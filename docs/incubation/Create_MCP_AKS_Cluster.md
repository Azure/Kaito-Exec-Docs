# Create an AKS Cluster and Deploy the KMCP Control Plane

## Introduction

This document describes how to provision an Azure Kubernetes Service (AKS)
cluster and deploy the KMCP (Kagent Model Control Platform) control plane
components. It uses parameterized environment variables so the same set of
commands can be reused across environments with minimal edits. The process
covers cluster creation, optional container registry setup, KMCP installation,
and basic validation.

At the end of this guide a functional KMCP control plane will be running on
AKS. This forms the foundation for deploying MCP servers (for example the
Echo MCP server) in subsequent runbooks.

## Prerequisites

This section lists the required tools and access needed before executing the
steps. Each item should be confirmed before continuing.

```bash
# Required local tooling (verify versions as needed)
# - Azure CLI (az) authenticated to target tenant
# - kubectl installed and on PATH
# - Helm v3 installed and on PATH
# - jq (recommended) for JSON parsing (improves pre-flight performance)
# - Sufficient Azure RBAC permissions: (Contributor) on subscription or RG
# - Network egress allowed to Azure public endpoints and Helm repo
```

The following Azure resource providers should be registered (usually registered by
default but verify if errors occur):

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.OperationsManagement
```

Summary: Ensure CLI tools are installed, authenticated, and appropriate Azure
permissions are available before proceeding.

## Setting up the environment

This section defines environment variables used throughout the document. Each
variable has a default value that can be adjusted as needed.

Unique resource names append the dynamic `HASH` suffix to avoid collisions. Here
we use a timestamp-based hash (YYMMDDHHMM).

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"
```

We need to define the subscription and location to use for the resuorces. By default we
are using the currently selected account. This command assumes that you have already logged
into Azure with `az login`.

```bash
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"  # Active subscription
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"  # Default region (ensure required quotas/providers are available)
```

Resources in Azure need human readable names for convenience:

```bash
# Resource group and cluster names (unique where needed)
export AZURE_RESOURCE_GROUP="mcpaks-rg_${HASH}"
export AKS_NAME="mcpaks-cluster"
```

The AKS cluster needs to know how to configure its nodes. Later we will use a script to attempt to automatically validate the SKU selected and requested quota. This validation will select another SKU if the configured VM Size or Quota is not available.

```bash
# Node configuration
export NODE_COUNT="2"
export NODE_ARCH="amd64"  # default to AMD64 for widest image compatibility; set to arm64 to target ARM-based SKUs
export NODE_VM_SIZE="Standard_DS2_v2"  # IMPORTANT: Canonical casing. Default is a widely available DSv2 SKU (AMD64); adjust for performance or architecture needs. Note the script below attempts to validate this SKU is available and selects alternatives if not.
export INCLUDE_BURSTABLE="true"  # set to false to prevent B-series burstable SKUs as a last-resort capacity fallback
export K8S_VERSION=""  # leave blank for default latest supported
```

```bash
# Azure Container Registry (optional but recommended)
export ACR_NAME="mcpacr${HASH}"  # must be globally unique (no underscores)
export ACR_SKU="Basic"

# KMCP deployment parameters (OCI based)
export KMCP_NAMESPACE="kmcp-system"
export KMCP_VERSION=""  # pin for reproducibility; update as needed

# Helm OCI (GitHub Container Registry) base path and chart identifiers
# NOTE: Earlier instructions used generic org-level paths and different chart names
# which can yield 403 (forbidden) or 404 (not found) because the OCI artifacts
# actually live under the nested path below.
export KMCP_OCI_BASE="oci://ghcr.io/kagent-dev/kmcp/helm"
export KMCP_CRDS_CHART="kmcp-crds"   # CRDs chart artifact name
export KMCP_CORE_CHART="kmcp"        # Core control plane artifact name
export KMCP_CRDS_RELEASE="kmcp-crds" # Release name in cluster
export KMCP_CORE_RELEASE="kmcp"      # Release name in cluster


# Optional network / tagging
export TAG_ENV="dev"

# Internal timeouts / waits (seconds)
export WAIT_ROLLOUT="300"
```

