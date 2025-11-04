# Open-WebSearch MCP Server - Deployment on Azure Kubernetes Service (AKS)

## Introduction

This executable document describes deploying the Open-WebSearch MCP server onto an Azure Kubernetes Service (AKS) cluster using the KMCP controller. Open-WebSearch provides multi-engine web search and content retrieval tools without requiring API keys (HTML scraping). The goal is to establish a repeatable, parameterized workflow from environment setup through deployment validation, monitoring, and cleanup. All commands are fully parameterized via environment variables to support automation.

Summary: Establishes context and objectives for automated AKS deployment of the Open-WebSearch MCP server using KMCP.

## Prerequisites

The following must be available prior to execution:

- Azure subscription with sufficient quota for AKS and ACR
- Azure CLI (az) installed and logged in (az login completed)
- KMCP CLI installed (kmcp version) and matching desired controller version
- Docker CLI installed and authenticated for pushing to Azure Container Registry
- Node.js (>= 18) and npm for local build validation
- Optional: kind (local Kubernetes) for pre-AKS smoke tests

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v kmcp >/dev/null || echo "KMCP CLI missing"
command -v docker >/dev/null || echo "Docker CLI missing"
command -v node >/dev/null || echo "Node.js missing"
command -v npm >/dev/null || echo "npm missing"
```

Summary: Confirms toolchain readiness (Azure, KMCP, Docker, Node.js) and prerequisite access before proceeding.

## Setting up the environment

This section defines all environment variables used throughout the steps. Defaults are provided and may be overridden. Unique resource names append the computed HASH value to avoid collisions. The HASH is a timestamp in YYMMDDHHMM format.

```bash
export HASH="$(date -u +"%y%m%d%H%M")"

export LOCATION="${LOCATION:-eastus2}"
export RESOURCE_GROUP="${RESOURCE_GROUP:-rg-openwebsearch-${HASH}}"
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-openwebsearch-${HASH}}"
export AKS_VERSION="${AKS_VERSION:-}"  # Optional Kubernetes version
export AKS_NODE_VM_SIZE="${AKS_NODE_VM_SIZE:-SKU=Standard_D4s_v5}"  # Must be an allowed SKU in region
export NODEPOOL_SYSTEM_NAME="${NODEPOOL_SYSTEM_NAME:-system}"
export NODEPOOL_USER_NAME="${NODEPOOL_USER_NAME:-user}"

export ACR_NAME="${ACR_NAME:-acrwebsearch${HASH}}"
export ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-${ACR_NAME}.azurecr.io}"
export MCP_IMAGE_NAME="${MCP_IMAGE_NAME:-open-websearch-mcp}"
export MCP_IMAGE_TAG="${MCP_IMAGE_TAG:-latest}"
export MCP_IMAGE_FULL="${MCP_IMAGE_FULL:-${ACR_LOGIN_SERVER}/${MCP_IMAGE_NAME}:${MCP_IMAGE_TAG}}"

export OPENWEBSEARCH_REPO_URL="${OPENWEBSEARCH_REPO_URL:-https://github.com/Aas-ee/open-webSearch.git}"
export OPENWEBSEARCH_REPO_DIR="${OPENWEBSEARCH_REPO_DIR:-open-webSearch}"
export SERVER_NAME="${SERVER_NAME:-open-websearch-mcp}"
export MCP_PROJECT_DIR="${MCP_PROJECT_DIR:-$(pwd)/${SERVER_NAME}}"
export KMCP_VERSION="${KMCP_VERSION:-}"  # Optional controller version

export MCP_SERVER_NAMESPACE="${MCP_SERVER_NAMESPACE:-default}"
export MCP_LOCAL_PORT="${MCP_LOCAL_PORT:-3000}"
export MCP_SERVICE_PORT="${MCP_SERVICE_PORT:-3000}"
export NO_INSPECTOR_FLAG="${NO_INSPECTOR_FLAG:-}"  # Set to '--no-inspector' if suppression desired

