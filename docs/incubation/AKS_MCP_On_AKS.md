# AKS MCP Server - Deployment on Azure Kubernetes Service (AKS)

## Introduction

This executable guide explains how to deploy the AKS-MCP Model Context
Protocol server on an Azure Kubernetes Service (AKS) cluster. The AKS-MCP
project enables AI assistants to invoke AKS administrative and diagnostic
operations through MCP, so running it in-cluster keeps credentials and traffic
close to the managed plane.

The workflow clones the upstream repository, prepares Azure credentials,
installs the Helm chart, validates the rollout, and exercises the MCP
streamable HTTP endpoint. All commands stay parameterized with environment
variables so different clusters and access levels can reuse the procedure.

Summary: Provides an end-to-end, variable-driven AKS deployment of the AKS-MCP
server with validation steps.

## Prerequisites

Before starting, ensure Azure access and the tooling required for Helm based
deployments are present. Azure role assignments must permit creating secrets
and installing cluster resources in the target namespace.

- Azure CLI (`az`) with an authenticated session (`az login`)
- kubectl connected to the target AKS cluster
- Helm 3.8 or newer
- Git for cloning the AKS-MCP repository
- Optional: `jq` for inspecting JSON payloads during validation

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v kubectl >/dev/null || echo "kubectl missing"
command -v helm >/dev/null || echo "Helm missing"
command -v git >/dev/null || echo "Git missing"
command -v jq >/dev/null || echo "jq missing (optional)"
```

Run the executable guide to [Creating an AKS Cluster](../Create_AKS.md) to
validate Azure access, provision the resource group, attach Azure Container
Registry when needed, and export the environment variables this document
expects. Return here once that workflow completes successfully.

Summary: Confirms the Azure CLI, kubectl, Helm, and supporting tools are ready
to manage the deployment.

## Setting up the environment

Export the variables that control resource names, image selection, access
levels, and validation helpers. Azure specific values (tenant, client, secret,
subscription) should already be sourced from secure storage or the
`docs/Create_AKS.md` workflow. Unique names append the timestamp based `HASH`
suffix to prevent collisions.

```bash
export HASH="${HASH:-$(
  date -u +"%y%m%d%H%M"
)}"
export RESOURCE_GROUP="${RESOURCE_GROUP:-mcp-rg}"
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-mcp-cluster}"
export AKS_MCP_NAMESPACE="${AKS_MCP_NAMESPACE:-aks-mcp}"
export AKS_MCP_RELEASE="${AKS_MCP_RELEASE:-aks-mcp-${HASH}}"
export AKS_MCP_REPO_URL="${AKS_MCP_REPO_URL:-https://github.com/Azure/aks-\
mcp.git}"
export AKS_MCP_REPO_DIR="${AKS_MCP_REPO_DIR:-aks-mcp}"
export AKS_MCP_CHART_PATH="${AKS_MCP_CHART_PATH:-${AKS_MCP_REPO_DIR}/chart}"
export AKS_MCP_IMAGE_REPOSITORY="${AKS_MCP_IMAGE_REPOSITORY:-ghcr.io/azure/\
aks-mcp}"
export AKS_MCP_IMAGE_TAG="${AKS_MCP_IMAGE_TAG:-latest}"
export AKS_MCP_ACCESS_LEVEL="${AKS_MCP_ACCESS_LEVEL:-readonly}"
export AKS_MCP_TRANSPORT="${AKS_MCP_TRANSPORT:-streamable-http}"
export AKS_MCP_PORT="${AKS_MCP_PORT:-8000}"
export AKS_MCP_LOCAL_PORT="${AKS_MCP_LOCAL_PORT:-8081}"
export AKS_MCP_SECRET_NAME="${AKS_MCP_SECRET_NAME:-aks-mcp-azure-\
credentials-${HASH}}"
export AZURE_TENANT_ID="${AZURE_TENANT_ID:-}"
export AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"
export AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET:-}"
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
export AKS_MCP_ALLOWED_NAMESPACES="${AKS_MCP_ALLOWED_NAMESPACES:-}"
export AKS_MCP_ADDITIONAL_TOOLS="${AKS_MCP_ADDITIONAL_TOOLS:-}"
export AKS_MCP_TELEMETRY_ENDPOINT="${AKS_MCP_TELEMETRY_ENDPOINT:-}"
export AKS_MCP_INIT_FILE="${AKS_MCP_INIT_FILE:-/tmp/aks-mcp-init.json}"
export AKS_MCP_PORT_FORWARD_LOG="${AKS_MCP_PORT_FORWARD_LOG:-/tmp/aks-mcp-\
port-forward.log}"
export AKS_MCP_PROTOCOL_VERSION="${AKS_MCP_PROTOCOL_VERSION:-2024-10-22}"
export AKS_MCP_CLIENT_NAME="${AKS_MCP_CLIENT_NAME:-exec-doc}"
export AKS_MCP_CLIENT_VERSION="${AKS_MCP_CLIENT_VERSION:-0.0.1}"
```

```bash
VARS=(
  HASH
  RESOURCE_GROUP
  AKS_CLUSTER_NAME
  AKS_MCP_NAMESPACE
  AKS_MCP_RELEASE
  AKS_MCP_REPO_URL
  AKS_MCP_REPO_DIR
  AKS_MCP_CHART_PATH
  AKS_MCP_IMAGE_REPOSITORY
  AKS_MCP_IMAGE_TAG
  AKS_MCP_ACCESS_LEVEL
  AKS_MCP_TRANSPORT
  AKS_MCP_PORT
  AKS_MCP_LOCAL_PORT
  AKS_MCP_SECRET_NAME
  AZURE_TENANT_ID
  AZURE_CLIENT_ID
  AZURE_CLIENT_SECRET
  AZURE_SUBSCRIPTION_ID
  AKS_MCP_ALLOWED_NAMESPACES
  AKS_MCP_ADDITIONAL_TOOLS
  AKS_MCP_TELEMETRY_ENDPOINT
  AKS_MCP_INIT_FILE
  AKS_MCP_PORT_FORWARD_LOG
  AKS_MCP_PROTOCOL_VERSION
  AKS_MCP_CLIENT_NAME
  AKS_MCP_CLIENT_VERSION
)

