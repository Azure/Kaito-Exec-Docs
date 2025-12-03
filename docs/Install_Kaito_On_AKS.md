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

### GPU Quota (Prerequisite)

In order to deploy KAITO workloads we will need sufficient GPUs available to our
subscription. Since deploying this entire infrastructure is time consuming and incurs costs it is worth checking the availability of quota in your subscription before progressing. GPU quota validation is captured in a dedicated executable document
so it can be reused across KAITO and other GPU workloads.

Execute the quota check executable doc: [Check GPU Quota for KAITO on AKS](Check_GPU_Quota_For_Kaito.md). This document has defaults for the required variables, of course, you could override them in your environment if you wanted to.

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
validate that a default hosted model can be deployed.

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

### Deploy a hosted Phi-3-mini-4k workspace

Deploy the Phi-3-mini-4k KAITO workspace using a generated YAML manifest so that
the workspace definition is version controlled alongside this document. The
GPU node provisioning takes several minutes.

```bash
cat > kaito_workspace_phi_3_mini.yaml <<EOF
apiVersion: kaito.sh/v1beta1
kind: Workspace
metadata:
  name: workspace-phi-3-mini
resource:
  instanceType: "${AZURE_VM_SIZE}"
  labelSelector:
    matchLabels:
      apps: phi-3
inference:
  preset:
    name: phi-3-mini-4k-instruct
EOF
kubectl apply -f kaito_workspace_phi_3_mini.yaml

echo "Workspace created (phi-3-mini-4k). Monitoring GPU node provisioning..."
echo "This typically takes 5-10 minutes for the node to provision and join."
sleep 30

kubectl get workspace workspace-phi-3-mini
kubectl get nodeclaim
```

This block applies the workspace CRD, waits briefly, and surfaces current
workspace and nodeclaim objects for a quick sanity check.

Summary:

- Phi-3-mini-4k workspace manifest is created locally, applied to the cluster,
  and initial status is displayed.

### Wait for GPU node and model deployment

Monitor the workspace until the GPU node provisions successfully and the
model deployment completes. This step polls status and waits for the
WORKSPACESUCCEEDED condition to become True.

```bash
echo "Waiting for GPU node provisioning for phi-3-mini-4k (this takes 5-10 minutes)..."
for i in {1..100}; do
  READY=$(kubectl get workspace workspace-phi-3-mini \
    -o jsonpath='{.status.conditions[?(@.type=="WorkspaceSucceeded")].status}' \
    2>/dev/null || echo "False")

  if [ "${READY}" = "True" ]; then

    kubectl get workspace workspace-phi-3-mini
    kubectl get nodes -l apps=phi-3
    echo "Workspace ready!"
    break
  fi

  echo "Attempt $i/100: Workspace phi-3-mini-4k not ready yet (status: ${READY})"
  sleep 15
done
```

This polling loop watches the workspace status until the `WorkspaceSucceeded`
condition flips to True or the retries are exhausted.

If GPUs are assigned and the workspace is marked as ready the final line of output will be:

<!-- expected_similarity=".*Workspace ready!" -->

```text
Workspace ready!
```

Summary:

- Waits for workspace readiness and verifies the GPU node has joined the
  cluster.

### Discover the inference service IP

Retrieve the service IP address for the Phi-3-mini-4k workspace so you can send a
test request.

```bash
export SERVICE_IP=$(kubectl get svc workspace-phi-3-mini \
  -o jsonpath='{.spec.clusterIP}')
echo "SERVICE_IP=${SERVICE_IP}"
```

This block queries the service resource and records its cluster IP for
subsequent inference tests.

Summary:

- Captures the cluster IP for the Phi-4-mini inference service.

### Test the Phi-3-mini-4k inference endpoint

Use a short sample prompt with the OpenAI-compatible completions API format to
verify that inference succeeds for the phi-3-mini-4k model. These steps create
a short-lived `curl` pod, wait for it to complete the request, and then print
only the response text from the model.

We'll start off by ensuring that the question pod isn't currently present. In a real world system we would likely want a pod that automatically maintained context, but for now we will keep things simple. If this is the first run there will be no question pod, so we need to ignore this case.

```bash
kubectl delete pod question --ignore-not-found
```

This guard removes any stale `question` pod so the upcoming run starts from a
clean slate.

Next, start a one-off `curl` pod to send the completion request to the
workspace service.

```bash
kubectl run question \
  --image=curlimages/curl \
  --restart=Never \
  -- \
  sh -c 'curl -sS -X POST "http://'"${SERVICE_IP}"'/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"phi-3-mini-4k-instruct\",\"messages\":[{\"role\":\"system\",\"content\":\"You are a programmer answers questions in a direct and concise way.\"},{\"role\":\"user\",\"content\":\"What is Python?\"}],\"max_tokens\":200}"' &
```

This block launches a one-off curl pod that issues a chat completions request
against the workspace service endpoint.

Wait briefly for the pod to start and complete the request, the pods logs will container the response.

```bash
for i in {1..20}; do
  phase=$(kubectl get pod question -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  if [ "$phase" = "Running" ] || [ "$phase" = "Succeeded" ] || [ "$phase" = "Failed" ]; then
    break
  fi
  sleep 1
done
```

This watch loop waits for the curl pod to reach a terminal phase before logs
are streamed.

Now stream the logs and extract only the completion text from the JSON
response using `jq`.

```bash
kubectl logs question | jq -r '.choices[0].message.content'
```

This command prints only the assistant response from the OpenAI-compatible
payload, making it easy to confirm inference quality.

Summary:

- Creates a temporary `curl` pod that calls the Phi-3-mini-4k inference
  endpoint using chat completions and prints the model's response via `jq`.

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
echo "=== Checking Phi-3-mini-4k Workspace ==="
WORKSPACE_STATUS=$(kubectl get workspace workspace-phi-3-mini \
  -o jsonpath='{.status.conditions[?(@.type=="WorkspaceSucceeded")].status}' \
  2>/dev/null || echo "")

if [ "${WORKSPACE_STATUS}" = "True" ]; then
  echo "PASS: Phi-3-mini-4k workspace operational"
  echo ""
  echo "=== All verification checks passed ==="
  echo "KAITO is fully deployed and operational."
  echo "GPU nodes are provisioned and model is serving."
  exit 0
elif kubectl get workspace workspace-phi-3-mini >/dev/null 2>&1; then
  echo "INFO: Workspace exists but not yet ready (may still be provisioning)"
  exit 1
else
  echo "INFO: Phi-3-mini-4k workspace not deployed yet"
  exit 1
fi
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
identity with federated credentials and RBAC permissions, and deployed the
Phi-4-mini inference workspace. The KAITO workspace controller automatically
provisioned a GPU node and deployed the model. The system is ready to serve
inference requests and deploy additional AI model workspaces.

Summary:

- KAITO workspace controller is operational with proper authentication, GPU
  nodes auto-provision successfully, and the Phi-4-mini model is serving.

## Next Steps

Consider extending the deployment with one or more of the following
executable documents:

- [Request GPU Quota Increase for KAITO](Install_Kaito_Request_GPU_Quota_Increase.md)
- [Deploy Additional KAITO Model Workspaces](Install_Kaito_Deploy_Additional_Model_Workspaces.md)
- [Monitor KAITO GPU Utilization](Install_Kaito_Monitor_GPU_Utilization.md)
- [Configure KAITO Diagnostic Settings](Install_Kaito_Configure_Diagnostics.md)
- [Clean Up KAITO Resources](Install_Kaito_Cleanup_Resources.md)