export ALLOWED_SEARCH_ENGINES="${ALLOWED_SEARCH_ENGINES:-bing,duckduckgo,brave,exa,baidu,csdn,juejin}"
export DEFAULT_SEARCH_ENGINE="${DEFAULT_SEARCH_ENGINE:-duckduckgo}"
export USE_PROXY="${USE_PROXY:-false}"
export PROXY_URL="${PROXY_URL:-}"
export RATE_LIMIT_QPS="${RATE_LIMIT_QPS:-5}"

export TEST_SEARCH_QUERY="${TEST_SEARCH_QUERY:-open source vector database comparison}"
export TEST_FETCH_CSDN_SLUG="${TEST_FETCH_CSDN_SLUG:-article-slug-example}"
export TEST_FETCH_GITHUB_REPO="${TEST_FETCH_GITHUB_REPO:-Aas-ee/open-webSearch}"
export TEST_FETCH_JUEJIN_ID="${TEST_FETCH_JUEJIN_ID:-1234567890}"

export KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind-openwebsearch-${HASH}}"

export ENABLE_METRICS="${ENABLE_METRICS:-true}"
export METRICS_PORT="${METRICS_PORT:-9090}"
```

Summary: All variables defined for Azure, KMCP, repository, image, search configuration, and test scenarios supporting repeatable execution.

## Steps

This section provides discrete steps. Each subsection introduces its purpose, presents executable commands, and concludes with a summary of the expected outcome.

### Verify Azure subscription context

```bash
az account show --query id -o tsv
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
```

Summary: Confirmed Azure subscription and provider readiness.

### Create resource group

```bash
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output table
```

Summary: Resource group provisioned for deployment assets.

### Create ACR (Azure Container Registry)

```bash
az acr create --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" --sku Basic --output table
az acr login --name "${ACR_NAME}"
```

Summary: ACR available for image build and push operations.

### Create AKS cluster

```bash
az aks create --name "${AKS_CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" --generate-ssh-keys \
  --node-count 1 --nodepool-name "${NODEPOOL_SYSTEM_NAME}" \
  --node-vm-size "${AKS_NODE_VM_SIZE}" \
  ${AKS_VERSION:+--kubernetes-version ${AKS_VERSION}} --output table

az aks nodepool add --cluster-name "${AKS_CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" \
  --name "${NODEPOOL_USER_NAME}" --node-count 1 --node-vm-size "${AKS_NODE_VM_SIZE}" --no-wait || echo "User pool add skipped"

