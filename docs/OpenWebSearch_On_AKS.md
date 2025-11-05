# Open-WebSearch MCP Server - Deployment on Azure Kubernetes Service (AKS)

## Introduction

This executable document explains how to deploy the Open-WebSearch MCP server
on Azure Kubernetes Service (AKS) using the KMCP controller. Open-WebSearch
delivers multi-engine web search and retrieval without API keys, so production
deployment requires careful registry, network, and controller configuration.
The steps reuse the local Kind workflow while extending it to Azure resources,
keeping everything parameterized through environment variables.

Long-running Azure operations may time out at the CLI. To keep the flow
resilient, asynchronous commands like `az aks nodepool add --no-wait` are
followed by `az aks nodepool wait --created`, ensuring each stage finishes
before continuing.

Summary: Guides an engineer through an end-to-end, variable-driven AKS
deployment of the Open-WebSearch MCP server managed by KMCP.

## Prerequisites

Ensure the following tooling and access before proceeding with the deployment.
You should already be authenticated to Azure (`az login`) and have sufficient
quota for the selected region and VM size. Optional local tools support quick
build validation.

- Azure subscription with required AKS and ACR quota
- Azure CLI (`az`) with logged-in session
- KMCP CLI (`kmcp`) matching the desired controller release
- Docker CLI configured for Azure Container Registry pushes
- Node.js (>= 18) and npm for building Open-WebSearch assets
- jq (optional) for parsing JSON responses during validation

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v kmcp >/dev/null || echo "KMCP CLI missing"
command -v docker >/dev/null || echo "Docker CLI missing"
command -v node >/dev/null || echo "Node.js missing"
command -v npm >/dev/null || echo "npm missing"
command -v jq >/dev/null || echo "jq missing (optional)"
```

Summary: Confirms that Azure, KMCP, container tooling, and optional utilities
are installed and authenticated.

## Setting up the environment

Define all environment variables used in this document so every command stays
repeatable. Defaults target a small proof-of-concept deployment and can be
overridden to match regional policy or scaling expectations. Unique names append
the timestamp-based `HASH` to avoid collisions.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"  # YYMMDDHHMM stamp

# Azure identity and region configuration
export LOCATION="${LOCATION:-eastus2}"
export SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export RESOURCE_GROUP="${RESOURCE_GROUP:-rg_openwebsearch_${HASH}}"
# Hyphen required because AKS cluster names cannot include underscores
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-openwebsearch-${HASH}}"
export AKS_VERSION="${AKS_VERSION:-}"  # Optional Kubernetes version override

# Node pool sizing (counts and SKU must satisfy regional quota)
export AKS_SYSTEM_NODE_COUNT="${AKS_SYSTEM_NODE_COUNT:-1}"
export AKS_USER_NODE_COUNT="${AKS_USER_NODE_COUNT:-1}"
export AKS_NODE_VM_SIZE="${AKS_NODE_VM_SIZE:-Standard_D4s_v5}"
export AKS_SYSTEM_NODEPOOL_NAME="${AKS_SYSTEM_NODEPOOL_NAME:-system}"
export AKS_USER_NODEPOOL_NAME="${AKS_USER_NODEPOOL_NAME:-user}"

# Container registry parameters (ACR names must remain alphanumeric)
export ACR_NAME="${ACR_NAME:-acrwebsearch${HASH}}"
export ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-${ACR_NAME}.azurecr.io}"

# Open-WebSearch image configuration
export MCP_IMAGE_NAME="${MCP_IMAGE_NAME:-open-websearch-mcp}"
export MCP_IMAGE_TAG="${MCP_IMAGE_TAG:-latest}"
export MCP_IMAGE_FULL="${MCP_IMAGE_FULL:-${ACR_LOGIN_SERVER}/${MCP_IMAGE_NAME}:${MCP_IMAGE_TAG}}"

# Repository clone targets
export OPENWEBSEARCH_REPO_URL="${OPENWEBSEARCH_REPO_URL:-https://github.com/Aas-ee/open-webSearch.git}"
export OPENWEBSEARCH_REPO_DIR="${OPENWEBSEARCH_REPO_DIR:-open-webSearch}"

# KMCP controller settings
export KMCP_NAMESPACE="${KMCP_NAMESPACE:-kmcp-system}"
export KMCP_CRDS_RELEASE_NAME="${KMCP_CRDS_RELEASE_NAME:-kmcp-crds}"
export KMCP_VERSION="${KMCP_VERSION:-}"

# MCP Kubernetes settings
export MCP_SERVER_NAMESPACE="${MCP_SERVER_NAMESPACE:-default}"
export SERVER_NAME="${SERVER_NAME:-open-websearch-mcp}"
export MCP_SERVICE_PORT="${MCP_SERVICE_PORT:-3000}"
export MCP_LOCAL_PORT="${MCP_LOCAL_PORT:-3000}"

# Application runtime behaviour
export ALLOWED_SEARCH_ENGINES="${ALLOWED_SEARCH_ENGINES:-bing,duckduckgo,brave,exa,baidu,csdn,juejin}"
export DEFAULT_SEARCH_ENGINE="${DEFAULT_SEARCH_ENGINE:-duckduckgo}"
export USE_PROXY="${USE_PROXY:-false}"
export PROXY_URL="${PROXY_URL:-}"
export RATE_LIMIT_QPS="${RATE_LIMIT_QPS:-5}"
export ENABLE_METRICS="${ENABLE_METRICS:-true}"
export METRICS_PORT="${METRICS_PORT:-9090}"
export PORT_FORWARD_PROBE_QUERY="${PORT_FORWARD_PROBE_QUERY:-healthcheck}"

# MCP protocol test parameters
export MCP_PROTOCOL_VERSION="${MCP_PROTOCOL_VERSION:-2024-10-22}"
export MCP_CLIENT_NAME="${MCP_CLIENT_NAME:-exec-doc}"
export MCP_CLIENT_VERSION="${MCP_CLIENT_VERSION:-0.0.1}"
export MCP_SEARCH_LIMIT="${MCP_SEARCH_LIMIT:-3}"
export MCP_SEARCH_ENGINES="${MCP_SEARCH_ENGINES:-[\"duckduckgo\",\"bing\"]}"
export MCP_ENDPOINT="${MCP_ENDPOINT:-http://localhost:${MCP_LOCAL_PORT}/mcp}"
export MCP_INIT_FILE="${MCP_INIT_FILE:-/tmp/mcp-init-request.json}"
export SEARCH_ENGINES_JSON="${SEARCH_ENGINES_JSON:-${MCP_SEARCH_ENGINES}}"

# Functional smoke test inputs
export TEST_SEARCH_QUERY="${TEST_SEARCH_QUERY:-open source vector database comparison}"
export TEST_FETCH_GITHUB_REPO="${TEST_FETCH_GITHUB_REPO:-Aas-ee/open-webSearch}"
```

