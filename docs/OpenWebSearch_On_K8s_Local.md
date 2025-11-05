# Local Open-WebSearch MCP Server (Kind Cluster)

## Introduction

This executable document describes deploying the Open-WebSearch MCP server onto a local Kubernetes cluster managed by Kind using the KMCP controller. Open-WebSearch provides multi-engine web search and content retrieval tools without requiring API keys (HTML scraping). The objective is to establish a fully local, repeatable workflow for development and validation prior to promotion to remote environments (e.g. AKS). All commands use environment variables for reproducibility.

Summary: Creates a local Kind cluster, installs KMCP, builds/loads the Open-WebSearch MCP server image, deploys it, validates functionality, and optionally cleans up.

## Prerequisites

Required tools installed locally (recent stable versions recommended):

1. Docker (or compatible container runtime) - image build and storage.
2. Kind - local Kubernetes cluster provisioning.
3. Helm - installs KMCP CRDs via OCI chart.
4. KMCP CLI - scaffolds/builds/deploys MCP servers.
5. Node.js (>= 18) and npm - build Open-WebSearch code.
6. jq (optional) - parse JSON output during tests.

Validation commands (non-blocking warnings shown if missing):

```bash
command -v docker >/dev/null || echo "Docker missing"
command -v kind >/dev/null || echo "Kind missing"
command -v helm >/dev/null || echo "Helm missing"
command -v kmcp >/dev/null || echo "KMCP CLI missing"
command -v node >/dev/null || echo "Node.js missing"
command -v npm >/dev/null || echo "npm missing"
command -v jq >/dev/null || echo "jq missing (optional)"
```

Summary: Confirms local tooling readiness for a Kind-based MCP deployment.

## Setting up the environment

Environment variables parameterize cluster naming, image references, ports, and test values. Adjust defaults as required.

```bash
export CLUSTER_NAME="${CLUSTER_NAME:-kind-openwebsearch-$(date -u +"%y%m%d%H%M")}"  # Unique cluster name with timestamp
export KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-kindest/node:v1.34.0}"  # Kind node image (override to change k8s version)
export KIND_CONFIG_FILE="${KIND_CONFIG_FILE:-/tmp/kind-${CLUSTER_NAME}.yaml}"  # Kind config path
export KIND_LOG_LEVEL="${KIND_LOG_LEVEL:-3}"                       # Kind verbosity
export KMCP_NAMESPACE="${KMCP_NAMESPACE:-kmcp-system}"            # KMCP controller namespace

export SERVER_NAME="${SERVER_NAME:-open-websearch-mcp}"           # Logical MCP server name
export MCP_IMAGE_FULL="${MCP_IMAGE_FULL:-ghcr.io/aas-ee/open-web-search:latest}"  # Full image reference (override to build locally)
export MCP_SERVER_NAMESPACE="${MCP_SERVER_NAMESPACE:-default}"    # Namespace for MCPServer resource
export MCP_LOCAL_PORT="${MCP_LOCAL_PORT:-3000}"                   # Local forward port
export MCP_SERVICE_PORT="${MCP_SERVICE_PORT:-3000}"               # In-cluster service port
export KMCP_CRDS_RELEASE_NAME="${KMCP_CRDS_RELEASE_NAME:-kmcp-crds}"  # Helm release name for CRDs

export ALLOWED_SEARCH_ENGINES="${ALLOWED_SEARCH_ENGINES:-bing,duckduckgo,brave,exa,baidu,csdn,juejin}"  # Enabled engines
export DEFAULT_SEARCH_ENGINE="${DEFAULT_SEARCH_ENGINE:-duckduckgo}"                                    # Default engine
export USE_PROXY="${USE_PROXY:-false}"
export PROXY_URL="${PROXY_URL:-}"                                 # Proxy URL if USE_PROXY=true
export RATE_LIMIT_QPS="${RATE_LIMIT_QPS:-5}"                      # Approximate queries per second
export ENABLE_METRICS="${ENABLE_METRICS:-true}"                   # Enable metrics endpoint
export METRICS_PORT="${METRICS_PORT:-9090}"                       # Metrics port

export MCP_PROTOCOL_VERSION="${MCP_PROTOCOL_VERSION:-2024-10-22}"    # MCP protocol version used in initialize
export MCP_CLIENT_NAME="${MCP_CLIENT_NAME:-exec-doc}"                # MCP client name for initialize
export MCP_CLIENT_VERSION="${MCP_CLIENT_VERSION:-0.0.1}"             # MCP client version for initialize
export MCP_SEARCH_LIMIT="${MCP_SEARCH_LIMIT:-3}"                     # Result limit for MCP search tool
export MCP_SEARCH_ENGINES="${MCP_SEARCH_ENGINES:-[\"duckduckgo\", \"bing\"]}" # Engines array for MCP search tool
export MCP_MCP_ENDPOINT="${MCP_ENDPOINT:-http://localhost:${MCP_LOCAL_PORT}/mcp}" # HTTP MCP endpoint base
export MCP_INIT_FILE="${MCP_INIT_FILE:-/tmp/mcp-init-request.json}"

export TEST_SEARCH_QUERY="${TEST_SEARCH_QUERY:-open source vector database comparison}"                 # Sample query
```