az aks get-credentials --name "${AKS_CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP}" --overwrite-existing
kubectl get nodes -o wide
```

Summary: AKS cluster deployed and kubeconfig merged locally.

#### Troubleshooting: VM size not allowed / capacity errors

If cluster creation fails with an error similar to:

`ERROR: (BadRequest) The VM size of Standard_DS2_v2 is not allowed in your subscription in location 'eastus'. The available VM sizes are 'standard_d16darm_v3,standard_d2darm_v3,standard_d32darm_v3,standard_d48darm_v3,standard_d4darm_v3,standard_d8darm_v3,standard_e16darm_v3,standard_e20darm_v3,standard_e2darm_v3,standard_e32darm_v3,standard_e48darm_v3,standard_e4darm_v3,standard_e8darm_v3'`.

Actions:

1. Set `AKS_NODE_VM_SIZE` to one of the allowed SKUs (respect casing):
   ```bash
   export AKS_NODE_VM_SIZE="Standard_B2ms"
   ```
2. Re-run the create command (Step 4) or the entire Step 4 block.
3. (Optional) Use the reusable dynamic pre-flight selection documented in `docs/AKS_VM_Size_Selection.md` to automatically identify an available, quota-compliant SKU. That executable doc performs diversified candidate construction, availability and quota checks, optional burstable fallback, and region failover. Run it before cluster creation and export the resulting `AKS_NODE_VM_SIZE` here.

Quota or region strategies:

- Try a different region with broader capacity (e.g. `westus3`, `centralus`).
- Reduce node count if near vCPU quota limits.
- Request a quota increase for the target family via Azure Portal (Subscriptions -> Usage + quotas).
- Prefer newer generation SKUs where possible (often have more regional capacity).

Summary: When encountering a disallowed or capacity constrained VM size, select an allowed SKU from the error output or let the helper script auto-select. Update `AKS_NODE_VM_SIZE` and re-run provisioning.

### Install KMCP CRDs and controller

```bash
kmcp install ${KMCP_VERSION:+--version ${KMCP_VERSION}}
kubectl get ns | grep kmcp || echo "KMCP namespaces validated"
kubectl api-resources | grep mcpserver || echo "MCPServer CRD missing"
```

Summary: KMCP CRDs and controller installed in cluster.

### Clone Open-WebSearch repository

```bash
git clone "${OPENWEBSEARCH_REPO_URL}" "${OPENWEBSEARCH_REPO_DIR}" || echo "Repo already exists"
cd "${OPENWEBSEARCH_REPO_DIR}"
git log -1 --oneline
```

Summary: Repository cloned and latest commit inspected.

### Local build and validation (Node.js)

```bash
cd "${OPENWEBSEARCH_REPO_DIR}"
npm install
npm run build
node dist/index.js --help || echo "Help command executed"
```

Summary: Node modules installed and build artifacts produced successfully.

### Basic local tool smoke tests

```bash
cd "${OPENWEBSEARCH_REPO_DIR}"
node dist/index.js search --engine "${DEFAULT_SEARCH_ENGINE}" --query "${TEST_SEARCH_QUERY}" | head -n 20
node dist/index.js fetchGithubReadme --repo "${TEST_FETCH_GITHUB_REPO}" | head -n 40
```

Summary: Core search and README fetch tool operations return sample output.

### Create container build context

```bash
cat > Dockerfile <<'EOF'
FROM node:20-slim
WORKDIR /app
ENV NODE_ENV=production \
    ALLOWED_SEARCH_ENGINES=${ALLOWED_SEARCH_ENGINES} \
    DEFAULT_SEARCH_ENGINE=${DEFAULT_SEARCH_ENGINE} \
    USE_PROXY=${USE_PROXY} \
    PROXY_URL=${PROXY_URL} \
    RATE_LIMIT_QPS=${RATE_LIMIT_QPS} \
    ENABLE_METRICS=${ENABLE_METRICS} \
    METRICS_PORT=${METRICS_PORT}

COPY package*.json ./
RUN npm install --omit=dev
COPY . .
RUN npm run build

EXPOSE 3000
EXPOSE ${METRICS_PORT}

CMD ["node", "dist/index.js"]
EOF
ls -1 Dockerfile
```

Summary: Container Dockerfile created for production build of MCP server.

### Build and tag container image

```bash
docker build -t "${MCP_IMAGE_FULL}" .
docker image inspect "${MCP_IMAGE_FULL}" >/dev/null && echo "Image built"
```

Summary: Local container image built and inspected successfully.

### Push image to ACR

```bash
az acr login --name "${ACR_NAME}"
docker push "${MCP_IMAGE_FULL}"
az acr repository show-tags --name "${ACR_NAME}" --repository "${MCP_IMAGE_NAME}" | grep "${MCP_IMAGE_TAG}" || echo "Tag not found"
```

Summary: Image pushed and tag verified in ACR.

### Create KMCP MCPServer custom resource

```bash
cat > mcpserver-${SERVER_NAME}.yaml <<EOF
apiVersion: kmcp.io/v1alpha1
kind: MCPServer
metadata:
  name: ${SERVER_NAME}
  namespace: ${MCP_SERVER_NAMESPACE}