```bash
# Variable summary (normalized Azure naming)
VARS=(
  HASH
  AZURE_SUBSCRIPTION_ID
  AZURE_LOCATION
  AZURE_RESOURCE_GROUP
  AKS_NAME
  NODE_COUNT
  NODE_ARCH
  NODE_VM_SIZE
  INCLUDE_BURSTABLE
  K8S_VERSION
  ACR_NAME
  ACR_SKU
  KMCP_NAMESPACE
  KMCP_VERSION
  KMCP_OCI_BASE
  KMCP_CRDS_CHART
  KMCP_CORE_CHART
  KMCP_CRDS_RELEASE
  KMCP_CORE_RELEASE
  TAG_ENV
  WAIT_ROLLOUT
)
for v in "${VARS[@]}"; do printf "%s=%s\n" "$v" "${!v}"; done
```

Summary: Environment variables have been defined with sensible defaults. The
`HASH` ensures uniqueness for resources that require globally unique names.

Note: VM size (SKU) comparisons in Azure CLI JMESPath filters are case
Sensitive. Provide canonical casing (e.g. `Standard_D2s_v5`, not
`standard_d2s_v5`). The pre-flight logic relies on exact matches.

## Steps

This section contains the ordered steps. Execute each block fully before
proceeding. All commands assume the environment variables above are exported
in the current shell.

### 1. Login and set subscription

Authenticate to Azure and set the active subscription context.

```bash
az account show >/dev/null 2>&1 || az login
az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
```

Summary: Azure CLI is authenticated and the working subscription is set.

### 2. Create resource group

Create a dedicated resource group for the cluster and supporting assets.

```bash
az group create \
  --name "${AZURE_RESOURCE_GROUP}" \
  --location "${AZURE_LOCATION}" \
  --tags env=${TAG_ENV} system=mcp controlplane=kmcp
```

Summary: The resource group is ready to contain AKS and optional ACR.

### 3. (Optional) Create Azure Container Registry

Create an ACR if container images need to be built and stored locally. This
step can be skipped if using public images only.

```bash
az acr create \
  --name "${ACR_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --sku "${ACR_SKU}" \
  --location "${AZURE_LOCATION}" \
  --tags env=${TAG_ENV} system=mcp

# Capture ACR resource ID for role assignment
export ACR_ID=$(az acr show -n "${ACR_NAME}" -g "${AZURE_RESOURCE_GROUP}" --query id -o tsv)
```

Summary: ACR is provisioned and ready for image pushes and pulls.

### 4. Create AKS cluster

Provision the AKS cluster. Attach the ACR if it exists. Use a system-assigned
managed identity (default) and enable OIDC issuer for future workload identity
integration if required.