Summary: Establishes all Azure, registry, KMCP, and runtime parameters with
consistent defaults and timestamp-based uniqueness.

### Verify environment variable values

Inspect the effective configuration before provisioning resources to avoid
unexpected names or regions. Re-run this block after adjustments to confirm the
active settings.

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
  MCP_IMAGE_FULL
  OPENWEBSEARCH_REPO_URL
  OPENWEBSEARCH_REPO_DIR
  KMCP_NAMESPACE
  KMCP_CRDS_RELEASE_NAME
  KMCP_VERSION
  MCP_SERVER_NAMESPACE
  SERVER_NAME
  MCP_SERVICE_PORT
  MCP_LOCAL_PORT
  ALLOWED_SEARCH_ENGINES
  DEFAULT_SEARCH_ENGINE
  USE_PROXY
  PROXY_URL
  RATE_LIMIT_QPS
  ENABLE_METRICS
  METRICS_PORT
  PORT_FORWARD_PROBE_QUERY
  TEST_SEARCH_QUERY
  TEST_FETCH_GITHUB_REPO
  MCP_PROTOCOL_VERSION
  MCP_CLIENT_NAME
  MCP_CLIENT_VERSION
  MCP_SEARCH_LIMIT
  MCP_SEARCH_ENGINES
  SEARCH_ENGINES_JSON
  MCP_ENDPOINT
)
for v in "${VARS[@]}"; do
  printf "%s=%s\n" "$v" "${!v}"
done
```

Summary: Prints the parameter set that subsequent steps depend on, enabling
quick audits or troubleshooting.

## Steps

Each step includes purpose, executable commands, and expected outcome so you can
validate progress before moving forward.

### Check Azure subscription context

Confirm the Azure subscription and provider registrations align with the target
region and resource types required for AKS and ACR.

```bash
az account show --query id -o tsv
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
```

Summary: Subscription context and provider registrations verified for AKS and
ACR features.

### Create resource group

Provision a dedicated resource group to hold the AKS cluster, registry, and
supporting assets for Open-WebSearch.

```bash
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output table
```

Summary: Resource group created in the selected region to host deployment
resources.

### Provision Azure Container Registry

Create an ACR instance for storing the Open-WebSearch container image and log in
locally so Docker can push the build output.

```bash
az acr create \
  --name "${ACR_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Basic \
  --output table
