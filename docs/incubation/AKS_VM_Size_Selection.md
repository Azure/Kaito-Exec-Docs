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

Summary: Confirms required tooling and authentication readiness.

## Setting up the environment

All parameters are defined as environment variables with sensible defaults.
`HASH` provides a timestamp for unique resource naming if needed. Adjust
values to fit the target subscription, region strategy, or performance goals.

```bash
export HASH="$(date -u +"%y%m%d%H%M")"

# Region & subscription
export LOCATION="${LOCATION:-eastus}"                  # Primary target region
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

Summary: Defines environment variables controlling region strategy, SKU
candidates, architecture, quota margin, and logging/output behavior.

### Environment variable matrix and override examples

The following matrix documents each environment variable, its default, purpose,
and common override scenarios.

```text
Variable                Default                                      Purpose / Notes
----------------------- -------------------------------------------- ---------------------------------------------------------------
HASH                   (current UTC YYMMDDHHMM)                     Uniqueness suffix for names when required.
LOCATION               eastus                                       Primary region for availability & quota evaluation.
FALLBACK_REGIONS       eastus2 westus3 centralus                    Ordered region failover list if primary yields no viable SKU.
AKS_NODE_ARCH          arm64                                        Target node architecture (arm64|amd64) influences candidate lists.
NODE_COUNT             1                                            Number of nodes used when projecting total required vCPUs.
AKS_NODE_VM_SIZE_REQUESTED Standard_D2darm_v3                       User-preferred starting SKU (first in candidate ordering).
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

### Run dynamic SKU selection script (core logic)

The script:

1. Builds an ordered candidate list: user-requested -> preferred family list -> fallback -> optional burstable.
2. Performs a single `az vm list-skus` inventory per region if `jq` is present (fast path). Falls back to per-SKU queries otherwise.
3. Filters for region availability, then evaluates regional vCPU quota (best effort) against projected usage (`per-node vCPUs * NODE_COUNT + margin`).
4. Selects the first candidate meeting availability and quota constraints. If none work in the primary region it iterates fallback regions.
5. Exports `AKS_NODE_VM_SIZE` and logs the selection (plain text). No cluster creation is performed here.