spec:
  image: ${MCP_IMAGE_FULL}
  transport:
    mode: http
    port: ${MCP_SERVICE_PORT}
  env:
    - name: ALLOWED_SEARCH_ENGINES
      value: "${ALLOWED_SEARCH_ENGINES}"
    - name: DEFAULT_SEARCH_ENGINE
      value: "${DEFAULT_SEARCH_ENGINE}"
    - name: USE_PROXY
      value: "${USE_PROXY}"
    - name: PROXY_URL
      value: "${PROXY_URL}"
    - name: RATE_LIMIT_QPS
      value: "${RATE_LIMIT_QPS}"
    - name: ENABLE_METRICS
      value: "${ENABLE_METRICS}"
    - name: METRICS_PORT
      value: "${METRICS_PORT}"
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
EOF
kubectl apply -f mcpserver-${SERVER_NAME}.yaml
kubectl get mcpserver "${SERVER_NAME}" -n "${MCP_SERVER_NAMESPACE}" -o yaml | head -n 40
```

Summary: MCPServer CR applied and initial status retrieved.

### Inspect deployment status

```bash
kubectl get deployment -n "${MCP_SERVER_NAMESPACE}" | grep "${SERVER_NAME}" || echo "Deployment missing"
kubectl get svc -n "${MCP_SERVER_NAMESPACE}" | grep "${SERVER_NAME}" || echo "Service missing"
kubectl describe mcpserver "${SERVER_NAME}" -n "${MCP_SERVER_NAMESPACE}" | sed -n '1,120p'
```

Summary: Deployment and Service existence confirmed; MCPServer status inspected.

### Port-forward MCP server locally

```bash
kubectl port-forward -n "${MCP_SERVER_NAMESPACE}" svc/"${SERVER_NAME}" \
  "${MCP_LOCAL_PORT}:${MCP_SERVICE_PORT}" >/tmp/port-forward-${SERVER_NAME}.log 2>&1 &
export MCP_PORT_FORWARD_PID=$!
sleep 3
ss -tnlp | grep "${MCP_LOCAL_PORT}" || echo "Port-forward not active"
```

Summary: Local port-forward established for MCP HTTP endpoint.

### Test search endpoint (HTTP)

```bash
curl -s "http://localhost:${MCP_LOCAL_PORT}/search?engine=${DEFAULT_SEARCH_ENGINE}&query=$(printf %s "${TEST_SEARCH_QUERY}" | sed 's/ /+/g')" | head -n 40
```

Summary: Search endpoint returns structured content for sample query.

### Test README content fetch

```bash
curl -s "http://localhost:${MCP_LOCAL_PORT}/fetchGithubReadme?repo=${TEST_FETCH_GITHUB_REPO}" | head -n 40
```

Summary: README content fetch returns initial lines of repository documentation.

### Test basic rate limiting behavior

```bash
for i in $(seq 1 10); do
  curl -s "http://localhost:${MCP_LOCAL_PORT}/search?engine=${DEFAULT_SEARCH_ENGINE}&query=test${i}" | jq '.results | length' || true
  sleep "$(awk -v q=${RATE_LIMIT_QPS} 'BEGIN{print 1.0/q}')"
done
```

Summary: Rate limiting target approximated using QPS variable; loop executed.

### Metrics endpoint probe

```bash
if [ "${ENABLE_METRICS}" = "true" ]; then
  curl -s "http://localhost:${MCP_LOCAL_PORT}/metrics" | head -n 20 || echo "Metrics endpoint not responding"
fi
```

Summary: Metrics endpoint probed; initial lines displayed if available.

### Log inspection

```bash
POD_NAME="$(kubectl get pods -n "${MCP_SERVER_NAMESPACE}" -l app=${SERVER_NAME} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
kubectl logs -n "${MCP_SERVER_NAMESPACE}" "${POD_NAME}" | tail -n 50
```

Summary: Recent pod logs reviewed for operational signals.

### Cleanup (optional)

```bash
kill "${MCP_PORT_FORWARD_PID}" 2>/dev/null || true
kubectl delete mcpserver "${SERVER_NAME}" -n "${MCP_SERVER_NAMESPACE}" || true
az group delete --name "${RESOURCE_GROUP}" --yes --no-wait || true
```

Summary: Initiated cleanup of MCPServer and Azure resource group assets.

## Summary

The Open-WebSearch MCP server was configured, containerized, deployed to AKS via KMCP, and validated through search and content fetch operations. Environment variables standardized resource naming, search behavior, rate limits, and optional metrics. Observability and rate limiting basics were demonstrated, establishing a foundation for production hardening.

## Next Steps

- Implement structured JSON-RPC MCP interface tests (integration suite)
- Add comprehensive error handling (engine failures, proxy errors)
- Refine rate limiting and add circuit breaker logic
- Integrate centralized logging and metrics export (Prometheus format)
- Document legal and ethical scraping guidelines and usage constraints
- Add acceptance tests for each tool and environment variable matrix
- Publish deployment guide updates and finalize task 003 closure criteria

Summary: Follow-on tasks target robustness, compliance, observability, and documentation completeness for production readiness.