az acr login --name "${ACR_NAME}"
```

Summary: Azure Container Registry is online and the local Docker daemon is
authenticated for pushes.

### Create AKS cluster

Deploy an AKS cluster sized for evaluation. The system node pool hosts control
workloads while the optional user pool accommodates application scale testing.
Check for an existing cluster first to avoid duplicate-name failures.

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

Provision a user node pool when requested. The add operation frequently takes
several minutes and the CLI can time out or be interrupted by network hiccups,
so running it without `--no-wait` often ends in a failed or aborted session
even though Azure continues provisioning in the background. Using
`--no-wait` lets the request return immediately, then `az aks nodepool wait
--created` tracks the authoritative state from Azure. The block first checks
for an existing pool to avoid duplicate-name failures. This sequence prevents
"operation in progress" and "node pool already exists" errors and keeps the
script resilient to temporary CLI disconnects.

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

az aks get-credentials \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --overwrite-existing
kubectl get nodes -o wide
```

Summary: AKS cluster created when absent, optional user pool requested with
wait for completion, and kubectl context updated for cluster access.

### Attach ACR to AKS cluster

Grant the AKS cluster pull permissions to the container registry so the MCP
deployment can retrieve the published image.

```bash
az aks update \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --attach-acr "${ACR_NAME}" \
  --output table
```

Summary: AKS cluster now has pull rights to the registry hosting the MCP image.

### Install KMCP CRDs

Deploy the KMCP CustomResourceDefinitions using the published Helm chart so the
cluster understands MCPServer resources.

```bash
helm upgrade --install "${KMCP_CRDS_RELEASE_NAME}" \
  oci://ghcr.io/kagent-dev/kmcp/helm/kmcp-crds \
  --namespace "${KMCP_NAMESPACE}" \
  --create-namespace
kubectl get crd | grep mcp || echo "MCP CRDs not detected"
```

Summary: KMCP CRDs registered in Kubernetes, enabling MCPServer custom objects.

### Install KMCP controller

Install or upgrade the KMCP controller, which reconciles MCPServer resources by
creating Deployments and Services for the MCP servers.

```bash
kmcp install ${KMCP_VERSION:+--version "${KMCP_VERSION}"} || true
kubectl get pods -n "${KMCP_NAMESPACE}"
```

Summary: KMCP controller pods deployed and ready to manage MCPServer instances.

### Clone Open-WebSearch repository

Retrieve the Open-WebSearch source to build a container image aligned with the
current branch or tag you wish to deploy.

```bash
if [ -d "${OPENWEBSEARCH_REPO_DIR}/.git" ]; then
  git -C "${OPENWEBSEARCH_REPO_DIR}" fetch --all --prune
  git -C "${OPENWEBSEARCH_REPO_DIR}" pull --ff-only
else
  git clone "${OPENWEBSEARCH_REPO_URL}" "${OPENWEBSEARCH_REPO_DIR}"
fi
git -C "${OPENWEBSEARCH_REPO_DIR}" log -1 --oneline
```

Summary: Repository synchronized locally, ready for build and packaging steps.

### Build Open-WebSearch assets

Install Node.js dependencies and produce the distributable artifacts required by
the MCP server entry point.

```bash
cd "${OPENWEBSEARCH_REPO_DIR}"
npm install
npm run build
node dist/index.js --help | head -n 20
cd -
```

Summary: Node modules installed and compiled assets validated via CLI help text.

### Build container image

Package the compiled assets into a container image tagged for your registry.

```bash
cd "${OPENWEBSEARCH_REPO_DIR}"
docker build \
  --tag "${MCP_IMAGE_FULL}" \
  .
docker image inspect "${MCP_IMAGE_FULL}" >/dev/null
cd -
```

Summary: Container image built locally and verified with `docker inspect`.

### Push image to Azure Container Registry

Authenticate to ACR using the current Azure session (or service principal) and
publish the container image. The login step fails if your `az` credentials have
expired or if the registry lives in a different tenant; rerun `az login` or use
`az acr login --expose-token` piping the short-lived token to `docker login` in
those cases. If you are building from an automation account, ensure the service
principal has the `AcrPush` role on the registry.

