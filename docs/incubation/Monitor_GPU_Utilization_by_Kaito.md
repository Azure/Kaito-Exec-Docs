# Monitor KAITO GPU Utilization

## Introduction

This executable document demonstrates how to monitor GPU-related
utilization for KAITO workloads on AKS using Azure Monitor metrics and
`kubectl top`.

Summary: Provides basic observability for GPU-capable nodes running
KAITO workspaces.

## Prerequisites

You must have KAITO running on AKS with GPU nodes provisioned.

- Completed [Installing Kaito on Azure Kubernetes Service (AKS)](Install_Kaito_On_AKS.md)

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v kubectl >/dev/null || echo "kubectl missing"
```

Summary: Confirms both Azure CLI and kubectl are installed.

## Setting up the environment

Define variables for subscription, node resource group, and label
selector.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"  # YYMMDDHHMM stamp
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-kaito-rg_${HASH}}"
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-kaito-cluster_${HASH}}"
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"
export AZURE_NODE_RESOURCE_GROUP="${AZURE_NODE_RESOURCE_GROUP:-MC_${AZURE_RESOURCE_GROUP}_${AKS_CLUSTER_NAME}_${AZURE_LOCATION}}"
export GPU_NODE_LABEL_SELECTOR="${GPU_NODE_LABEL_SELECTOR:-apps=phi-4}"

VARS=(
  HASH
  AZURE_SUBSCRIPTION_ID
  AZURE_RESOURCE_GROUP
  AKS_CLUSTER_NAME
  AZURE_LOCATION
  AZURE_NODE_RESOURCE_GROUP
  GPU_NODE_LABEL_SELECTOR
)

for v in "${VARS[@]}"; do
  printf "%s=%s\n" "$v" "${!v}"
done
```

Summary: Sets the context needed to query metrics and target GPU nodes.

## Steps

### Query Azure Monitor metrics for GPU nodes

Use Azure Monitor metrics to inspect CPU usage over the last hour for
GPU node scale sets.

```bash
az monitor metrics list \
  --resource "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_NODE_RESOURCE_GROUP}" \
  --resource-type "Microsoft.Compute/virtualMachineScaleSets" \
  --metric "Percentage CPU" \
  --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --interval PT1M \
  --aggregation Average
```

Summary: Retrieves recent CPU utilization metrics for GPU node scale
sets.

### Use kubectl top to view node resource usage

Use `kubectl top` to view live usage for nodes labeled for KAITO
workspaces.

```bash
kubectl top nodes -l "${GPU_NODE_LABEL_SELECTOR}"
```

Summary: Shows current resource usage for GPU nodes hosting KAITO
workloads.

## Verification

Re-run the metric and `kubectl top` commands to confirm they return
sensible values over time.

```bash
echo "Re-checking node usage..."
kubectl top nodes -l "${GPU_NODE_LABEL_SELECTOR}"
```

Summary: Confirms that GPU nodes remain observable and responsive.

## Summary

This document provided commands to inspect utilization of GPU-capable
nodes running KAITO workloads using Azure Monitor and `kubectl top`.

Summary: Establishes a simple baseline for monitoring KAITO GPU
utilization.

## Next Steps

- Integrate metrics with dashboards or alerts in Azure Monitor.
- Add pod-level observability using `kubectl top pods` and traces.