Perform a consolidated pre-flight selection: build a diversified candidate
list (user requested size first, then multiple families and generations) and
choose the first VM size that is both available in the region and within
remaining regional vCPU quota. This implements practices from Azure capacity
allocation guidance (see http://aka.ms/allocation-guidance): diversify SKU
families, include newer generations, optionally allow burstable SKUs as a
last resort, and prefer smaller footprints when approaching quota limits.
The candidate list is generated from `NODE_ARCH` (arm64 vs amd64) plus
`INCLUDE_BURSTABLE`. Adjust these if specific performance characteristics or
architectural constraints apply. This reduces create failures and shortens
iteration time.

```bash
SELECTED_SKU=""
SELECTED_VCPUS=""

# Build diversified candidate list
ARM64_CANDIDATES=( \
  Standard_D2darm_v3 Standard_D4darm_v3 Standard_D8darm_v3 \
  Standard_D2ps_v5 Standard_D4ps_v5 Standard_D8ps_v5 \
)
AMD64_CANDIDATES=( \
  # Start with older DSv2 (broad capacity), then scale up generations v3->v4->v5 and storage optimized ds variants.
  Standard_DS2_v2 Standard_DS3_v2 \
  Standard_D2s_v3 Standard_D4s_v3 \
  Standard_D2s_v4 Standard_D4s_v4 \
  Standard_D2s_v5 Standard_D4s_v5 \
  Standard_D2ds_v5 Standard_D4ds_v5 \
)
BURSTABLE_CANDIDATES=(Standard_B2ms Standard_B4ms)

PRECHECK_CANDIDATES=(${NODE_VM_SIZE})
if [ "${NODE_ARCH}" = "arm64" ]; then
  PRECHECK_CANDIDATES+=("${ARM64_CANDIDATES[@]}")
else
  PRECHECK_CANDIDATES+=("${AMD64_CANDIDATES[@]}")
fi
if [ "${INCLUDE_BURSTABLE}" = "true" ]; then
  PRECHECK_CANDIDATES+=("${BURSTABLE_CANDIDATES[@]}")
fi

# Deduplicate while preserving order
DEDUP=()
for SKU in "${PRECHECK_CANDIDATES[@]}"; do
  SEEN=false
  for D in "${DEDUP[@]}"; do [ "$D" = "$SKU" ] && SEEN=true && break; done
  [ "$SEEN" = false ] && DEDUP+=("$SKU")
done
PRECHECK_CANDIDATES=("${DEDUP[@]}")

## Performance optimization: single SKU inventory + in-memory filtering
# Fetch regional quota once (best effort)
REGIONAL_CURRENT=$(az vm list-usage -l "${LOCATION}" \
  --query "[?localName=='Total Regional vCPUs'].currentValue" -o tsv 2>/dev/null)
REGIONAL_LIMIT=$(az vm list-usage -l "${LOCATION}" \
  --query "[?localName=='Total Regional vCPUs'].limit" -o tsv 2>/dev/null)

USE_JQ=false; command -v jq >/dev/null 2>&1 && USE_JQ=true
if [ "${USE_JQ}" = true ]; then
  # Single call - restrict to virtualMachines resource type only
  SKU_DATA=$(az vm list-skus -l "${LOCATION}" --all \
    --query "[?resourceType=='virtualMachines']" -o json 2>/dev/null || echo '[]')
  echo "PRECHECK: cached $(echo "${SKU_DATA}" | jq 'length') VM SKU entries for region ${LOCATION}." >&2
else
  echo "PRECHECK: jq not found - falling back to per-SKU az queries (slower). Install jq for better performance." >&2
fi

echo "Pre-flight: starting VM size selection (requested=${NODE_VM_SIZE}; arch=${NODE_ARCH}; burstable=${INCLUDE_BURSTABLE}; jq=${USE_JQ})." >&2
echo "PRECHECK: candidate order: ${PRECHECK_CANDIDATES[*]}" >&2

for SKU in "${PRECHECK_CANDIDATES[@]}"; do
  if [ "${USE_JQ}" = true ]; then
    AVAIL=$(echo "${SKU_DATA}" | jq -r --arg sku "${SKU}" '.[] | select(.name==$sku) | .name' | head -n1)
    if [ -z "${AVAIL}" ]; then
      echo "PRECHECK: skip ${SKU} - not available in ${LOCATION}." >&2
      continue
    fi
    VCPU=$(echo "${SKU_DATA}" | jq -r --arg sku "${SKU}" '.[] | select(.name==$sku) | .capabilities[]? | select(.name=="vCPUs") | .value' | head -n1)
  else
    AVAIL=$(az vm list-skus -l "${LOCATION}" \
      --query "[?name=='${SKU}' && locations[0]=='${LOCATION}'].name" -o tsv 2>/dev/null)
    if [ -z "${AVAIL}" ]; then
      echo "PRECHECK: skip ${SKU} - not available in ${LOCATION}." >&2
      continue
    fi
    VCPU=$(az vm list-skus -l "${LOCATION}" \
      --query "[?name=='${SKU}'].capabilities[?name=='vCPUs'].value | [0]" -o tsv 2>/dev/null)
  fi
  if [ -z "${VCPU}" ]; then
    echo "PRECHECK: skip ${SKU} - could not determine vCPUs." >&2
    continue
  fi
  REQUIRED=$(( VCPU * NODE_COUNT ))
  if [ -z "${REGIONAL_CURRENT}" ] || [ -z "${REGIONAL_LIMIT}" ]; then
    echo "PRECHECK: selecting ${SKU} (quota data unavailable)." >&2
    SELECTED_SKU=${SKU}; SELECTED_VCPUS=${VCPU}; break
  fi
  PROJECTED=$(( REGIONAL_CURRENT + REQUIRED ))
  if [ ${PROJECTED} -le ${REGIONAL_LIMIT} ]; then
    echo "PRECHECK: selecting ${SKU} (current=${REGIONAL_CURRENT} + required=${REQUIRED} = ${PROJECTED} <= limit=${REGIONAL_LIMIT})." >&2
    SELECTED_SKU=${SKU}; SELECTED_VCPUS=${VCPU}; break
  else
    echo "PRECHECK: skip ${SKU} - quota exceed (current=${REGIONAL_CURRENT} + required=${REQUIRED} = ${PROJECTED} > limit=${REGIONAL_LIMIT})." >&2
  fi
done

if [ -z "${SELECTED_SKU}" ]; then
  echo "PRECHECK: no viable VM size found. Consider: reduce NODE_COUNT, enable INCLUDE_BURSTABLE=true, request quota increase, try another region, or supply an alternate NODE_VM_SIZE (see http://aka.ms/allocation-guidance)." >&2
else
  export NODE_VM_SIZE=${SELECTED_SKU}
  echo "PRECHECK SUMMARY: NODE_VM_SIZE=${NODE_VM_SIZE}; per-node vCPUs=${SELECTED_VCPUS}; total required=$(( SELECTED_VCPUS * NODE_COUNT ))." >&2
fi
```

The pre-flight routine finalizes `NODE_VM_SIZE` by selecting the first SKU that
is both region available and within remaining regional vCPU quota. The
following command provisions the AKS cluster using the resolved size together
with OIDC issuer and workload identity features. If the summary indicated no
viable SKU was found the create step may fail; adjust `NODE_VM_SIZE`, reduce
`NODE_COUNT`, or request additional quota before re-running.

The OIDC issuer and workload identity features let
Kubernetes service accounts securely obtain short-lived tokens that Azure AD
can exchange for managed identity access (no node-level identity agents or
long-lived secrets). The cluster exposes an OpenID Connect (OIDC) discovery
endpoint for this purpose. The flags `--enable-oidc-issuer` (publishes the
discovery endpoint) and `--enable-workload-identity` (enables token federation)
activate this capability, reducing secret sprawl and simplifying identity
governance.

```bash
AKS_CREATE_CMD=(az aks create \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${AKS_NAME}" \
  --location "${AZURE_LOCATION}" \
  --node-count "${NODE_COUNT}" \
  --node-vm-size "${NODE_VM_SIZE}" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --ssh-access disabled \
  --tags env=${TAG_ENV} system=mcp)

if [ -n "${K8S_VERSION}" ]; then
  AKS_CREATE_CMD+=(--kubernetes-version "${K8S_VERSION}")
fi
if az acr show -n "${ACR_NAME}" -g "${AZURE_RESOURCE_GROUP}" >/dev/null 2>&1; then
  AKS_CREATE_CMD+=(--attach-acr "${ACR_NAME}")
fi

"${AKS_CREATE_CMD[@]}"
```

Note: If an alternate size is selected automatically verify your container
images support the architecture (ARM vs AMD64). Override by exporting a
different `NODE_VM_SIZE` prior to running this step.

Summary: The AKS cluster is created with optional ACR integration and workload
identity features enabled.

### 5. Retrieve kubeconfig

Download and merge cluster credentials into the local kubeconfig for kubectl.

```bash
az aks get-credentials \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${AKS_NAME}" \
  --overwrite-existing

kubectl cluster-info
```

Summary: kubectl now targets the provisioned AKS cluster.

### 6. Create namespace

Create a dedicated namespace for KMCP system components to keep separation.

```bash
kubectl create namespace "${KMCP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
```

Summary: Namespace for KMCP is present or confirmed.

### 7. Install KMCP CRDs and control plane (Helm OCI)

First ensure the `kmcp` CLI is available locally. This helper command is used
after the Helm installs for additional KMCP-specific operations. The following
block checks for the binary and installs it if missing (idempotent safe):

```bash
# Ensure KMCP CLI installed
if ! command -v kmcp >/dev/null 2>&1; then
  echo "KMCP CLI not found - installing..." >&2
  curl -fsSL https://raw.githubusercontent.com/kagent-dev/kmcp/refs/heads/main/scripts/get-kmcp.sh | bash
  if ! command -v kmcp >/dev/null 2>&1; then
    echo "KMCP CLI installation failed." >&2
  else
    echo "KMCP CLI installed at $(command -v kmcp)" >&2
  fi
else
  echo "KMCP CLI present: $(command -v kmcp)" >&2
fi

kmcp version 2>/dev/null || true
```

Now we can install (or upgrade) the CRDs chart (idempotent), then the core control
plane chart. Use `--version` for reproducibility. Provider credentials should ideally be injected via a Kubernetes Secret mounted or values
file, but a quick-start inline `--set` is shown conditionally.

```bash
helm upgrade --install "${KMCP_CRDS_RELEASE}" \
  "${KMCP_OCI_BASE}/${KMCP_CRDS_CHART}" \
  --version "${KMCP_VERSION}" \
  --namespace "${KMCP_NAMESPACE}" \
  --create-namespace

kmcp install
```

Summary: KMCP CRDs and core control plane have been installed (or upgraded)
using correct OCI chart paths.

### 8. Wait for KMCP pods to become Ready

Monitor rollout status to ensure KMCP components are operational.

```bash
kubectl get pods -n "${KMCP_NAMESPACE}" -o wide

END=$((SECONDS + WAIT_ROLLOUT))
while [ $SECONDS -lt $END ]; do
  NOT_READY=$(kubectl get pods -n "${KMCP_NAMESPACE}" \
    --no-headers 2>/dev/null | awk '{print $3}' | grep -Ev 'Running|Completed' | wc -l)
  if [ "${NOT_READY}" -eq 0 ]; then
    echo "All KMCP pods Ready."; break
  fi
  echo "Waiting for KMCP pods..."; sleep 10
done
```

Summary: KMCP pods have been verified. Investigate any CrashLoopBackOff before
continuing.

### 9. Cleanup (optional)

Delete created resources to avoid ongoing costs when the environment is no
longer needed.

```bash
az group delete --name "${AZURE_RESOURCE_GROUP}" --yes --no-wait
```

Summary: Resource group deletion schedules removal of all contained assets.

## Summary

An AKS cluster was provisioned, optional ACR created, and the KMCP control
plane installed via Helm. Verification steps confirmed that pods are running
and CRDs are registered. The environment is now ready for deploying MCP
servers (for example the Echo MCP server) using the KMCP APIs.

## Next Steps

Recommended follow-on actions:

- [Build an Echo MCP](Create_Echo_MCP_Server.md)
- [Deploy an MCP server](Deploy_MCP_Server.md)