```bash
if az acr login --name "${ACR_NAME}" && \
   docker push "${MCP_IMAGE_FULL}" && \
   az acr repository show-tags \
     --name "${ACR_NAME}" \
     --repository "${MCP_IMAGE_NAME}" \
     --output tsv | grep "${MCP_IMAGE_TAG}"; then
  echo "ACR push verified for ${MCP_IMAGE_FULL}"
else
  cat <<ERR
Failed to authenticate with Azure Container Registry or push the image.
Remediation steps:
  1. Re-run 'az login' (add '--tenant <TENANT_ID>' if required).
  2. If direct login fails, run:
     az acr login --name ${ACR_NAME} --expose-token --output tsv \
       --query accessToken | \
       docker login ${ACR_LOGIN_SERVER} \
         --username 00000000-0000-0000-0000-000000000000 \
         --password-stdin
  3. Ensure the caller has AcrPush on the registry scope:
     az role assignment list \
       --scope "\$(az acr show --name ${ACR_NAME} --query id -o tsv)" \
       --assignee <principal-id>
ERR
fi
```

Summary: Container image uploaded to ACR and tag presence confirmed.

### Create MCPServer resource

Define the MCPServer custom resource that instructs KMCP to run the
Open-WebSearch MCP server with the configured environment.

```bash
cat > mcpserver-${SERVER_NAME}.yaml <<EOF
apiVersion: kagent.dev/v1alpha1
kind: MCPServer
metadata:
  name: ${SERVER_NAME}
  namespace: ${MCP_SERVER_NAMESPACE}
spec:
  transportType: http
  httpTransport:
    targetPort: ${MCP_SERVICE_PORT}
    path: /
  deployment:
    image: ${MCP_IMAGE_FULL}
    port: ${MCP_SERVICE_PORT}
    env:
      ALLOWED_SEARCH_ENGINES: "${ALLOWED_SEARCH_ENGINES}"
      DEFAULT_SEARCH_ENGINE: "${DEFAULT_SEARCH_ENGINE}"
      USE_PROXY: "${USE_PROXY}"
      PROXY_URL: "${PROXY_URL}"
      RATE_LIMIT_QPS: "${RATE_LIMIT_QPS}"
      ENABLE_METRICS: "${ENABLE_METRICS}"
      METRICS_PORT: "${METRICS_PORT}"
      ENABLE_CORS: "true"
      CORS_ORIGIN: "*"
EOF
kubectl apply -f mcpserver-${SERVER_NAME}.yaml
kubectl get mcpserver "${SERVER_NAME}" \
  -n "${MCP_SERVER_NAMESPACE}" \
  -o yaml | head -n 20
```

Summary: MCPServer custom resource applied and initial status retrieved for
verification.

### Wait for MCPServer readiness

Wait for KMCP to create the Service and Deployment, ensuring at least one pod is
Ready before attempting port-forward or MCP session tests.

```bash
echo "Waiting for Service ${SERVER_NAME}"
for i in $(seq 1 60); do
  if kubectl get svc "${SERVER_NAME}" \
    -n "${MCP_SERVER_NAMESPACE}" >/dev/null 2>&1; then
    echo "Service detected on attempt ${i}"
    break
  fi
  sleep 1
done

echo "Waiting for a Ready pod"
for i in $(seq 1 120); do
  READY_CT=$(kubectl get pods \
    -n "${MCP_SERVER_NAMESPACE}" \
    -l app.kubernetes.io/name="${SERVER_NAME}" \
    -o jsonpath='{range .items[*]}{range .status.conditions[*]}{@.type}{":"}{@.status}{"\n"}{end}{end}' \
    2>/dev/null | grep -c 'Ready:True' || true)
  if [ "${READY_CT}" -ge 1 ]; then
    echo "Ready pod detected on attempt ${i}"
    break
  fi
  sleep 1
done
```

Summary: MCPServer Service and Deployment confirmed, and at least one pod
reports Ready.

### Port-forward MCP server

Establish a local port-forward to reach the MCP HTTP endpoint securely from your
workstation.