for var in "${VARS[@]}"; do
  printf "%s=%s\n" "${var}" "${!var}"
done
```

Summary: Establishes reproducible defaults and prints the resulting
configuration for quick review before provisioning.

## Steps

Follow each step to install, validate, and exercise the AKS-MCP server on
your cluster. Commands stop on failure (`set -e`) is not implied, so review
each outcome before continuing.

### Step 1. Confirm Azure access and AKS context

Verify the Azure subscription, ensure the AKS credentials are current, and
confirm cluster reachability.

```bash
az account show --output table
az aks show --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --output table
kubectl get nodes
```

Summary: Azure CLI and kubectl can reach the intended subscription and cluster.

### Step 2. Clone or update the AKS-MCP repository

Fetch the Helm chart and source templates from the official repository.

```bash
if [ -d "${AKS_MCP_REPO_DIR}/.git" ]; then
  git -C "${AKS_MCP_REPO_DIR}" fetch --all --prune
  git -C "${AKS_MCP_REPO_DIR}" pull --ff-only
else
  git clone "${AKS_MCP_REPO_URL}" "${AKS_MCP_REPO_DIR}"
fi
git -C "${AKS_MCP_REPO_DIR}" log -1 --oneline
```

Summary: Local sources are synchronized with the latest AKS-MCP content.

### Step 3. Prepare the Azure credential secret

Create or update the secret that the Helm chart references for Azure CLI
authentication. Skip the secret when using managed identity by leaving the
client credentials empty.

```bash
kubectl create namespace "${AKS_MCP_NAMESPACE}" --dry-run=client -o yaml | \
  kubectl apply -f -
if [ -n "${AZURE_CLIENT_ID}" ] && [ -n "${AZURE_CLIENT_SECRET}" ]; then
  kubectl create secret generic "${AKS_MCP_SECRET_NAME}" \
    --namespace "${AKS_MCP_NAMESPACE}" \
    --from-literal=tenant-id="${AZURE_TENANT_ID}" \
    --from-literal=client-id="${AZURE_CLIENT_ID}" \
    --from-literal=client-secret="${AZURE_CLIENT_SECRET}" \
    --from-literal=subscription-id="${AZURE_SUBSCRIPTION_ID}" \
    --dry-run=client -o yaml | kubectl apply -f -
else
  echo "Skipping secret creation; managed identity configuration assumed."
fi
kubectl get secret "${AKS_MCP_SECRET_NAME}" \
  --namespace "${AKS_MCP_NAMESPACE}" \
  --ignore-not-found
```

Summary: Namespace exists and Azure credentials are stored when required.

### Step 4. Install or upgrade the Helm release

Deploy the AKS-MCP server using Helm. Optional flags inject additional tools,
namespace filters, or telemetry only when values are provided.

```bash
cd "${AKS_MCP_CHART_PATH}"
helm dependency update
OPTIONAL_ARGS=()
if [ -n "${AKS_MCP_ADDITIONAL_TOOLS}" ]; then
  OPTIONAL_ARGS+=(
    "--set"
    "config.additionalTools={${AKS_MCP_ADDITIONAL_TOOLS}}"
  )
fi
if [ -n "${AKS_MCP_ALLOWED_NAMESPACES}" ]; then
  OPTIONAL_ARGS+=(
    "--set"
    "config.allowNamespaces={${AKS_MCP_ALLOWED_NAMESPACES}}"
  )
fi
if [ -n "${AKS_MCP_TELEMETRY_ENDPOINT}" ]; then
  OPTIONAL_ARGS+=(
    "--set"
    "telemetry.otlpEndpoint=${AKS_MCP_TELEMETRY_ENDPOINT}"
  )