Summary: Variables defined for local cluster, image usage, server configuration, search behavior, and test scenarios.

### Verify environment variable values

The following command outputs the active values of all parameters for traceability and debugging. This can be re-run after any modification to confirm the effective configuration.

```bash
# Ensure HASH exists (YYMMDDHHMM)
: "${HASH:=$(date -u +"%y%m%d%H%M")}"

VARS=(
  HASH
  CLUSTER_NAME
  KIND_NODE_IMAGE
  KIND_CONFIG_FILE
  KIND_LOG_LEVEL
  KMCP_NAMESPACE
  SERVER_NAME
  MCP_IMAGE_FULL
  MCP_SERVER_NAMESPACE
  MCP_LOCAL_PORT
  MCP_SERVICE_PORT
  MCP_MCP_ENDPOINT
  MCP_INIT_FILE
  KMCP_CRDS_RELEASE_NAME
  ALLOWED_SEARCH_ENGINES
  DEFAULT_SEARCH_ENGINE
  USE_PROXY
  PROXY_URL
  RATE_LIMIT_QPS
  ENABLE_METRICS
  METRICS_PORT
  TEST_SEARCH_QUERY
  TEST_FETCH_GITHUB_REPO
  MCP_PROTOCOL_VERSION
  MCP_CLIENT_NAME
  MCP_CLIENT_VERSION
  MCP_SEARCH_LIMIT
  MCP_SEARCH_ENGINES
  SEARCH_ENGINES_JSON
  MCP_SESSION_ID
  MCP_PORT_FORWARD_PID
)

for v in "${VARS[@]}"; do
  printf "%s=%s\n" "$v" "${!v}"
done
```

Summary: Provides a deterministic snapshot of all configured environment variables prior to executing procedural steps.

## Steps

Each step provides purpose, commands, and expected outcome.

### Check preconditions

```bash
if ! command -v kind >/dev/null 2>&1; then
  echo "Kind not found. Install: https://kind.sigs.k8s.io/docs/user/quick-start/"; exit 1
fi
if command -v docker >/dev/null 2>&1; then
  docker info >/dev/null 2>&1 || { echo "Docker daemon not reachable"; exit 1; }
else
  echo "Docker runtime required"; exit 1
fi
```

Summary: Validates that Kind and container runtime are operational.

### Configure Kind cluster file

```bash
cat > "${KIND_CONFIG_FILE}" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
  - role: control-plane
    image: ${KIND_NODE_IMAGE}
  - role: worker
    image: ${KIND_NODE_IMAGE}
EOF
echo "Kind config written: ${KIND_CONFIG_FILE}"; head -n 10 "${KIND_CONFIG_FILE}" || true
```

Summary: Basic two-node (control-plane + worker) Kind configuration written to file.

### Create Kind cluster