```bash
kubectl port-forward \
  -n "${MCP_SERVER_NAMESPACE}" \
  svc/"${SERVER_NAME}" \
  "${MCP_LOCAL_PORT}:${MCP_SERVICE_PORT}" \
  >/tmp/port-forward-${SERVER_NAME}.log 2>&1 &
export MCP_PORT_FORWARD_PID=$!
ATTEMPTS=30
for i in $(seq 1 "${ATTEMPTS}"); do
  if ss -tnlp | grep -q ":${MCP_LOCAL_PORT}"; then
    if curl -s --get \
      --header 'Accept: application/json' \
      --data-urlencode "engine=${DEFAULT_SEARCH_ENGINE}" \
      --data-urlencode "query=${PORT_FORWARD_PROBE_QUERY}" \
      "http://localhost:${MCP_LOCAL_PORT}/search" >/dev/null 2>&1; then
      echo "Port-forward active on attempt ${i}"
      break
    fi
  fi
  sleep 1
done
```

Summary: Local port-forward running with readiness confirmed via search probe.

### Initialize MCP session

Open a streamable HTTP MCP session against the port-forwarded endpoint to obtain
a session identifier required for subsequent JSON-RPC calls.

```bash
unset MCP_SESSION_ID
cat > "${MCP_INIT_FILE}" <<EOF
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "clientInfo": {
      "name": "${MCP_CLIENT_NAME}",
      "version": "${MCP_CLIENT_VERSION}"
    },
    "protocolVersion": "${MCP_PROTOCOL_VERSION}",
    "capabilities": {}
  }
}
EOF

INIT_HEADERS=$(mktemp)
curl -sS \
  -D "${INIT_HEADERS}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data-binary "@${MCP_INIT_FILE}" \
  -o /tmp/mcp-init.json \
  "${MCP_ENDPOINT}"

MCP_SESSION_ID=$(awk -F': ' 'tolower($1)=="mcp-session-id" {print $2}' "${INIT_HEADERS}" | tr -d '\r')
if [ -z "${MCP_SESSION_ID}" ]; then
  echo "Failed to acquire MCP session identifier"
  cat /tmp/mcp-init.json
else
  export MCP_SESSION_ID
  echo "MCP session established: ${MCP_SESSION_ID}"
fi
rm -f "${MCP_INIT_FILE}" "${INIT_HEADERS}"
```

Summary: Streamable MCP session initialized and session identifier captured for
subsequent tool invocations.

### Perform search via MCP session

Invoke the MCP `search` tool over the established session and inspect the first
few lines of the response payload.

```bash
SESSION_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H "mcp-session-id: ${MCP_SESSION_ID}" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  "${MCP_ENDPOINT}")
if [ "${SESSION_STATUS}" = "200" ]; then
  echo "MCP session verified"
else
  echo "MCP session check failed with status ${SESSION_STATUS}"
fi

MCP_SEARCH_REQUEST=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "search",
    "arguments": {
      "query": "${TEST_SEARCH_QUERY}",
      "limit": ${MCP_SEARCH_LIMIT},
      "engines": ${SEARCH_ENGINES_JSON}
    }
  }
}
EOF
)

curl -s \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H "mcp-session-id: ${MCP_SESSION_ID}" \
  -d "${MCP_SEARCH_REQUEST}" \
  "${MCP_ENDPOINT}" |
  awk '/^data:/{sub(/^data: /,"",$0); print}' |
  jq -r '.result.content[0].text' |
  sed 's/\\n/\n/g' |
  head -n 40
```

Summary: Verified MCP session remains active and captured example search
results from the Open-WebSearch toolset.

### Cleanup (optional)

Remove local port-forward and Azure resources when experimentation concludes.

```bash
kill "${MCP_PORT_FORWARD_PID}" 2>/dev/null || true
kubectl delete mcpserver "${SERVER_NAME}" -n "${MCP_SERVER_NAMESPACE}" || true
az group delete --name "${RESOURCE_GROUP}" --yes --no-wait || true
```

Summary: Initiated teardown of MCP deployment, Kubernetes resources, and Azure
resource group.

## Summary

The Open-WebSearch MCP server was built, published to Azure Container Registry,
and deployed onto AKS through the KMCP controller. Port-forwarding and MCP
session tests validated the search tool end to end, confirming registry access,
controller reconciliation, and HTTP transport readiness.

## Next Steps

- Add automated MCP protocol tests that cover additional tools beyond search
- Integrate Azure Monitor or Prometheus scraping for metrics and alerts
- Configure network policies and private cluster endpoints for production use
- Extend the deployment pipeline with CI tasks for image build and KMCP apply
- Document operational runbooks (scaling, log review, failure recovery)

Summary: Focus future work on coverage, observability, security, and automation.
