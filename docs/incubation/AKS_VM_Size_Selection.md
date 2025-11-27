# AKS Dynamic VM Size (SKU) Selection - Executable Guide

## Introduction

This executable document provides a reusable, parameterized script for
selecting an Azure Kubernetes Service (AKS) node VM size (SKU) that is both
region-available and within remaining vCPU quota. It implements guidance
from the Azure allocation best practices (http://aka.ms/allocation-guidance)
by diversifying SKUs, optionally including burstable sizes, and supporting
ARM vs AMD64 architectures. The script reduces cluster create failures such
as `AllocationFailed` or disallowed SKU errors by performing a pre-flight
selection before running `az aks create`.

Summary: Introduces purpose and goals of automated AKS VM size pre-flight
selection for resilient cluster provisioning.

## Prerequisites

- Azure CLI (`az`) logged in (`az login`)
- Optional: `jq` for faster single-call SKU inventory parsing
- Bash shell environment
- Permissions to query regional VM SKUs and quotas

Verification:

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v jq >/dev/null || echo "jq not found (fallback path still works)"
```

<!-- expected_similarity="(Azure CLI|jq)" -->

```text
jq not found (fallback path still works)
```

Summary: Confirms required tooling and authentication readiness.

## Setting up the environment

All parameters are defined as environment variables with sensible defaults.
`HASH` provides a timestamp for unique resource naming if needed. Adjust
values to fit the target subscription, region strategy, or performance goals.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"

# Region & subscription
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"      # Primary target region (normalized)
export FALLBACK_REGIONS="${FALLBACK_REGIONS:-eastus2 westus3 centralus}"  # Ordered fallbacks

# Architecture & sizing
export AKS_NODE_ARCH="${AKS_NODE_ARCH:-amd64}"         # arm64 or amd64
export NODE_COUNT="${NODE_COUNT:-1}"                   # Initial node count
export AKS_NODE_VM_SIZE_REQUESTED="${AKS_NODE_VM_SIZE_REQUESTED:-Standard_DS2_v2}"  # User preference

# Candidate lists (space separated). First valid candidate is chosen.
export PREFERRED_SKUS_ARM="${PREFERRED_SKUS_ARM:-Standard_D2darm_v3 Standard_D4darm_v3 Standard_E2darm_v3 Standard_E4darm_v3 Standard_D8darm_v3}"
export PREFERRED_SKUS_AMD="${PREFERRED_SKUS_AMD:-Standard_DS2_v2 Standard_D2s_v5 Standard_D2ds_v5 Standard_D4s_v5 Standard_D4ds_v5}"
export FALLBACK_SKUS_ARM="${FALLBACK_SKUS_ARM:-Standard_E8darm_v3}"       # Larger sizes last
export FALLBACK_SKUS_AMD="${FALLBACK_SKUS_AMD:-Standard_D8s_v5}"          # Larger sizes last

# Burstable fallback toggle
export INCLUDE_BURSTABLE="${INCLUDE_BURSTABLE:-true}"  # true|false
export BURSTABLE_SKUS="${BURSTABLE_SKUS:-Standard_B2ms Standard_B4ms}"

# Quota safety (projected vCPU must be <= limit - margin)
export QUOTA_SAFETY_MARGIN="${QUOTA_SAFETY_MARGIN:-0}" # Extra vCPU headroom

# Logging behavior
export VERBOSE="${VERBOSE:-true}"                      # true for detailed stderr logs

# AKS support enforcement (prevent selecting sizes not supported for AKS even if region-available)
export ENFORCE_AKS_SUPPORTED="${ENFORCE_AKS_SUPPORTED:-true}"  # true|false
export AKS_SUPPORTED_SKUS_ARM="${AKS_SUPPORTED_SKUS_ARM:-Standard_D2darm_v3 Standard_D4darm_v3 Standard_D8darm_v3 Standard_D16darm_v3 Standard_D32darm_v3 Standard_D48darm_v3 Standard_E2darm_v3 Standard_E4darm_v3 Standard_E8darm_v3 Standard_E16darm_v3 Standard_E20darm_v3 Standard_E32darm_v3 Standard_E48darm_v3}"
export AKS_SUPPORTED_SKUS_AMD="${AKS_SUPPORTED_SKUS_AMD:-}"  # Populate if AMD64 list differs
```

```bash
# Consolidated variable summary (normalized naming)
VARS=(
  HASH
  AZURE_LOCATION
  FALLBACK_REGIONS
  AKS_NODE_ARCH
  NODE_COUNT
  AKS_NODE_VM_SIZE_REQUESTED
  PREFERRED_SKUS_ARM
  PREFERRED_SKUS_AMD
  FALLBACK_SKUS_ARM
  FALLBACK_SKUS_AMD
  INCLUDE_BURSTABLE
  BURSTABLE_SKUS
  QUOTA_SAFETY_MARGIN
  VERBOSE
  ENFORCE_AKS_SUPPORTED
  AKS_SUPPORTED_SKUS_ARM
  AKS_SUPPORTED_SKUS_AMD
)
for v in "${VARS[@]}"; do printf "%s=%s\n" "$v" "${!v}"; done
```

<!-- expected_similarity="(HASH=|AZURE_LOCATION=|AKS_NODE_ARCH=)" -->

```text
HASH=2511202253
AZURE_LOCATION=eastus2
FALLBACK_REGIONS=eastus2 westus3 centralus
AKS_NODE_ARCH=amd64
NODE_COUNT=1
AKS_NODE_VM_SIZE_REQUESTED=Standard_DS2_v2
```

Summary: Defines environment variables controlling region strategy, SKU
candidates, architecture, quota margin, and logging/output behavior.

### Environment variable matrix and override examples

The following matrix documents each environment variable, its default, purpose,
and common override scenarios.

```text
Variable                Default                                      Purpose / Notes
----------------------- -------------------------------------------- ---------------------------------------------------------------
HASH                   (current UTC YYMMDDHHMM)                     Uniqueness suffix for names when required.
AZURE_LOCATION         eastus2                                      Primary region for availability & quota evaluation.
FALLBACK_REGIONS       eastus2 westus3 centralus                    Ordered region failover list if primary yields no viable SKU.
AKS_NODE_ARCH          amd64                                        Target node architecture (arm64|amd64) influences candidate lists.
NODE_COUNT             1                                            Number of nodes used when projecting total required vCPUs.
AKS_NODE_VM_SIZE_REQUESTED Standard_DS2_v2                          User-preferred starting SKU (first in candidate ordering).
PREFERRED_SKUS_ARM     D2darm_v3 D4darm_v3 E2darm_v3 E4darm_v3 D8darm_v3  ARM prioritized diversified list (smaller → larger).
PREFERRED_SKUS_AMD     DS2_v2 D2s_v5 D2ds_v5 D4s_v5 D4ds_v5         AMD prioritized diversified list (older DSv2 → newer v5 variants).
FALLBACK_SKUS_ARM      E8darm_v3                                    ARM fallback larger size (last resort before burstable if enabled).
FALLBACK_SKUS_AMD      D8s_v5                                      AMD fallback larger size.
INCLUDE_BURSTABLE      true                                         Whether to append burstable B-series SKUs as capacity fallback.
BURSTABLE_SKUS         B2ms B4ms                                    Burstable candidate list (low cost / last resort capacity).
ENFORCE_AKS_SUPPORTED  true                                         Enforce filtering against AKS-supported lists before selection.
AKS_SUPPORTED_SKUS_ARM D2darm_v3 D4darm_v3 D8darm_v3 D16darm_v3 ...  Region AKS-permitted ARM64 sizes (copy from AKS error output).
AKS_SUPPORTED_SKUS_AMD (empty)                                      Region AKS-permitted AMD64 sizes (populate as needed).
QUOTA_SAFETY_MARGIN    0                                            Extra vCPU headroom to avoid consuming full quota; increase for buffer.
VERBOSE                true                                         Controls detailed stderr logging (skip logs when false).
```

Override examples (adjust for testing, performance scaling, or quota pressure):

```bash
# Target AMD64 architecture with 3 nodes, exclude burstable SKUs
export AKS_NODE_ARCH=amd64
export NODE_COUNT=3
export INCLUDE_BURSTABLE=false

# Increase safety margin to retain 4 vCPUs of quota headroom
export QUOTA_SAFETY_MARGIN=4

# Narrow fallback regions when focusing on East US pair only
export FALLBACK_REGIONS="eastus2"

# Prefer v5 generation SKUs first (manual re-prioritization)
export PREFERRED_SKUS_AMD="Standard_D2s_v5 Standard_D4s_v5 Standard_D2ds_v5 Standard_D4ds_v5 Standard_DS2_v2"

# Enforce AKS-supported list (prevent selecting region-available but AKS-disallowed sizes)
export ENFORCE_AKS_SUPPORTED=true

# Force a specific requested size (will still validate availability/quota)
export AKS_NODE_VM_SIZE_REQUESTED="Standard_D4s_v5"
```

Summary: The matrix clarifies variable intent and the override examples show
typical adjustments for architecture changes, scaling, quota management, and
candidate reprioritization.

## Steps

The SKU selection process is divided into three stages: building the
candidate list and querying regional SKU inventory, filtering candidates
against availability and quota constraints, and performing regional fallback
if necessary. Each stage can be executed and verified independently.

Summary: Three-stage selection process provides visibility into candidate
filtering decisions and enables incremental debugging.

### Build candidate list and query regional inventory

Build an ordered list of VM size candidates based on the target architecture
(ARM64 or AMD64), incorporating the user-requested SKU, preferred families,
fallback sizes, and optional burstable SKUs. Query the Azure SKU inventory
for the primary region using a single API call when jq is available, or
fall back to per-SKU queries. Export the candidate list and SKU data for
use in the filtering stage.

```bash
# Build candidate list per architecture
if [ "${AKS_NODE_ARCH}" = "arm64" ]; then
  ARCH_PREF_LIST="${PREFERRED_SKUS_ARM}"
  ARCH_FALLBACK_LIST="${FALLBACK_SKUS_ARM}"
else
  ARCH_PREF_LIST="${PREFERRED_SKUS_AMD}"
  ARCH_FALLBACK_LIST="${FALLBACK_SKUS_AMD}"
fi

CANDIDATES=( ${AKS_NODE_VM_SIZE_REQUESTED} ${ARCH_PREF_LIST} ${ARCH_FALLBACK_LIST} )

if [ "${INCLUDE_BURSTABLE}" = "true" ]; then
  CANDIDATES+=( ${BURSTABLE_SKUS} )
fi

# Deduplicate while preserving order
DEDUP=()
for SKU in "${CANDIDATES[@]}"; do
  [ -z "${SKU}" ] && continue
  SEEN=false
  for D in "${DEDUP[@]}"; do [ "${D}" = "${SKU}" ] && SEEN=true && break; done
  [ "${SEEN}" = false ] && DEDUP+=("${SKU}")
done
CANDIDATES=("${DEDUP[@]}")

# Export candidate list for next stage
export CANDIDATE_SKUS="${CANDIDATES[*]}"
export CANDIDATE_COUNT="${#CANDIDATES[@]}"

# Query SKU inventory for primary region (single API call if jq available)
command -v jq >/dev/null 2>&1 && HAVE_JQ=1 || HAVE_JQ=0
export HAVE_JQ

# Use temp file to avoid environment variable size limits
export SKU_DATA_FILE="/tmp/sku-data-${HASH}-${AZURE_LOCATION}.json"

if [ ${HAVE_JQ} -eq 1 ]; then
  echo "Fetching SKU inventory for ${AZURE_LOCATION} (single API call with jq)"
  az vm list-skus -l "${AZURE_LOCATION}" --all \
    --query "[?resourceType=='virtualMachines']" -o json 2>/dev/null > "${SKU_DATA_FILE}" || echo '[]' > "${SKU_DATA_FILE}"
  SKU_COUNT=$(jq 'length' < "${SKU_DATA_FILE}" 2>/dev/null || echo 0)
else
  echo "jq not available - will use per-SKU queries (slower)"
  echo '[]' > "${SKU_DATA_FILE}"
  SKU_COUNT=0
fi

# Query quota for primary region
export QUOTA_CURRENT=$(az vm list-usage -l "${AZURE_LOCATION}" \
  --query "[?localName=='Total Regional vCPUs'].currentValue" -o tsv 2>/dev/null || echo "0")
export QUOTA_LIMIT=$(az vm list-usage -l "${AZURE_LOCATION}" \
  --query "[?localName=='Total Regional vCPUs'].limit" -o tsv 2>/dev/null || echo "0")

echo "Region: ${AZURE_LOCATION}"
echo "Candidates: ${CANDIDATE_COUNT} SKUs (${CANDIDATE_SKUS})"
echo "SKU inventory: ${SKU_COUNT} VMs loaded"
echo "Quota: ${QUOTA_CURRENT}/${QUOTA_LIMIT} vCPUs"
```

<!-- expected_similarity="(Candidates: [0-9]+ SKUs|Quota: [0-9]+/[0-9]+ vCPUs)" -->

```text
Fetching SKU inventory for eastus (single API call with jq)
Region: eastus
Candidates: 7 SKUs (Standard_DS2_v2 Standard_D2s_v5 Standard_D2ds_v5 Standard_D4s_v5 Standard_D4ds_v5 Standard_D8s_v5 Standard_B2ms Standard_B4ms)
SKU inventory: 1247 VMs loaded
Quota: 0/20 vCPUs
```

Summary: Built candidate list from architecture-specific preferences and
queried primary region SKU inventory and quota limits.

### Filter candidates and select viable SKU

Iterate through the candidate list in priority order, checking each SKU
against subscription restrictions, AKS support requirements, regional
availability, and vCPU quota constraints. Select the first SKU that passes
all filters or indicate that no viable SKU exists in the primary region.

```bash
# Helper: verify SKU allowed for AKS when enforcement enabled
aks_supported() {
  local SKU="$1"; local SKU_L
  SKU_L=$(echo "$SKU" | tr '[:upper:]' '[:lower:]')
  if [ "${ENFORCE_AKS_SUPPORTED}" != "true" ]; then
    return 0
  fi
  local LIST=""
  if [ "${AKS_NODE_ARCH}" = "arm64" ]; then
    LIST="${AKS_SUPPORTED_SKUS_ARM}"
  else
    LIST="${AKS_SUPPORTED_SKUS_AMD}"
  fi
  [ -z "${LIST}" ] && return 0
  for S in ${LIST}; do
    [ "$(echo "$S" | tr '[:upper:]' '[:lower:]')" = "${SKU_L}" ] && return 0
  done
  return 1
}

# Filter candidates in primary region
SELECTED="" SELECTED_VCPUS="" SELECTED_REGION="${AZURE_LOCATION}"
read -ra CANDIDATES_ARRAY <<< "${CANDIDATE_SKUS}"

echo "Filtering candidates in ${AZURE_LOCATION}..."
for SKU in "${CANDIDATES_ARRAY[@]}"; do
  AVAIL="" VCPU="" RESTRICTED=""

  if [ ${HAVE_JQ} -eq 1 ] && [ -s "${SKU_DATA_FILE}" ]; then
    AVAIL=$(jq -r --arg sku "${SKU}" \
      '.[] | select(.name==$sku) | select((.restrictions | map(.reasonCode) | index("NotAvailableForSubscription")) | not) | .name' \
      < "${SKU_DATA_FILE}" 2>/dev/null | head -n1)
    VCPU=$(jq -r --arg sku "${SKU}" \
      '.[] | select(.name==$sku) | .capabilities[]? | select(.name=="vCPUs") | .value' \
      < "${SKU_DATA_FILE}" 2>/dev/null | head -n1)
    RESTRICTED=$(jq -r --arg sku "${SKU}" \
      '.[] | select(.name==$sku) | .restrictions[]? | select(.reasonCode=="NotAvailableForSubscription") | .reasonCode' \
      < "${SKU_DATA_FILE}" 2>/dev/null | head -n1)
  else
  AVAIL=$(az vm list-skus -l "${AZURE_LOCATION}" \
      --query "[?name=='${SKU}' && resourceType=='virtualMachines'].name" -o tsv 2>/dev/null)
  RESTRICTED=$(az vm list-skus -l "${AZURE_LOCATION}" \
      --query "[?name=='${SKU}' && resourceType=='virtualMachines'].restrictions[?reasonCode=='NotAvailableForSubscription'].reasonCode" -o tsv 2>/dev/null)
  VCPU=$(az vm list-skus -l "${AZURE_LOCATION}" \
      --query "[?name=='${SKU}'].capabilities[?name=='vCPUs'].value | [0]" -o tsv 2>/dev/null)
  fi

  if [ -n "${RESTRICTED}" ]; then
    echo "  ✗ ${SKU}: subscription restricted"
    continue
  fi
  if ! aks_supported "${SKU}"; then
    echo "  ✗ ${SKU}: not AKS supported"
    continue
  fi
  if [ -z "${AVAIL}" ]; then
    echo "  ✗ ${SKU}: not available"
    continue
  fi
  if [ -z "${VCPU}" ]; then
    echo "  ✗ ${SKU}: vCPU count unknown"
    continue
  fi

  REQUIRED=$(( VCPU * NODE_COUNT ))
  if [ -n "${QUOTA_CURRENT}" ] && [ -n "${QUOTA_LIMIT}" ]; then
    PROJECTED=$(( QUOTA_CURRENT + REQUIRED + QUOTA_SAFETY_MARGIN ))
    if [ ${PROJECTED} -gt ${QUOTA_LIMIT} ]; then
      echo "  ✗ ${SKU}: quota exceeded (${PROJECTED}>${QUOTA_LIMIT})"
      continue
    fi
  fi

  echo "  ✓ ${SKU}: available (${VCPU} vCPUs, quota OK)"
  SELECTED="${SKU}"
  SELECTED_VCPUS="${VCPU}"
  break
done

export SELECTED_SKU="${SELECTED}"
export SELECTED_VCPUS
export SELECTED_REGION

if [ -n "${SELECTED}" ]; then
  echo "Primary region selection: ${SELECTED} (${SELECTED_VCPUS} vCPUs)"
else
  echo "No viable SKU found in primary region ${AZURE_LOCATION}"
fi
```

<!-- expected_similarity="(available \([0-9]+ vCPUs|No viable SKU)" -->

```text
Filtering candidates in eastus...
  ✗ Standard_DS2_v2: not available
  ✗ Standard_D2s_v5: not available
  ✗ Standard_D2ds_v5: not available
  ✗ Standard_D4s_v5: not available
  ✗ Standard_D4ds_v5: not available
  ✗ Standard_D8s_v5: not available
  ✗ Standard_B2ms: not available
  ✗ Standard_B4ms: not available
No viable SKU found in primary region eastus
```

Summary: Filtered candidates against subscription restrictions, AKS support
lists, availability, and quota; selected first viable SKU or flagged need
for regional fallback.

### Execute regional fallback and export selection

If no viable SKU was found in the primary region, iterate through fallback
regions in order, querying SKU inventory and quota for each region and
applying the same filtering logic. Export the first successful SKU selection
or exit with an error if all regions are exhausted.

```bash
if [ -n "${SELECTED_SKU}" ]; then
  echo "Using primary region selection - no fallback needed"
  AKS_NODE_VM_SIZE="${SELECTED_SKU}"
  FINAL_REGION="${SELECTED_REGION}"
  FINAL_VCPUS="${SELECTED_VCPUS}"
else
  echo "Attempting regional fallback..."

  # Parse fallback regions and filter out primary
  FALLBACK_LIST=()
  for R in ${FALLBACK_REGIONS}; do
    [ "${R}" != "${AZURE_LOCATION}" ] && FALLBACK_LIST+=("${R}")
  done

  FOUND=false
  for REGION in "${FALLBACK_LIST[@]}"; do
    echo ""
    echo "Trying fallback region: ${REGION}"

    # Query SKU inventory for fallback region using temp file
    REGION_SKU_FILE="/tmp/sku-data-${HASH}-${REGION}.json"
    if [ ${HAVE_JQ} -eq 1 ]; then
      az vm list-skus -l "${REGION}" --all \
        --query "[?resourceType=='virtualMachines']" -o json 2>/dev/null > "${REGION_SKU_FILE}" || echo '[]' > "${REGION_SKU_FILE}"
    else
      echo '[]' > "${REGION_SKU_FILE}"
    fi

    # Query quota for fallback region
    REGION_QUOTA_CURRENT=$(az vm list-usage -l "${REGION}" \
      --query "[?localName=='Total Regional vCPUs'].currentValue" -o tsv 2>/dev/null || echo "0")
    REGION_QUOTA_LIMIT=$(az vm list-usage -l "${REGION}" \
      --query "[?localName=='Total Regional vCPUs'].limit" -o tsv 2>/dev/null || echo "0")

    echo "  Quota: ${REGION_QUOTA_CURRENT}/${REGION_QUOTA_LIMIT} vCPUs"

    # Filter candidates in this fallback region
    read -ra CANDIDATES_ARRAY <<< "${CANDIDATE_SKUS}"
    for SKU in "${CANDIDATES_ARRAY[@]}"; do
      AVAIL="" VCPU="" RESTRICTED=""

      if [ ${HAVE_JQ} -eq 1 ] && [ -s "${REGION_SKU_FILE}" ]; then
        AVAIL=$(jq -r --arg sku "${SKU}" \
          '.[] | select(.name==$sku) | select((.restrictions | map(.reasonCode) | index("NotAvailableForSubscription")) | not) | .name' \
          < "${REGION_SKU_FILE}" 2>/dev/null | head -n1)
        VCPU=$(jq -r --arg sku "${SKU}" \
          '.[] | select(.name==$sku) | .capabilities[]? | select(.name=="vCPUs") | .value' \
          < "${REGION_SKU_FILE}" 2>/dev/null | head -n1)
        RESTRICTED=$(jq -r --arg sku "${SKU}" \
          '.[] | select(.name==$sku) | .restrictions[]? | select(.reasonCode=="NotAvailableForSubscription") | .reasonCode' \
          < "${REGION_SKU_FILE}" 2>/dev/null | head -n1)
      else
        AVAIL=$(az vm list-skus -l "${REGION}" \
          --query "[?name=='${SKU}' && resourceType=='virtualMachines'].name" -o tsv 2>/dev/null)
        RESTRICTED=$(az vm list-skus -l "${REGION}" \
          --query "[?name=='${SKU}' && resourceType=='virtualMachines'].restrictions[?reasonCode=='NotAvailableForSubscription'].reasonCode" -o tsv 2>/dev/null)
        VCPU=$(az vm list-skus -l "${REGION}" \
          --query "[?name=='${SKU}'].capabilities[?name=='vCPUs'].value | [0]" -o tsv 2>/dev/null)
      fi

      [ -n "${RESTRICTED}" ] && continue
      aks_supported "${SKU}" || continue
      [ -z "${AVAIL}" ] && continue
      [ -z "${VCPU}" ] && continue

      REQUIRED=$(( VCPU * NODE_COUNT ))
      if [ -n "${REGION_QUOTA_CURRENT}" ] && [ -n "${REGION_QUOTA_LIMIT}" ]; then
        PROJECTED=$(( REGION_QUOTA_CURRENT + REQUIRED + QUOTA_SAFETY_MARGIN ))
        [ ${PROJECTED} -gt ${REGION_QUOTA_LIMIT} ] && continue
      fi

      echo "  ✓ Found: ${SKU} (${VCPU} vCPUs)"
      AKS_NODE_VM_SIZE="${SKU}"
      FINAL_REGION="${REGION}"
      FINAL_VCPUS="${VCPU}"
      FOUND=true
      break
    done

    [ "${FOUND}" = true ] && break
  done

  if [ "${FOUND}" != true ]; then
    echo ""
    echo "ERROR: No viable SKU found in primary or fallback regions" >&2
    exit 2
  fi
fi

export AKS_NODE_VM_SIZE
echo ""
echo "Selected SKU=${AKS_NODE_VM_SIZE} region=${FINAL_REGION} vCPUs/node=${FINAL_VCPUS}"

# Cleanup temporary SKU data files
rm -f /tmp/sku-data-${HASH}-*.json 2>/dev/null || true
echo "Cleaned up temporary SKU data files"
```

<!-- expected_similarity="Selected SKU=Standard_[A-Z0-9_]+ region=[a-z0-9]+ vCPUs/node=[0-9]+" -->

```text
Attempting regional fallback...

Trying fallback region: eastus2
  Quota: 0/20 vCPUs
  ✓ Found: Standard_DS2_v2 (2 vCPUs)

Selected SKU=Standard_DS2_v2 region=eastus2 vCPUs/node=2
Cleaned up temporary SKU data files
```

Summary: Executed regional fallback when primary region had no viable SKU;
exported AKS_NODE_VM_SIZE for use in cluster creation commands and cleaned
up temporary files.

### Remediation (no viable SKU found)

When the script exits with `ERROR: No viable SKU found` it indicates that all
candidate sizes failed availability or quota checks in the primary and fallback
regions. Use the following ordered remediation guidance:

```text
1. Reduce NODE_COUNT to lower projected vCPU usage (temporary downsizing).
2. Increase regional vCPU quota via Azure Portal (Subscriptions -> Usage + quotas).
3. Add or adjust candidate lists: include newer generation SKUs (v5), diversify families (D, E), or enable burstable (`INCLUDE_BURSTABLE=true`).
4. Decrease QUOTA_SAFETY_MARGIN if conservative headroom is blocking selection (ensure risk is acceptable).
5. Extend FALLBACK_REGIONS list to include additional regions with broader capacity (e.g. westus3, centralus, canadacentral).
6. Switch architecture (`AKS_NODE_ARCH=amd64` or `arm64`) if workload images support both and one architecture has better capacity.
7. Manually set AKS_NODE_VM_SIZE to a known allowed SKU from an `az vm list-skus` query for the target region.
8. Review subscription-wide usage anomalies; deallocate unused test clusters consuming quota.
9. Escalate persistent capacity issues by filing a support request if regional constraints persist across multiple families.
```

Example manual discovery command for a specific region:

```bash
# Only perform manual SKU inventory listing if dynamic selection failed.
if [ -z "${AKS_NODE_VM_SIZE:-}" ]; then
  echo "No AKS_NODE_VM_SIZE selected - listing sample SKUs for region ${AZURE_LOCATION}" >&2
  az vm list-skus -l "${AZURE_LOCATION}" --all \
    --query "[?resourceType=='virtualMachines'].name" -o tsv | sort -u | head -n 40 || echo "SKU listing command failed" >&2
  # Clean up any leftover temp files from failed selection
  rm -f /tmp/sku-data-${HASH}-*.json 2>/dev/null || true
else
  echo "AKS_NODE_VM_SIZE (${AKS_NODE_VM_SIZE}) already selected - skipping SKU inventory listing." >&2
fi
```

<!-- expected_similarity="already selected - skipping" -->

```text
AKS_NODE_VM_SIZE (Standard_DS2_v2) already selected - skipping SKU inventory listing.
```

Summary: Conditionally lists available SKUs only when automatic selection has
failed, avoiding unnecessary API calls during normal operation.

### AKS support enforcement rationale

Generic VM SKU availability does not guarantee AKS support for a subscription/region. A SKU (e.g. `Standard_D4s_v5`) may appear in `az vm list-skus` results yet be omitted from the AKS error message enumerating allowed sizes, causing a create failure. The `ENFORCE_AKS_SUPPORTED` toggle filters candidates through `AKS_SUPPORTED_SKUS_ARM` or `AKS_SUPPORTED_SKUS_AMD` (populated from an AKS create error output or documentation). This pre-flight constraint prevents selecting SKUs that would later fail with an "is not supported" message.

Summary: Enforcing AKS-supported lists reduces cluster create retries by eliminating candidates that are region-available but AKS-disallowed for the subscription.

### Known restriction reasons

Azure may return restriction metadata for a VM size in a region. Common
`reasonCode` values observed in SKU queries:

```text
NotAvailableForSubscription   Subscription is not authorized for this SKU in the region (often burstable or specialized sizes).
ZonePlacementConstraint       SKU limited by zonal placement rules; may require specifying Availability Zones.
QuotaId                       Quota category association; creates implicit limits requiring quota increases to proceed.
CapabilityNotSupported        Feature/capability required by the SKU not enabled for the subscription.
RegionalCapacityConstraint    Temporary regional capacity pressure (retry in alternate region or later).
```

Selection logic currently skips SKUs with `NotAvailableForSubscription` to
avoid pre-flight false positives. Other restriction codes do not always block
AKS creation outright but may surface as allocation failures; consider adding
extended filtering if they produce repeat errors in practice.

Summary: Restriction metadata clarifies why a SKU is filtered or fails; use it
to guide subscription enablement, quota increase requests, or region/architecture adjustments.

## Verification

Check whether a viable AKS VM size has already been selected by verifying
that the `AKS_NODE_VM_SIZE` environment variable is set to a non-empty value.
This read-only verification allows fast re-execution of the document without
repeating the SKU selection process.

```bash
if [ -n "${AKS_NODE_VM_SIZE:-}" ]; then
  echo "✓ AKS_NODE_VM_SIZE already set to: ${AKS_NODE_VM_SIZE}"
  echo "✓ SKU selection complete - document execution not needed"
  exit 0
else
  echo "AKS_NODE_VM_SIZE not set - SKU selection required"
  exit 1
fi
```

<!-- expected_similarity="(already set to|not set)" -->

```text
AKS_NODE_VM_SIZE not set - SKU selection required
```

Summary: Verification checks confirm whether SKU selection has completed
without performing any Azure API calls or mutations.

## Summary

You executed the dynamic SKU selection script to identify an available AKS
VM size within regional availability and quota constraints. The script
exported `AKS_NODE_VM_SIZE` containing the selected SKU, ready for use in
`az aks create` commands. Regional fallback, architecture-specific candidate
lists, and subscription restriction filtering reduced allocation failures.

Summary: SKU selection completed with AKS_NODE_VM_SIZE exported for
downstream cluster creation workflows.

## Next Steps

- Reference this doc from deployment runbooks (replace inline SKU troubleshooting blocks)
- Extend to add zonal awareness or GPU SKU handling if required
- Feed selection metrics into observability pipeline (counts of fallback usage)

Summary: Future enhancements can improve proactive capacity planning and integration with automated provisioning workflows without coupling selection to cluster creation.
