# Deploy Azure Container Registry for AKS

## Introduction

This executable guide provisions an Azure Container Registry (ACR) and
attaches it to an existing Azure Kubernetes Service (AKS) cluster. It
assumes the resource group and AKS cluster already exist, and focuses
only on the registry creation and cluster permissions required for
pulling images. All steps are parameterized via environment variables
for repeatable use across subscriptions and regions.

Summary: Creates an ACR and grants an existing AKS cluster permission
to pull images from it.

## Prerequisites

Before starting, ensure you have an existing AKS cluster and the
necessary Azure CLI tooling and permissions.

- Existing AKS cluster and resource group
- Azure subscription with quota in the selected region
- Azure CLI (`az`) logged in with sufficient rights
- `kubectl` configured (for later cluster workloads, not required here)

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v kubectl >/dev/null || echo "kubectl missing (optional)"
```

Summary: Confirms that Azure CLI is available and kubectl is installed
if you plan to deploy workloads after ACR setup.

## Setting up the environment

Define all environment variables used in this document. If any are
already set, those values are preserved. The `HASH` variable ensures
resource names remain unique across repeated executions.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"  # YYMMDDHHMM stamp

# Azure scope and placement
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg_aks_${HASH}}"

# AKS cluster name (must already exist)
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-openwebsearch-${HASH}}"

# ACR configuration
export ACR_NAME="${ACR_NAME:-acrwebsearch${HASH}}"
export ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-${ACR_NAME}.azurecr.io}"

# Summary variable list
VARS=(
  HASH
  AZURE_LOCATION
  AZURE_SUBSCRIPTION_ID
  AZURE_RESOURCE_GROUP
  AKS_CLUSTER_NAME
  ACR_NAME
  ACR_LOGIN_SERVER
)

for v in "${VARS[@]}"; do
  printf "%s=%s\n" "$v" "${!v}"
done
```

Summary: Establishes the ACR and AKS identifiers and prints their
values so you can confirm naming and regional choices before
provisioning.

## Steps

Follow these steps to create the ACR and attach it to the AKS cluster.

### Verify Azure subscription context

Confirm the active subscription and ensure the ACR and AKS resource
providers are registered.

```bash
az account show --query id -o tsv
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
```

Summary: Ensures Azure is targeting the expected subscription with
required providers available.

### Provision Azure Container Registry

Create the ACR in the specified resource group and region. If the
registry already exists, it is reused. The login command prepares the
local Docker client to push images.

```bash
if az acr show \
  --name "${ACR_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "ACR ${ACR_NAME} already exists in ${AZURE_RESOURCE_GROUP}; reusing existing registry"
else
  az acr create \
    --name "${ACR_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_LOCATION}" \
    --sku Basic \
    --output table
fi

az acr login --name "${ACR_NAME}"
```

Summary: ACR is created if needed and the local Docker client is
authenticated for image pushes.

### Attach ACR to AKS cluster

Grant the AKS cluster permission to pull images from the ACR. If the
`AcrPull` role assignment already exists, the step is skipped.

```bash
ACR_ID=$( \
  az acr show \
    --name "${ACR_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --query id \
    --output tsv
)

EXISTING_ACR=$( \
  az aks show \
    --name "${AKS_CLUSTER_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --query "servicePrincipalProfile.clientId" \
    --output tsv 2>/dev/null || echo "msi"
)

if [ "${EXISTING_ACR}" = "msi" ]; then
  KUBELET_IDENTITY_OBJECT_ID=$( \
    az aks show \
      --name "${AKS_CLUSTER_NAME}" \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --query "identityProfile.kubeletidentity.objectId" \
      --output tsv
  )
  ROLE_ASSIGNMENT=$( \
    az role assignment list \
      --assignee "${KUBELET_IDENTITY_OBJECT_ID}" \
      --scope "${ACR_ID}" \
      --role "AcrPull" \
      --query "[0].id" \
      --output tsv
  )
  if [ -n "${ROLE_ASSIGNMENT}" ]; then
    echo "ACR ${ACR_NAME} is already attached to AKS cluster ${AKS_CLUSTER_NAME}; skipping"
  else
    az aks update \
      --name "${AKS_CLUSTER_NAME}" \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --attach-acr "${ACR_NAME}" \
      --output table
  fi
else
  az aks update \
    --name "${AKS_CLUSTER_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --attach-acr "${ACR_NAME}" \
    --output table
fi
```

Summary: Ensures the AKS cluster identity has `AcrPull` rights on the
ACR, either reusing an existing assignment or creating a new
attachment.

## Verification

Run these checks to confirm that the ACR exists and the AKS cluster has
pull permissions.

```bash
az acr show \
  --name "${ACR_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --query "{name:name,loginServer:loginServer,location:location}" \
  --output table
```

```bash
az role assignment list \
  --scope "$(az acr show --name "${ACR_NAME}" --resource-group "${AZURE_RESOURCE_GROUP}" --query id -o tsv)" \
  --query "[?roleDefinitionName=='AcrPull'].[principalId,roleDefinitionName]" \
  --output table
```

Summary: Confirms the registry exists and that an identity associated
with the AKS cluster holds `AcrPull` rights on the registry scope.

## Summary

This document created or reused an Azure Container Registry and
attached it to an existing AKS cluster so workloads in the cluster can
pull private images from the registry.

Summary: ACR and AKS are now integrated, enabling secure image pulls
for workloads.

## Next Steps

- Push application images to the new ACR using `docker push` or Azure
  DevOps/GitHub Actions pipelines.
- Reference `ACR_LOGIN_SERVER` in your Kubernetes manifests or Helm
  charts for image locations.
- Combine this workflow with `docs/Create_AKS.md` or other cluster
  provisioning guides when building end-to-end environments.

Summary: You can now use the ACR as the primary image source for
applications running on your AKS cluster.