```bash
echo "Creating cluster ${CLUSTER_NAME} with image ${KIND_NODE_IMAGE}"
kind create cluster --name "${CLUSTER_NAME}" \
  --config "${KIND_CONFIG_FILE}" \
  --retain \
  --verbosity "${KIND_LOG_LEVEL}"
```

<!-- expected_similarity=0.5 -->

```text
Creating cluster "kmcp-dev-2510101432" ...
 ✓ Ensuring node image (kindest/node:v1.34.0) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-kmcp-dev-2510101432"
You can now use your cluster with:

kubectl cluster-info --context kind-kmcp-dev-2510101432

Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
```

Summary: Local Kubernetes cluster available with context set (kind-${CLUSTER_NAME}).

### Install KMCP CRDs

```bash
helm upgrade --install ${KMCP_CRDS_RELEASE_NAME} \
  oci://ghcr.io/kagent-dev/kmcp/helm/kmcp-crds \
  --namespace ${KMCP_NAMESPACE} \
  --create-namespace

kubectl get crds | grep mcp || echo "MCP CRDs not found"

echo "Waiting for MCPServer CRD to register (api-resources)..."
for i in $(seq 1 30); do
  if kubectl api-resources | grep -q "mcpserver"; then
    echo "MCPServer CRD available"; break
  fi
  sleep 2
done
kubectl api-resources | grep -i mcpserver || echo "MCPServer CRD still missing (check Helm release/logs)"

# Optional: wait for Established condition if CRD plural is known
kubectl get crd | grep -i mcp || true
kubectl wait --for=condition=Established crd/mcpservers.kmcp.io --timeout=60s 2>/dev/null || echo "CRD Established wait skipped or failed"
```

Summary: KMCP CRDs installed or upgraded in target namespace.

### Install KMCP controller

```bash
kmcp install
echo "KMCP controller pods:" && kubectl get pods -n "${KMCP_NAMESPACE}" || true
```

Summary: KMCP controller deployed; pods visible in namespace.

### Clone Open-WebSearch repository

This script can work with the pre-built and published container, or it can work from source. It can be useful in a development environment to have the source available locally, regardless of which approach we are taking. This block will ensure the local working copy of Open-WebSearch source is present by cloning if absent or updating if already cloned.

```bash
if [ -d "open-webSearch/.git" ]; then
  echo "Repository exists - updating"
  git -C open-webSearch fetch --all --prune
  git -C open-webSearch pull --ff-only
else
  echo "Cloning repository"
  git clone https://github.com/Aas-ee/open-webSearch.git open-webSearch
fi

git -C open-webSearch log -1 --oneline
```

Summary: Repository directory synchronized with remote (clone or fast-forward pull) and latest commit displayed.

### (Optional) Build and validate locally

```bash
cd open-webSearch
npm install
npm run build
node dist/index.js --help | head -n 20
```

Summary: Build artifacts generated; help output confirms executable entry point.

### (Optional) Local smoke tests

```bash
node dist/index.js search --engine "${DEFAULT_SEARCH_ENGINE}" --query "${TEST_SEARCH_QUERY}" | head -n 20
node dist/index.js fetchGithubReadme --repo "${TEST_FETCH_GITHUB_REPO}" | head -n 20
```

Summary: Core CLI functions produce sample output.

### Build and load image into Kind (if overriding upstream image)

```bash
if [[ "${MCP_IMAGE_FULL}" == ghcr.io/aas-ee/open-web-search:* ]]; then
  echo "Using upstream image ${MCP_IMAGE_FULL}; skipping local build and load.";
else
  docker build -t "${MCP_IMAGE_FULL}" . || { echo "Docker build failed"; }
  kind load docker-image "${MCP_IMAGE_FULL}" --name "${CLUSTER_NAME}" || { echo "Kind image load failed"; }
  docker image inspect "${MCP_IMAGE_FULL}" >/dev/null && echo "Image built and loaded";
fi
```

Summary: Upstream image used or custom image built and loaded into cluster.

