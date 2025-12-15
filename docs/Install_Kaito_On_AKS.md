# Installing Kaito on Azure Kubernetes Service (AKS)

## Introduction

This executable guide explains how to install KAITO (Kubernetes AI Toolchain
Operator) on an Azure Kubernetes Service (AKS) cluster. KAITO simplifies the
deployment of large language models and other AI workloads by automating GPU
node provisioning, model installation, and inference service configuration.

The workflow sets up the KAITO workspace controller, configures
auto-provisioning with Azure GPU Provisioner for dynamic GPU node management,
and validates the installation. All commands use environment variables so the
procedure can be reused across different clusters and configurations.

Summary:

- Provides an end-to-end, variable-driven deployment of KAITO on AKS with
  automatic GPU node management.

## Prerequisites

Before starting, ensure Azure access, the tooling required for KAITO deployments,
the parameters of the deployment are set and necessary Azure resources are
allocated.

### Required CLI tools

This executable document requires that a number of CLI tools are available.

- Azure CLI (`az`) with an authenticated session (`az login`)
- `jq` for inspecting JSON payloads during validation

The following commands will validate these dependencies, and where necessary will
install or update them.

```bash
MIN_AZ_VERSION="2.80.0"

version_ge() {
  # returns 0 (true) if $1 >= $2
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

if ! command -v az >/dev/null; then
  echo "Azure CLI missing, installing..."
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
  echo "Checking Azure CLI version..."
  az_version=$(az --version 2>/dev/null | awk '/azure-cli/ {print $2; exit}')
  echo "Found azure-cli ${az_version}"

  if ! version_ge "${az_version}" "${MIN_AZ_VERSION}"; then
    echo "Azure CLI version is below ${MIN_AZ_VERSION}, upgrading..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  fi
fi

if command -v az >/dev/null; then
  echo "Azure CLI is installed."
fi
```

The above commands ensure that the installed version of the az CLI tool meets the minimum required version. The ouput should look something like this:

<!-- expected_similarity="Azure CLI is installed\." -->

```text
Azure CLI missing, installing...

Azure CLI is installed.
```

We use `jq` to parse JSON response from some commands.

```bash
if ! command -v jq >/dev/null; then
  echo "jq missing, installing..."
  if command -v apt-get >/dev/null; then
    sudo apt-get update && sudo apt-get install -y jq
  elif command -v yum >/dev/null; then
    sudo yum install -y jq
  elif command -v brew >/dev/null; then
    brew install jq
  else
    echo "Package manager not found. Please install jq manually."
    exit 1
  fi
fi

echo "jq is installed."
```

These commands check `jq` is installed and attempt to install it if it is missing.

<!-- expected_similarity="jq is installed\." -->

```text
jq missing, installing...

jq is installed.
```

These commands confirm tooling availability and bootstrap any missing CLI
dependencies before continuing.

### Deployment Configuration

To facilitate reuse we will export the environment variables that define our
provisioning options and validation helpers. Note that if a variable already
has a value that value will be given preference, this means you can set any of
these values manually if you so desire, these commands will not override your
chosen values.

Unique names append a timestamp based `HASH` suffix to prevent collisions.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-kaito-rg-${HASH}}"
export AZURE_VM_SIZE="${AZURE_VM_SIZE:-Standard_NC40ads_H100_v5}"

echo "HASH=${HASH}"
echo "AZURE_LOCATION=${AZURE_LOCATION}"
echo "AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}"
echo "AZURE_VM_SIZE=${AZURE_VM_SIZE}"
```

This command seeds the `HASH` variable so every resource created in the
remaining steps gains a predictable, unique suffix and establishes defaults for
the Azure location, resource group and KAITO workspace VM size.

<!-- expected_similarity="AZURE_LOCATION=.*" -->

```text
HASH= 2512021200
AZURE_LOCATION=eastus2
AZURE_RESOURCE_GROUP=kaito-rg-2512021200
AZURE_VM_SIZE=Standard_NC40ads_H100_v5
```

### GPU Quota

In order to deploy KAITO workloads we will need sufficient GPUs available to our
subscription. Since deploying this entire infrastructure is time consuming and incurs costs it is worth checking the availability of quota in your subscription before progressing. GPU quota validation is captured in a dedicated executable document
so it can be reused across KAITO and other GPU workloads.

Execute the quota check executable doc: [Check GPU Quota for KAITO on AKS](Check_VM_Quota.md). This document has defaults for the required variables, of course, you could override them in your environment if you wanted to.

### AKS Cluster

KAITO requires an AKS cluster and `kubectl` to be configured to use it. If you have one already then the following environment variables need to be set accordingly. If you do not have one yet then we will configure it here:

```bash
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-kaito-cluster_${HASH}}"
```

This variable sets the target AKS cluster name, defaulting to a unique value
derived from the shared HASH suffix.

By following the executable guide [Creating an AKS Cluster](Create_AKS.md) we can ensure that the required AKS cluster is already available, or is created and that `kubectl` is configured to operate on it.

### Summary

- Established reproducible defaults and printed the resulting configuration for quick review before provisioning.
- Validated that GPU quota is available using `Check_GPU_Quota_For_Kaito.md`.
- Ensured that there is an active AKS cluster.

## Steps

Follow each step to enable the AI toolchain operator add-on for KAITO and
validate that the KAITO platform is ready to host workspaces.

### Enable the AI toolchain operator add-on

Enable the AI toolchain operator add-on, OIDC issuer, and Node Autoprovision
on the existing AKS cluster. Node Autoprovision mode is required for KAITO to
dynamically create GPU agent pools when workspaces are deployed.

```bash
az aks update \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --enable-ai-toolchain-operator \
  --enable-oidc-issuer \
  --node-provisioning-mode Auto
