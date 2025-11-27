# Create Azure AKS Infrastructure

## Introduction

This executable document provisions the core Azure resources required for a
production-ready AKS deployment. It validates Azure access, creates a resource
group, deploys a baseline AKS cluster, and optionally adds an additional node
pool for user workloads. All commands rely on parameterized environment
variables so the workflow remains repeatable across regions and subscriptions.

Summary:

- Builds the foundational Azure infrastructure for a generic AKS cluster
  that can host any containerized workload, without assuming any specific
  container registry configuration.

## Prerequisites

The following tooling and account access are required before running the guide.
Ensure you are authenticated to Azure using `az login` and have sufficient
permissions to create resource groups, container registries, and AKS clusters.

- Azure subscription with quota for the selected region
- Azure CLI (`az`) with Owner or Contributor rights
- kubectl configured locally for cluster access
- jq (optional) for parsing JSON output during verification

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v kubectl >/dev/null || echo "kubectl missing"
command -v jq >/dev/null || echo "jq missing (optional)"
```

### Setting up the environment

Define all environment variables used throughout the provisioning steps. If any of
these values are already set then the current value will be used.

The `HASH` timestamp keeps resource names unique during repeated executions.
Cluster defaults target a minimal proof-of-concept footprint but can be
adjusted as needed.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"  # YYMMDDHHMM stamp

# Azure scope and regional placement (normalized names)
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg_aks_${HASH}}"

# AKS cluster naming and version control
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-${HASH}}"
export AKS_VERSION="${AKS_VERSION:-}"  # Optional Kubernetes version override

# Node pool sizing
export AKS_SYSTEM_NODE_COUNT="${AKS_SYSTEM_NODE_COUNT:-1}"
export AKS_USER_NODE_COUNT="${AKS_USER_NODE_COUNT:-1}"
export AKS_NODE_VM_SIZE="${AKS_NODE_VM_SIZE:-Standard_D4s_v5}"
export AKS_SYSTEM_NODEPOOL_NAME="${AKS_SYSTEM_NODEPOOL_NAME:-system}"
export AKS_USER_NODEPOOL_NAME="${AKS_USER_NODEPOOL_NAME:-user}"
```

Summary:

- Confirms the necessary CLI tooling and Azure access are in place.
- Establishes Azure scope and AKS sizing for the provisioning sequence
  regardless of downstream workloads.

## Steps

Execute each step sequentially. Every subsection includes purpose, commands,
and a summary to confirm expected outcomes.

### Check Azure subscription context

Verify the active Azure subscription and ensure the resource providers required
for AKS operations are registered.

```bash
az account show --query id -o tsv
az provider register --namespace Microsoft.ContainerService
```

Summary:

- Azure subscription context confirmed and required providers registered.

### Create resource group

Provision a dedicated resource group to isolate the AKS cluster, registry, and
supporting infrastructure for your workloads.

```bash
az group create \
  --name "${AZURE_RESOURCE_GROUP}" \
  --location "${AZURE_LOCATION}" \
  --output table
```

Summary:

- Resource group created in the target region for subsequent resources.

### Create AKS cluster

Deploy the AKS cluster that will host your workloads. Guard against
re-using an existing cluster name by checking before creation.

```bash
if az aks show \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "AKS cluster ${AKS_CLUSTER_NAME} already exists in ${AZURE_RESOURCE_GROUP}";
  echo "Skip creation or provide a new AKS_CLUSTER_NAME.";
else
  az aks create \
    --name "${AKS_CLUSTER_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_LOCATION}" \
    --generate-ssh-keys \
    --node-count "${AKS_SYSTEM_NODE_COUNT}" \
    --nodepool-name "${AKS_SYSTEM_NODEPOOL_NAME}" \
    --node-vm-size "${AKS_NODE_VM_SIZE}" \
    ${AKS_VERSION:+--kubernetes-version "${AKS_VERSION}"} \
    --output table
fi
```

Summary:

- AKS cluster created (or an existing one detected) in the specified
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
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AKS_USER_NODEPOOL_NAME}" >/dev/null 2>&1; then
    echo "Node pool ${AKS_USER_NODEPOOL_NAME} already exists; skipping add.";
  else
    az aks nodepool add \
      --cluster-name "${AKS_CLUSTER_NAME}" \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${AKS_USER_NODEPOOL_NAME}" \
      --node-count "${AKS_USER_NODE_COUNT}" \
      --node-vm-size "${AKS_NODE_VM_SIZE}" \
      --no-wait
    az aks nodepool wait \
      --cluster-name "${AKS_CLUSTER_NAME}" \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${AKS_USER_NODEPOOL_NAME}" \
      --created
  fi
fi
```

Summary:

- Optional user node pool provisioned (or detected) with Azure confirming
  creation before continuing.

### Retrieve cluster credentials

Merge the AKS kubeconfig into the local context and verify all nodes are
reachable.

```bash
az aks get-credentials \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --overwrite-existing
kubectl get nodes -o wide
```

Summary:

- kubectl context updated and node connectivity verified.

## Verification

Confirm the AKS cluster exists and responds to basic `kubectl` queries before
continuing to downstream deployment steps. Starting with ensuring the AKS cluster
exists.

```bash
if ! az aks show \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --query "{name:name,provisioningState:provisioningState,location:location}" \
  --output table; then
  echo "AKS cluster '${AKS_CLUSTER_NAME}' not found in resource group '${AZURE_RESOURCE_GROUP}'."
else
  echo "AKS cluster '${AKS_CLUSTER_NAME}' exists in resource group '${AZURE_RESOURCE_GROUP}'."
fi
```

If the AKS cluster has been created you will see something like:

<!-- expected_similarity=".*exists.*" -->

```text
AKS cluster ${AKS_CLUSTER_NAME} exists in resource group ${AZURE_RESOURCE_GROUP}.
```

Next we check that `kubectl` is correctly configured.

```bash
az aks get-credentials \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --overwrite-existing

kubectl cluster-info
```

This command will output status of the current cluster, something like:

<!-- expected_similarity="(?s).*control plane is running.*" -->

```text
Kubernetes control plane is running at ...
CoreDNS is running at https://...
Metrics-server is running at https://...
```

Now, lets ensure that there are both system and user nodes available.

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.labels.agentpool}{"\n"}{end}' |
  sort |
  uniq -c
```

This will output a count of nodes, something like:

<!-- expected_similarity=".*[0-9]+.*system\n.*[0-9]+.*user" -->

```text
      1 system
      1 user
```

### Environment Variables

For convenience, dump key environment variables to the console for
inspection. Extend this list as needed, following the ALL_CAPS naming
convention.

```bash
VARS=(
  HASH
  AZURE_
  AKS_
)

for prefix in "${VARS[@]}"; do
  echo "=== Variables starting with ${prefix} ==="
  while IFS= read -r var_name; do
    if [[ "${var_name}" == "${prefix}"* ]]; then
      printf "  %s=%s\n" "${var_name}" "${!var_name}"
    fi
  done < <(compgen -v | sort)
  echo
done
```

Summary:

- Validated that the AKS cluster is present, healthy, and reachable via
  kubectl in the current context.
- Prints the active parameters grouped by prefix to validate naming,
  sizing, and regional choices.

## Summary

The resource group, AKS cluster, and optional node pool are validated, leaving
the cluster ready for any containerized workloads. Use the dedicated ACR
deployment document if you need a private container registry attached to this
cluster.

Summary:

- AKS infrastructure is provisioned and verified as ready for workloads.

## Next Steps

- Proceed with `docs/OpenWebSearch_On_AKS.md` to deploy KMCP and the MCP server
- Configure role assignments or network policies specific to your security
  posture
- Integrate Azure Monitor or Log Analytics for operational visibility
- Run infrastructure cleanup commands after experimentation to manage costs