### Create MCPServer resource

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
kubectl get mcpserver "${SERVER_NAME}" -n "${MCP_SERVER_NAMESPACE}" -o yaml | head -n 30
```

### Wait for MCPServer resources (service + pod readiness)

The controller creates Deployment and Service asynchronously. These blocks wait until the Service exists and at least one pod reports Ready, reducing race conditions for subsequent port-forward.

```bash
echo "Waiting for Service ${SERVER_NAME} in namespace ${MCP_SERVER_NAMESPACE}";
for i in $(seq 1 60); do
  if kubectl get svc "${SERVER_NAME}" -n "${MCP_SERVER_NAMESPACE}" >/dev/null 2>&1; then
    echo "Service found (attempt ${i})"; break
  fi
  if [[ $i -eq 60 ]]; then
    echo "Service did not appear after 60s"
    kubectl get svc -n "${MCP_SERVER_NAMESPACE}"
  fi
  sleep 1
done
```

<!-- expected_similarity=".*Service found.*" -->

```text
Service found (attempt 2)
```

```bash
echo "Waiting for at least one Ready pod";
for i in $(seq 1 120); do
  READY_CT=$(kubectl get pods -n "${MCP_SERVER_NAMESPACE}" \
    -l app.kubernetes.io/name="${SERVER_NAME}" \
    -o jsonpath='{range .items[*]}{range .status.conditions[*]}{@.type}{":"}{@.status}{"\n"}{end}{end}' 2>/dev/null \
    | grep -c 'Ready:True' || true)
  if [[ ${READY_CT} -ge 1 ]]; then
    echo "Pod Ready (attempt ${i})"
    break
  fi
  if [[ $i -eq 120 ]]; then
    echo "Pod did not become Ready after 120s"
    kubectl get pods -n "${MCP_SERVER_NAMESPACE}" -l app.kubernetes.io/name="${SERVER_NAME}"
  fi
  sleep 1
done
```

<!-- expected_similarity=".*Pod Ready.*" -->

```text
Pod Ready (attempt 5)
```

### Port-forward MCP server

Creates a local tunnel (`kubectl port-forward`) mapping `MCP_LOCAL_PORT` to `MCP_SERVICE_PORT` enabling HTTP access to the MCP server.

```bash
echo "Starting port-forward for service ${SERVER_NAME} (${MCP_SERVER_NAMESPACE}) on local port ${MCP_LOCAL_PORT}";
kubectl port-forward -n "${MCP_SERVER_NAMESPACE}" svc/"${SERVER_NAME}" \
  "${MCP_LOCAL_PORT}:${MCP_SERVICE_PORT}" >/tmp/port-forward-${SERVER_NAME}.log 2>&1 &
export MCP_PORT_FORWARD_PID=$!
echo "Port-forward PID=${MCP_PORT_FORWARD_PID}";

ATTEMPTS=30
for i in $(seq 1 ${ATTEMPTS}); do
  if ss -tnlp | grep -q ":${MCP_LOCAL_PORT}"; then
    if curl -s "http://localhost:${MCP_LOCAL_PORT}/search?engine=${DEFAULT_SEARCH_ENGINE}&query=healthcheck" >/dev/null 2>&1; then
      echo "Port-forward ready (attempt ${i})"; break
    fi
  fi
  if [[ ${i} -eq ${ATTEMPTS} ]]; then
    echo "Port-forward failed after ${ATTEMPTS} attempts";
    echo "Last 60 port-forward log lines:"; tail -n 60 /tmp/port-forward-${SERVER_NAME}.log || true
  fi
  sleep 1
done