```

This command will output a JSON file desbribing the AKS cluster, within it you should find confirmation that KAITO has been enabled:

<!-- expected_similarity="\"aiToolchainOperatorProfile\":\s*{\s*\"enabled\":\s*true\s*}" -->

```text
  "aiToolchainOperatorProfile": {
    "enabled": true
  }
```

Summary:

- AKS cluster is updated to enable the AI toolchain operator add-on, OIDC
  issuer, and automatic node provisioning for dynamic GPU pool creation.

### Configure service account and restart controller

Bind the KAITO workspace controller to the managed identity so it can call
Azure APIs (GPU Provisioner, Marketplace, storage) without embedding
credentials. The service account annotation advertises which identity to use
for workload identity token exchange.

To do this we will first grab the client id:

```bash
export AZURE_NODE_RESOURCE_GROUP="MC_${AZURE_RESOURCE_GROUP}_${AKS_CLUSTER_NAME}_\
${AZURE_LOCATION}"
export AI_TOOLCHAIN_CLIENT_ID=$(az identity list \
  --resource-group "${AZURE_NODE_RESOURCE_GROUP}" \
  --query "[?contains(name, 'ai-toolchain')].clientId" -o tsv)

echo "Client ID: ${AI_TOOLCHAIN_CLIENT_ID}"
```

These commands capture the managed identity's client ID so it can be referenced
when configuring workload identity.

Once we have the ID we can annotate and label the workspace.

```bash
kubectl annotate serviceaccount kaito-workspace \
  -n kube-system \
  azure.workload.identity/client-id="${AI_TOOLCHAIN_CLIENT_ID}" \
  --overwrite

kubectl label serviceaccount kaito-workspace \
  -n kube-system \
  azure.workload.identity/use=true \
  --overwrite
```

These commands bind the `kaito-workspace` service account to the managed
identity so pods issued under it can request Azure tokens via workload
identity federation.

Restarting the controller forces it to reload those annotations immediately.

```bash
kubectl rollout restart deployment kaito-workspace -n kube-system

echo "Waiting for controller to restart..."
kubectl rollout status deployment kaito-workspace -n kube-system --timeout=60s
```

This restart ensures the controller reloads the updated service account and
begins using the workload identity mapping immediately.

Summary:

- Service account configured with workload identity and controller restarted to
  enable authentication.

## Verification

Check whether KAITO is deployed and operational by verifying the
workspace controller, federated identity credential, RBAC assignments, and
workspace status. If all checks pass, the document has already been executed
successfully and can be skipped.

```bash
echo "=== Checking AI Toolchain Operator Status ==="
AI_ENABLED=$(az aks show \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --query "aiToolchainOperatorProfile.enabled" -o tsv 2>/dev/null)

if [ "${AI_ENABLED}" != "true" ]; then
  echo "FAIL: AI toolchain operator not enabled"
  exit 1
fi

echo ""
echo "=== Checking KAITO Workspace Controller ==="
KAITO_READY=$(kubectl get deployment kaito-workspace -n kube-system \
  -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")

if [ "${KAITO_READY}" -lt 1 ]; then
  echo "FAIL: KAITO workspace controller not ready"
  exit 1
fi
echo "PASS: KAITO workspace controller running"

echo ""
echo "=== Checking Service Account Annotation ==="
SA_CLIENT_ID=$(kubectl get serviceaccount kaito-workspace -n kube-system \
  -o jsonpath='{.metadata.annotations.azure\.workload\.identity/client-id}' \
  2>/dev/null)

if [ -z "${SA_CLIENT_ID}" ]; then
  echo "FAIL: Service account not annotated with client ID"
  exit 1
fi
echo "PASS: Service account configured for workload identity"

echo ""
echo "=== All platform verification checks passed ==="
echo "KAITO is fully deployed and ready to host workspaces."
exit 0
```

This verification script confirms the add-on, controller, and workspace are in
a healthy state before skipping the rest of the document.

### Environment Variables

For convenience we will dump the environment variables used in this deployment to the console for inspection.

```bash
VARS=(
  HASH
  AZURE_
  AKS_
  KAITO_
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

- Verification checks confirm KAITO components are deployed, authenticated,
  and operational without making any modifications.

## Summary

You enabled the AI toolchain operator add-on on AKS, configured workload
identity with federated credentials and RBAC permissions, and validated that
the KAITO workspace controller is healthy and ready. The KAITO platform is now
ready to host KAITO workspaces and deploy AI models.

## Next Steps

Consider extending the deployment with one or more of the following
executable documents:

- [Request GPU Quota Increase for KAITO](Install_Kaito_Request_GPU_Quota_Increase.md)
- [Deploy a KAITO Phi-3 Workspace on AKS](incubation/Deploy_Kaito_Workspace.md)
- [Monitor KAITO GPU Utilization](Install_Kaito_Monitor_GPU_Utilization.md)
- [Configure KAITO Diagnostic Settings](Install_Kaito_Configure_Diagnostics.md)
- [Clean Up KAITO Resources](Install_Kaito_Cleanup_Resources.md)