fi
helm upgrade --install "${AKS_MCP_RELEASE}" "." \
  --namespace "${AKS_MCP_NAMESPACE}" \
  --create-namespace \
  --set image.repository="${AKS_MCP_IMAGE_REPOSITORY}" \
  --set image.tag="${AKS_MCP_IMAGE_TAG}" \
  --set app.transport="${AKS_MCP_TRANSPORT}" \
  --set app.port="${AKS_MCP_PORT}" \
  --set app.accessLevel="${AKS_MCP_ACCESS_LEVEL}" \
  --set azure.existingSecret="${AKS_MCP_SECRET_NAME}" \
  "${OPTIONAL_ARGS[@]}"
cd -
```

Summary: Helm applies the AKS-MCP chart with your chosen image, transport, and
access policy.

### Step 5. Wait for the deployment to become ready

Check rollout status and inspect the service endpoint provisioned by the
chart.

```bash
RELEASE_NAME="${AKS_MCP_RELEASE}"
APP_NAME="${RELEASE_NAME}"
kubectl rollout status deployment/"${APP_NAME}" \
  --namespace "${AKS_MCP_NAMESPACE}"
kubectl get pods,svc \
  --namespace "${AKS_MCP_NAMESPACE}" \
  --selector app.kubernetes.io/instance="${RELEASE_NAME}"
```

Summary: Deployment reports `Successfully rolled out` and service resources are
visible.

### Step 6. Port-forward the MCP endpoint for validation

Forward the service to localhost, probe the health check, and keep the PID for
cleanup.

```bash
APP_NAME="${AKS_MCP_RELEASE}"
kubectl port-forward \
  --namespace "${AKS_MCP_NAMESPACE}" \
  svc/"${APP_NAME}" \
  "${AKS_MCP_LOCAL_PORT}:${AKS_MCP_PORT}" \
  >"${AKS_MCP_PORT_FORWARD_LOG}" 2>&1 &
export AKS_MCP_PORT_FORWARD_PID=$!
PORT_FORWARD_READY=false
for attempt in $(seq 1 30); do
  if curl -sf "http://localhost:${AKS_MCP_LOCAL_PORT}/health" >/dev/null; then
    echo "Health check succeeded on attempt ${attempt}"
    PORT_FORWARD_READY=true
    break
  fi
  sleep 2
done
if [ "${PORT_FORWARD_READY}" != "true" ]; then
  echo "Failed to verify port-forward to service ${APP_NAME}. Check ${AKS_MCP_PORT_FORWARD_LOG}." >&2
  exit 1
fi
```

Summary: The MCP endpoint is reachable locally through the port-forward.

### Step 7. Initialize an MCP session over HTTP

Send the MCP `initialize` request using the latest protocol schema. The
response includes the `Mcp-Session-Id` header that future calls must supply.

```bash
cat > "${AKS_MCP_INIT_FILE}" <<EOF
{
  "jsonrpc": "2.0",
  "id": "init-1",
  "method": "initialize",
  "params": {
    "client": {
      "name": "${AKS_MCP_CLIENT_NAME}",
      "version": "${AKS_MCP_CLIENT_VERSION}"
    },
    "protocol": {
      "version": "${AKS_MCP_PROTOCOL_VERSION}"
    },
    "capabilities": {}
  }
}
EOF
INIT_HEADERS=$(mktemp)
curl -sS \
  --request POST \
  --header "Content-Type: application/json" \
  --header "Accept: application/json" \
  --data "@${AKS_MCP_INIT_FILE}" \
  --dump-header "${INIT_HEADERS}" \
  --output /tmp/aks-mcp-init-response.json \
  "http://localhost:${AKS_MCP_LOCAL_PORT}/mcp"
MCP_SESSION_ID=$(awk -F': ' 'tolower($1)=="mcp-session-id" {print $2}' "${INIT_HEADERS}" | tr -d '\r')
if [ -z "${MCP_SESSION_ID}" ]; then
  echo "Failed to capture MCP session identifier. Inspect /tmp/aks-mcp-init-response.json for details." >&2
else
  export MCP_SESSION_ID
  echo "MCP session established: ${MCP_SESSION_ID}"
fi
rm -f "${AKS_MCP_INIT_FILE}" "${INIT_HEADERS}"
```

Summary: The MCP server returned a session identifier through the
`Mcp-Session-Id` header, confirming the endpoint is ready for additional
requests.

## Summary

You cloned the AKS-MCP sources, prepared Azure authentication material,
installed the Helm release, verified pod readiness, and confirmed the MCP
session handshake succeeds through a port-forwarded endpoint.

Summary: Deployment is operational and ready for MCP clients to connect.

## Next Steps

Consider extending the deployment with one or more of the following paths.

1. Enable OAuth by supplying the Helm chart OAuth values and registering an
   Azure AD app for browser authenticated access.
2. Switch to managed identity by omitting client secrets and granting the pod
   a federated credential bound to the AKS workload identity profile.
3. Configure ingress or Azure App Routing to expose the MCP endpoint without
   relying on port-forwarding.

Summary: Suggested enhancements support production hardening and easier client
integration.