ss -tnlp | grep ":${MCP_LOCAL_PORT}" || echo "Listener not found despite readiness loop"
```

<!-- expected_similarity=".*Port-forward ready.*" -->

```text
Port-forward ready (attempt 1)
```

Summary: Port-forward established with readiness loop ensuring HTTP endpoint responds before subsequent tests.

### Initialize the MCP Server

Establish a streamable HTTP MCP session. The Open-WebSearch server currently uses
the pre-2024-10 MCP schema (clientInfo/protocolVersion). Provide those keys even
though newer servers expect nested objects. The Accept header must advertise both
`application/json` and `text/event-stream` for FastMCP compatibility.

```bash
unset MCP_SESSION_ID
cat <<EOF > "${MCP_INIT_FILE}"
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"${MCP_CLIENT_NAME}","version":"${MCP_CLIENT_VERSION}"},"protocolVersion":"${MCP_PROTOCOL_VERSION}","capabilities":{}}}
EOF

INIT_HEADERS=$(mktemp)
curl -sS \
  -D "${INIT_HEADERS}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data-binary "@${MCP_INIT_FILE}" \
  -o /tmp/mcp-init.json \
  "${MCP_MCP_ENDPOINT}"

MCP_SESSION_ID=$(awk -F': ' 'tolower($1)=="mcp-session-id" {print $2}' "${INIT_HEADERS}" | tr -d '\r')
if [ -z "${MCP_SESSION_ID}" ]; then
  echo "Failed to obtain session ID from initialize response";
  cat /tmp/mcp-init.json || cat "${INIT_HEADERS}"
else
  export MCP_SESSION_ID
  echo "Initialized streamable HTTP session: MCP_SESSION_ID=${MCP_SESSION_ID}";
fi

rm -f "${MCP_INIT_FILE}" "${INIT_HEADERS}"
```

<!-- expected_similarity="Initialized streamable HTTP session:.*" -->

```text
Initialized streamable HTTP session: MCP_SESSION_ID=9w0-w9e0
```

# Perform a search

```bash
[ "$(curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -H "mcp-session-id: $MCP_SESSION_ID" -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' "$MCP_MCP_ENDPOINT")" = 200 ] && echo "Session is active" || echo "Session is inactive"

MCP_SEARCH_REQUEST=$(cat <<EOF
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"search","arguments":{"query":"${TEST_SEARCH_QUERY}","limit":${MCP_SEARCH_LIMIT},"engines":${SEARCH_ENGINES_JSON}}}}
EOF
)

echo "Invoking search tool (endpoint=$MCP_MCP_ENDPOINT, limit=${MCP_SEARCH_LIMIT}, engines=${MCP_SEARCH_ENGINES})"
curl -s -H 'Content-Type: application/json' -H "mcp-session-id: $MCP_SESSION_ID" \
  -d "${MCP_SEARCH_REQUEST}" "${MCP_MCP_ENDPOINT}" \
  | jq '.result.content[0].text' \
  | sed 's/\\n/\n/g' \
  | head -n 40
```

Summary: Session lifecycle demonstrated (initialize, verify, search, optional keep-alive, delete) using streamable HTTP transport.

<!--
### Cleanup (optional)

```bash
kill "${MCP_PORT_FORWARD_PID}" 2>/dev/null || true
kubectl delete mcpserver "${SERVER_NAME}" -n "${MCP_SERVER_NAMESPACE}" || true
kind delete cluster --name "${CLUSTER_NAME}" || true
```

Summary: Local resources removed (MCPServer and Kind cluster).
-->

## Summary

The Open-WebSearch MCP server was deployed on a local Kind cluster using KMCP. The workflow demonstrated image usage (upstream or custom), MCPServer resource application, functional endpoint tests (search, README retrieval), rate limiting probe, metrics access, and log inspection. Environment variables standardized naming and configuration for reproducibility.

## Next Steps

- Add JSON-RPC protocol level integration tests for MCP operations
- Integrate structured observability (OpenTelemetry export) and enhanced metrics
- Implement advanced rate limiting (token bucket + burst smoothing)
- Add proxy and network policy examples for restricted egress scenarios
- Introduce security scanning for custom-built images (Trivy/Grype) before load
- Extend documentation with AKS promotion steps (reference separate Exec Doc)
- Provide a VS Code task for automatic rebuild and redeploy on file changes

Summary: Follow-on tasks focus on protocol validation, observability, security, performance, and promotion readiness.
