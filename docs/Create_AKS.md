# Create Azure AKS Infrastructure for Open-WebSearch

## Introduction

This executable document provisions the Azure resources required before
deploying the Open-WebSearch MCP server. It validates Azure access, creates a
resource group, establishes an Azure Container Registry (ACR), deploys an AKS
cluster, optionally adds a user node pool, and grants the cluster permission to
pull from the registry. All commands rely on parameterized environment
variables so the workflow remains repeatable across regions and subscriptions.

Summary: Prepares Azure networking and compute foundations for the
Open-WebSearch MCP deployment.

## Prerequisites

The following tooling and account access are required before running the guide.
Ensure you are already authenticated to Azure using `az login`.

- Azure subscription with quota for the target region
- Azure CLI (`az`) with sufficient permissions (Resource Group, ACR, AKS)
- kubectl for retrieving cluster credentials
- jq (optional) for parsing JSON output during verification

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v kubectl >/dev/null || echo "kubectl missing"
command -v jq >/dev/null || echo "jq missing (optional)"
```

Summary: Confirms the necessary CLI tooling and Azure access are in place.

## Setting up the environment

Define all environment variables used throughout the provisioning steps. The
`HASH` timestamp keeps resource names unique during repeated executions. Cluster
and registry defaults target a minimal proof-of-concept footprint but can be
adjusted as needed.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"  # YYMMDDHHMM stamp

# Azure scope and regional placement
export LOCATION="${LOCATION:-eastus2}"
export SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export RESOURCE_GROUP="${RESOURCE_GROUP:-rg_openwebsearch_${HASH}}"

# AKS cluster naming and version control
# Hyphen required because AKS cluster names cannot include underscores
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-openwebsearch-${HASH}}"
export AKS_VERSION="${AKS_VERSION:-}"  # Optional Kubernetes version override

# Node pool sizing
export AKS_SYSTEM_NODE_COUNT="${AKS_SYSTEM_NODE_COUNT:-1}"
export AKS_USER_NODE_COUNT="${AKS_USER_NODE_COUNT:-1}"
export AKS_NODE_VM_SIZE="${AKS_NODE_VM_SIZE:-Standard_D4s_v5}"
export AKS_SYSTEM_NODEPOOL_NAME="${AKS_SYSTEM_NODEPOOL_NAME:-system}"
export AKS_USER_NODEPOOL_NAME="${AKS_USER_NODEPOOL_NAME:-user}"

# ACR configuration
export ACR_NAME="${ACR_NAME:-acrwebsearch${HASH}}"
export ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-${ACR_NAME}.azurecr.io}"
```

Summary: Establishes Azure scope, AKS sizing, and ACR naming conventions for the
provisioning sequence.

### Verify environment variable values

Review the effective configuration before creating resources. Re-run the block
after any adjustments to ensure the active values are correct for the target
subscription and region.

```bash
: "${HASH:=$(date -u +"%y%m%d%H%M")}"  # Ensure HASH exists

VARS=(
  HASH
  LOCATION
  SUBSCRIPTION_ID
  RESOURCE_GROUP
  AKS_CLUSTER_NAME
  AKS_VERSION
  AKS_SYSTEM_NODE_COUNT
  AKS_USER_NODE_COUNT
  AKS_NODE_VM_SIZE
  AKS_SYSTEM_NODEPOOL_NAME
  AKS_USER_NODEPOOL_NAME
  ACR_NAME
  ACR_LOGIN_SERVER
)
for v in "${VARS[@]}"; do
  printf "%s=%s\n" "$v" "${!v}"
done
```

Summary: Prints the active parameters to validate naming, sizing, and regional
choices.

## Steps

Execute each step sequentially. Every subsection includes purpose, commands,
and a summary to confirm expected outcomes.

### Check Azure subscription context

Verify the active Azure subscription and ensure the resource providers required
for AKS and ACR operations are registered.

```bash
az account show --query id -o tsv
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
```

Summary: Azure subscription context confirmed and required providers registered.

### Create resource group

Provision a dedicated resource group to isolate all AKS and ACR assets for the
Open-WebSearch deployment.

```bash
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output table
```

Summary: Resource group created in the target region for subsequent resources.

### Provision Azure Container Registry

Create an Azure Container Registry for storing the Open-WebSearch container
image and authenticate the local Docker daemon to push images.

```bash
az acr create \
  --name "${ACR_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Basic \
  --output table
az acr login --name "${ACR_NAME}"
```

Summary: ACR provisioned and local Docker client authenticated for pushes.

### Create AKS cluster

Deploy the AKS cluster that will host the Open-WebSearch MCP server. Guard
against re-using an existing cluster name by checking before creation.

```bash
if az aks show \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "AKS cluster ${AKS_CLUSTER_NAME} already exists in ${RESOURCE_GROUP}";
  echo "Skip creation or provide a new AKS_CLUSTER_NAME.";
else
  az aks create \
    --name "${AKS_CLUSTER_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --generate-ssh-keys \
    --node-count "${AKS_SYSTEM_NODE_COUNT}" \
    --nodepool-name "${AKS_SYSTEM_NODEPOOL_NAME}" \
    --node-vm-size "${AKS_NODE_VM_SIZE}" \
    ${AKS_VERSION:+--kubernetes-version "${AKS_VERSION}"} \
    --output table
fi
```

Summary: AKS cluster created (or an existing one detected) in the specified
resource group.

### Add optional user node pool

Provision an additional node pool when requested. The add command runs
asynchronously to avoid CLI timeouts; the wait command tracks Azure's progress.
The script first checks whether the pool already exists to prevent duplicate
name errors.

```bash
if [ "${AKS_USER_NODE_COUNT}" -gt 0 ]; then
  if az aks nodepool show \
    --cluster-name "${AKS_CLUSTER_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_USER_NODEPOOL_NAME}" >/dev/null 2>&1; then
    echo "Node pool ${AKS_USER_NODEPOOL_NAME} already exists; skipping add.";
  else
    az aks nodepool add \
      --cluster-name "${AKS_CLUSTER_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${AKS_USER_NODEPOOL_NAME}" \
      --node-count "${AKS_USER_NODE_COUNT}" \
      --node-vm-size "${AKS_NODE_VM_SIZE}" \
      --no-wait
    az aks nodepool wait \
      --cluster-name "${AKS_CLUSTER_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${AKS_USER_NODEPOOL_NAME}" \
      --created
  fi
fi
```

Summary: Optional user node pool provisioned (or detected) with Azure confirming
creation before continuing.

### Retrieve cluster credentials

Merge the AKS kubeconfig into the local context and verify all nodes are
reachable.

```bash
az aks get-credentials \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --overwrite-existing
kubectl get nodes -o wide
```

Summary: kubectl context updated and node connectivity verified.

### Attach ACR to AKS cluster

Grant the AKS cluster permission to pull images from the provisioned ACR so
future deployments can access the Open-WebSearch containers.

```bash
az aks update \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --attach-acr "${ACR_NAME}" \
  --output table
```

Summary: AKS cluster now has pull rights to the Azure Container Registry.

## Summary

Azure prerequisites for the Open-WebSearch MCP deployment are complete. The
resource group, container registry, AKS cluster, optional node pool, and registry
attachment are all validated, leaving the cluster ready for MCP-specific
configuration.

## Next Steps

- Proceed with `docs/OpenWebSearch_On_AKS.md` to deploy KMCP and the MCP server
- Configure role assignments or network policies specific to your security
  posture
- Integrate Azure Monitor or Log Analytics for operational visibility
- Run infrastructure cleanup commands after experimentation to manage costs
