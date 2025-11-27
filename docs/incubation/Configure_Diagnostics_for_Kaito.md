# Configure KAITO Diagnostic Settings on AKS

## Introduction

This executable document configures diagnostic settings for an AKS
cluster running KAITO, sending control plane logs and metrics to a Log
Analytics workspace.

Summary: Enables centralized logging and metrics for KAITO-enabled AKS
clusters.

## Prerequisites

You must have an AKS cluster with KAITO installed and Azure CLI access.

- Completed [Installing Kaito on Azure Kubernetes Service (AKS)](Install_Kaito_On_AKS.md)

```bash
command -v az >/dev/null || echo "Azure CLI missing"
```

Summary: Confirms Azure CLI is available and KAITO is already running.

## Setting up the environment

Define subscription, resource group, cluster name, and location
variables.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"  # YYMMDDHHMM stamp
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-kaito-rg_${HASH}}"
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-kaito-cluster_${HASH}}"
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"

VARS=(
  HASH
  AZURE_SUBSCRIPTION_ID
  AZURE_RESOURCE_GROUP
  AKS_CLUSTER_NAME
  AZURE_LOCATION
)

for v in "${VARS[@]}"; do
  printf "%s=%s\n" "$v" "${!v}"
done
```

Summary: Establishes cluster identity and location for diagnostics.

## Steps

### Create Log Analytics workspace

Create or reuse a Log Analytics workspace for KAITO diagnostics.

```bash
LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace create \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --workspace-name "kaito-logs-${HASH}" \
  --location "${AZURE_LOCATION}" \
  --query id -o tsv)

echo "LOG_ANALYTICS_WORKSPACE_ID=${LOG_ANALYTICS_WORKSPACE_ID}"
```

Summary: Ensures a Log Analytics workspace exists for receiving AKS
logs and metrics.

### Configure AKS diagnostic settings

Wire AKS control plane logs and all metrics to the workspace.

```bash
az monitor diagnostic-settings create \
  --name "kaito-cluster-diagnostics" \
  --resource "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${AKS_CLUSTER_NAME}" \
  --workspace "${LOG_ANALYTICS_WORKSPACE_ID}" \
  --logs '[{"category":"kube-apiserver","enabled":true},{"category":"kube-controller-manager","enabled":true}]' \
  --metrics '[{"category":"AllMetrics","enabled":true}]'
```

Summary: Sends key AKS control plane logs and metrics to Log
Analytics.

## Verification

Confirm that diagnostic settings are configured on the cluster.

```bash
az monitor diagnostic-settings list \
  --resource "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${AKS_CLUSTER_NAME}" \
  --output table
```

Summary: Confirms the presence of the diagnostic settings entry for the
AKS cluster.

## Summary

This document created a Log Analytics workspace and configured AKS
diagnostic settings to send KAITO-related logs and metrics for
analysis.

Summary: Centralizes observability data for KAITO-enabled AKS
clusters.

## Next Steps

- Build dashboards and alerts over the Log Analytics workspace.
- Add diagnostic settings for additional Azure resources supporting
  KAITO workloads.