```bash
#!/usr/bin/env bash
set -euo pipefail

log() { [ "${VERBOSE}" = "true" ] && echo "$*" >&2; }

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

command -v jq >/dev/null 2>&1 && HAVE_JQ=1 || HAVE_JQ=0

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

select_in_region() {
  local REGION="$1"; shift
  local SKU_DATA=""
  if [ ${HAVE_JQ} -eq 1 ]; then
    log "Fetching SKU inventory for region ${REGION} (single call)"
    SKU_DATA=$(az vm list-skus -l "${REGION}" --all \
      --query "[?resourceType=='virtualMachines']" -o json 2>/dev/null || echo '[]')
  fi

  local REGIONAL_CURRENT REGIONAL_LIMIT
  REGIONAL_CURRENT=$(az vm list-usage -l "${REGION}" \
    --query "[?localName=='Total Regional vCPUs'].currentValue" -o tsv 2>/dev/null || echo "")
  REGIONAL_LIMIT=$(az vm list-usage -l "${REGION}" \
    --query "[?localName=='Total Regional vCPUs'].limit" -o tsv 2>/dev/null || echo "")

  local SELECTED="" SELECTED_VCPUS=""; local LOG_PREFIX="[${REGION}]"
  log "${LOG_PREFIX} Candidate order: ${CANDIDATES[*]}"

  for SKU in "${CANDIDATES[@]}"; do
    local AVAIL="" VCPU=""
    if [ ${HAVE_JQ} -eq 1 ]; then
      # Availability within region (SKU appears) and not subscription restricted
      AVAIL=$(echo "${SKU_DATA}" | jq -r --arg sku "${SKU}" \
        '.[] | select(.name==$sku) | select((.restrictions | map(.reasonCode) | index("NotAvailableForSubscription")) | not) | .name' | head -n1)
      VCPU=$(echo "${SKU_DATA}" | jq -r --arg sku "${SKU}" \
        '.[] | select(.name==$sku) | .capabilities[]? | select(.name=="vCPUs") | .value' | head -n1)
      RESTRICTED=$(echo "${SKU_DATA}" | jq -r --arg sku "${SKU}" \
        '.[] | select(.name==$sku) | .restrictions[]? | select(.reasonCode=="NotAvailableForSubscription") | .reasonCode' | head -n1)
    else
      AVAIL=$(az vm list-skus -l "${REGION}" \
        --query "[?name=='${SKU}' && resourceType=='virtualMachines'].name" -o tsv 2>/dev/null)
      RESTRICTED=$(az vm list-skus -l "${REGION}" \
        --query "[?name=='${SKU}' && resourceType=='virtualMachines'].restrictions[?reasonCode=='NotAvailableForSubscription'].reasonCode" -o tsv 2>/dev/null)
      VCPU=$(az vm list-skus -l "${REGION}" \
        --query "[?name=='${SKU}'].capabilities[?name=='vCPUs'].value | [0]" -o tsv 2>/dev/null)
    fi
    if [ -n "${RESTRICTED}" ]; then
      log "${LOG_PREFIX} skip ${SKU} (subscription restricted)"; continue
    fi
    if ! aks_supported "${SKU}"; then
      log "${LOG_PREFIX} skip ${SKU} (not AKS supported)"; continue
    fi
    if [ -z "${AVAIL}" ]; then
      log "${LOG_PREFIX} skip ${SKU} (not available)"; continue
    fi
    if [ -z "${VCPU}" ]; then
      log "${LOG_PREFIX} skip ${SKU} (vCPU unknown)"; continue
    fi
    local REQUIRED=$(( VCPU * NODE_COUNT ))
    if [ -n "${REGIONAL_CURRENT}" ] && [ -n "${REGIONAL_LIMIT}" ]; then
      local PROJECTED=$(( REGIONAL_CURRENT + REQUIRED + QUOTA_SAFETY_MARGIN ))
      if [ ${PROJECTED} -gt ${REGIONAL_LIMIT} ]; then
        log "${LOG_PREFIX} skip ${SKU} (quota: ${PROJECTED}>${REGIONAL_LIMIT})"; continue
      fi
    fi
    SELECTED="${SKU}"; SELECTED_VCPUS="${VCPU}"; break
  done

  if [ -n "${SELECTED}" ]; then
    echo "${SELECTED}:${SELECTED_VCPUS}"; return 0
  fi
  return 1
}

PRIMARY="${LOCATION}"
ALL_REGIONS=("${PRIMARY}")
for R in ${FALLBACK_REGIONS}; do [ "${R}" != "${PRIMARY}" ] && ALL_REGIONS+=("${R}"); done

FOUND_REGION="" FOUND_PAIR=""
for R in "${ALL_REGIONS[@]}"; do
  if PAIR=$(select_in_region "${R}" 2>/dev/null); then
    FOUND_REGION="${R}"; FOUND_PAIR="${PAIR}"; break
  fi
done

if [ -z "${FOUND_REGION}" ]; then
  echo "ERROR: No viable SKU found in primary or fallback regions." >&2
  exit 2
fi

AKS_NODE_VM_SIZE="${FOUND_PAIR%%:*}"; export AKS_NODE_VM_SIZE
SELECTED_VCPUS="${FOUND_PAIR##*:}"
echo "Selected SKU=${AKS_NODE_VM_SIZE} region=${FOUND_REGION} vCPUs/node=${SELECTED_VCPUS}"
```

Summary: Executes pre-flight SKU selection; exports `AKS_NODE_VM_SIZE` and outputs selection details only.

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
  echo "No AKS_NODE_VM_SIZE selected - listing sample SKUs for region ${LOCATION}" >&2
  az vm list-skus -l "${LOCATION}" --all \
    --query "[?resourceType=='virtualMachines'].name" -o tsv | sort -u | head -n 40 || echo "SKU listing command failed" >&2
else
  echo "AKS_NODE_VM_SIZE (${AKS_NODE_VM_SIZE}) already selected - skipping SKU inventory listing." >&2
fi
```

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

## Summary

The dynamic selection script identified an available AKS VM size within
quota constraints, reducing allocation failures. It supports ARM/AMD64,
fallback regions, burstable options, and a quota safety margin.

## Next Steps

- Reference this doc from deployment runbooks (replace inline SKU troubleshooting blocks)
- Extend to add zonal awareness or GPU SKU handling if required
- Feed selection metrics into observability pipeline (counts of fallback usage)

Summary: Future enhancements can improve proactive capacity planning and integration with automated provisioning workflows without coupling selection to cluster creation.
