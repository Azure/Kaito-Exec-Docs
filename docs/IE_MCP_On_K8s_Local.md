## Introduction

This document continues from `IE_MCP_Server.md`. The local FastMCP
server previously scaffolded will now be deployed onto a local Kubernetes
development cluster managed by Kind. The KMCP controller will be installed and
used to manage the MCP server lifecycle. Each step uses environment variables
for consistency and repeatability.

Summary: A local Kind cluster will be created, KMCP controller components will
be installed, the server image will be built and loaded, and the MCP server
will be deployed and validated.

### Executable Documentation

This document is an "Executable Document". This can help significantly with learning and development cycles. By editing the descriptive content alongside the scripting found within this document you can ensure that you have a fully documented, reproducible workflow.

When building customizing this solution for your own purposes we recommend using the following command to execute this document in an unattended environment. Errors will often be spotted and reported during execution:

`clear; ie clear-env --force; kind get clusters | xargs -r -I {} kind delete cluster --name {}; ie execute docs/IE_MCP_On_K8s.md`

NOTE: this command clears all workplace content and environment setup. It is assumed that the executable document will reconfigure everything to ensure a consistent development environment.

See the [Innovation Engine](http://github.com/Azure/InnovationEngine) project for more details.

## Prerequisites

The following tools must be installed and accessible in the shell. Versions do
not need to be exact but recent stable releases are recommended.

Required tools:

1. Docker - builds and stores container images locally.
2. Kind - creates local Kubernetes clusters inside Docker.
3. Helm - installs KMCP Custom Resource Definitions and controller charts.
4. KMCP CLI - scaffolds, builds, and deploys MCP servers.
5. uv - runs FastMCP Python servers locally (already used in prior document).
6. MCP Inspector - validates connectivity to the MCP server.

Validation commands (no changes required yet):

```bash
docker version
kind version
helm version
kmcp --help | head -n 5
uv --version
inspector --help 2>/dev/null || npx @modelcontextprotocol/inspector --help
kmcp --version
```

Summary: All required local tooling should be installed and verified before
continuing.

## Setting up the environment

Environment variables provide clear configuration of cluster, namespace, image
tags, and feature toggles. The `HASH` ensures uniqueness for names when desired.

It is assumed that all the environment variables defined in `IE_MCP_Server.md` have been set in the current environment.

Note: For Azure AKS production deployments requiring resilient node VM size selection (quota + availability pre-flight), reference the executable document `AKS_VM_Size_Selection.md`. That guide provides a parameterized script to export a viable `AKS_NODE_VM_SIZE` before cluster creation. This local Kind workflow does not require SKU evaluation but downstream promotion to AKS should incorporate that pre-flight step to reduce allocation failures.

Define the following in the current shell (adjust defaults if required):

```bash
export HASH="$(date +'%y%m%d%H%M')"
export CLUSTER_NAME="${CLUSTER_NAME:-kmcp-dev-${HASH}}"
export K8S_VERSION="${K8S_VERSION:-v1.34.0}"
export KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-kindest/node:${K8S_VERSION}}"
export FALLBACK_NODE_IMAGE="${FALLBACK_NODE_IMAGE:-kindest/node:v1.33.0}"
export KIND_LOG_LEVEL="${KIND_LOG_LEVEL:-3}"
export KIND_CONFIG_FILE="${KIND_CONFIG_FILE:-/tmp/kind-${CLUSTER_NAME}.yaml}"
export KMCP_NAMESPACE="${KMCP_NAMESPACE:-kmcp-system}"                # Namespace for KMCP controller & CRDs

# MCP server/image related variables (required for build/deploy steps)
export SERVER_NAME="${SERVER_NAME:-innovation-engine-mcp}"            # Logical MCP server name
export MCP_PROJECT_DIR="${MCP_PROJECT_DIR:-$(pwd)/${SERVER_NAME}}"  # Root of KMCP-scaffolded server
export MCP_IMAGE_NAME="${MCP_IMAGE_NAME:-${SERVER_NAME}}"             # Base image name
export MCP_IMAGE_TAG="${MCP_IMAGE_TAG:-latest}"                      # Image tag
export MCP_IMAGE_FULL="${MCP_IMAGE_FULL:-${MCP_IMAGE_NAME}:${MCP_IMAGE_TAG}}"  # Full image reference
export MCP_SERVER_NAMESPACE="${MCP_SERVER_NAMESPACE:-default}"        # Namespace for MCPServer CR
export MCP_LOCAL_PORT="${MCP_LOCAL_PORT:-3000}"                      # Local port for port-forward
export MCP_SERVICE_PORT="${MCP_SERVICE_PORT:-3000}"                  # Service target port
export MCP_CLIENT_URL="${MCP_CLIENT_URL:-http://127.0.0.1:${MCP_LOCAL_PORT}/mcp}"  # Client URL for tests
export IE_VERSION="${IE_VERSION:-latest}"                            # Innovation Engine version
export KMCP_CRDS_RELEASE_NAME="${KMCP_CRDS_RELEASE_NAME:-kmcp-crds}"  # CRDs Helm release name
export NO_INSPECTOR_FLAG="${NO_INSPECTOR_FLAG:---no-inspector}"       # Empty string disables inspector; set to empty to enable
export KMCP_WAIT_TIMEOUT="${KMCP_WAIT_TIMEOUT:-180}"                  # Controller readiness timeout
```

For convenience lets output these values to the console:

```bash
echo "## Environment Setup"

echo "HASH=${HASH}"
echo "MCP_PROJECT_DIR=${MCP_PROJECT_DIR}"
echo "CLUSTER_NAME=${CLUSTER_NAME}"
echo "K8S_VERSION=${K8S_VERSION}"
echo "KIND_NODE_IMAGE=${KIND_NODE_IMAGE}"
echo "FALLBACK_NODE_IMAGE=${FALLBACK_NODE_IMAGE}"
echo "KIND_LOG_LEVEL=${KIND_LOG_LEVEL}"
echo "KIND_CONFIG_FILE=${KIND_CONFIG_FILE}"
echo "SERVER_NAME=${SERVER_NAME}"
echo "MCP_IMAGE_NAME=${MCP_IMAGE_NAME}"
echo "MCP_IMAGE_TAG=${MCP_IMAGE_TAG}"
echo "MCP_IMAGE_FULL=${MCP_IMAGE_FULL}"
echo "MCP_SERVER_NAMESPACE=${MCP_SERVER_NAMESPACE}"
echo "MCP_LOCAL_PORT=${MCP_LOCAL_PORT}"
echo "MCP_SERVICE_PORT=${MCP_SERVICE_PORT}"
echo "MCP_CLIENT_URL=${MCP_CLIENT_URL}"
echo "IE_VERSION=${IE_VERSION}"
echo "KMCP_CRDS_RELEASE_NAME=${KMCP_CRDS_RELEASE_NAME}"
echo "NO_INSPECTOR_FLAG=${NO_INSPECTOR_FLAG}"
echo "KMCP_WAIT_TIMEOUT=${KMCP_WAIT_TIMEOUT}"
```

Summary: All variables have been defined with sensible defaults and may now be
used in subsequent steps.

## Steps

### Check preconditions

The following code will ensure that all the necessary preconditions have been met. If any are not met a message will be output and the run halted.

```bash
if ! command -v kind >/dev/null 2>&1; then
  echo "kind not found. Install: https://kind.sigs.k8s.io/docs/user/quick-start/"
  exit 1
fi

if command -v docker >/dev/null 2>&1; then
  if ! docker info >/dev/null 2>&1; then
    echo "docker daemon not reachable."
    exit 1
  fi
elif command -v nerdctl >/dev/null 2>&1; then
  if ! nerdctl info >/dev/null 2>&1; then
    echo "nerdctl container runtime not reachable."
    exit 1
  fi
else
  echo "No supported container runtime (docker or nerdctl) detected."
  exit 1
fi
```

Next up lets pre-pull the Node images as a convenience, and to ensure a fast-fail if there is a problem.

```bash
echo "Pulling primary node image: ${KIND_NODE_IMAGE}"
docker pull "${KIND_NODE_IMAGE}" >/dev/null 2>&1 || \
  (echo "Image pull failed for ${KIND_NODE_IMAGE}"; exit 1)
```

### Configure Kind

```bash
cat > "${KIND_CONFIG_FILE}" <<EOF
# kind cluster config
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
  - role: control-plane
    image: ${KIND_NODE_IMAGE}
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            cgroup-driver: systemd
    labels:
      mcp.dev/role: control-plane
  - role: worker
    image: ${KIND_NODE_IMAGE}
    labels:
      mcp.dev/role: worker
EOF

echo "Kind config written to ${KIND_CONFIG_FILE}"
```

### Create a local Kind cluster

Creates a single node development cluster. If a cluster of the same name
already exists, delete or reuse it (`kind get clusters`).

```bash
echo "Creating cluster ${CLUSTER_NAME} with image ${KIND_NODE_IMAGE}"
kind create cluster --name "${CLUSTER_NAME}" \
  --config "${KIND_CONFIG_FILE}" \
  --retain \
  --verbosity "${KIND_LOG_LEVEL}"
```

<!-- expected_similarity=0.6 -->

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

Summary: A local Kubernetes cluster is now available for KMCP components.

#### Cluster Create Failures

If you get an error message `ERROR: failed to create cluster: could not find a log line that matches "Reached target .Multi-User System.|detected cgroup v1"` it is often caused by issues with systemd. These are especially common when using Docker and WSL in a development environment, which can result in too many files being opened by kind. The easiest solution is delete unused kind clusters.

You can find the current kind clusters with `kind get clusters` and delete any that are no longer needed with `kind delete cluster --name "$CLUSTER_NAME"`.

### Install KMCP CRDs

Install (or upgrade) the KMCP Custom Resource Definitions required to represent MCP servers. Using `helm upgrade --install` makes the step idempotent and avoids the error `cannot re-use a name that is still in use` if the release already exists.

```bash
helm upgrade --install ${KMCP_CRDS_RELEASE_NAME} \
  oci://ghcr.io/kagent-dev/kmcp/helm/kmcp-crds \
  --namespace ${KMCP_NAMESPACE} \
  --create-namespace
```

Troubleshooting:

1. Release already exists in another namespace:

```bash
helm list -A | grep kmcp-crds || true
```

If the name appears under a different namespace than `${KMCP_NAMESPACE}`, either uninstall it there or choose a different `${KMCP_CRDS_RELEASE_NAME}`. 2. Stuck or failed previous install:

```bash
helm status ${KMCP_CRDS_RELEASE_NAME} -n ${KMCP_NAMESPACE} || true
helm uninstall ${KMCP_CRDS_RELEASE_NAME} -n ${KMCP_NAMESPACE} && \
  helm upgrade --install ${KMCP_CRDS_RELEASE_NAME} \
   oci://ghcr.io/kagent-dev/kmcp/helm/kmcp-crds \
   --namespace ${KMCP_NAMESPACE} --create-namespace
```

3. Version pinning (optional):

```bash
export KMCP_CRDS_VERSION=0.1.9
helm upgrade --install ${KMCP_CRDS_RELEASE_NAME} \
  oci://ghcr.io/kagent-dev/kmcp/helm/kmcp-crds \
  --version ${KMCP_CRDS_VERSION} \
  --namespace ${KMCP_NAMESPACE} --create-namespace
```

4. View CRDs after install:

```bash
kubectl get crds | grep mcp || true
```

Expected output excerpt (will vary by version):

```text
NAME: kmcp-crds
NAMESPACE: kmcp-system
STATUS: deployed
REVISION: <N>
```

Summary: KMCP CRDs are ensured present (installed or upgraded) in the target namespace.

### Install the KMCP controller

Deploys the controller manager responsible for reconciling MCPServer resources.
The KMCP CLI wraps Helm logic and performs installation checks.

```bash
kmcp install
```

<!-- exptected_similarity=0.6 -->

```text
🚀 Deploying KMCP controller to cluster...
No version specified, using latest: 0.1.8
Pulled: ghcr.io/kagent-dev/kmcp/helm/kmcp-crds:0.1.8
Digest: sha256:78ac150414d943e31a478dd51e0b6d056cd3f4d06efbce2cdcda26e78059c462
Release "kmcp-crds" has been upgraded. Happy Helming!
NAME: kmcp-crds
LAST DEPLOYED: Fri Oct 10 14:38:03 2025
NAMESPACE: kmcp-system
STATUS: deployed
REVISION: 2
TEST SUITE: None
Release "kmcp" does not exist. Installing it now.
Pulled: ghcr.io/kagent-dev/kmcp/helm/kmcp:0.1.8
Digest: sha256:aeb077ac6f245db0fac0d8ba108edcf2372535cb8b86006a3eff38381870d53d
NAME: kmcp
LAST DEPLOYED: Fri Oct 10 14:38:04 2025
NAMESPACE: kmcp-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
✅ KMCP controller deployed successfully
💡 Check controller status with: kubectl get pods -n kmcp-system
💡 View controller logs with: kubectl logs -l app.kubernetes.io/name=kmcp -n kmcp-system
```

Monitor rollout status to ensure KMCP components are operational.

```bash
echo "Initial KMCP pod state:" && kubectl get pods -n "${KMCP_NAMESPACE}" -o wide || true

echo "Waiting for KMCP controller deployment to become Available (timeout: ${KMCP_WAIT_TIMEOUT}s)..."
if ! kubectl rollout status deployment/kmcp-controller-manager -n "${KMCP_NAMESPACE}" --timeout="${KMCP_WAIT_TIMEOUT}s"; then
  echo "Rollout status command timed out or failed; entering fallback polling.";
  END=$(( $(date +%s) + KMCP_WAIT_TIMEOUT ))
  while [ $(date +%s) -lt $END ]; do
    READY=$(kubectl get deployment kmcp-controller-manager -n "${KMCP_NAMESPACE}" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)
    DESIRED=$(kubectl get deployment kmcp-controller-manager -n "${KMCP_NAMESPACE}" -o jsonpath='{.status.replicas}' 2>/dev/null || echo 1)
    if [ "$READY" = "$DESIRED" ] && [ "$READY" != "" ] && [ "$READY" != "0" ]; then
      echo "KMCP controller deployment is Available (${READY}/${DESIRED})."; break
    fi
    echo "Waiting... (available=${READY} desired=${DESIRED})"; sleep 5
  done
fi

echo "Final KMCP pod state:" && kubectl get pods -n "${KMCP_NAMESPACE}" -o wide || true
```

Summary: Controller deployment should be visible and operational in the target
namespace.

<!--
### Add Innovation Engine binary to the container image

Insert the Innovation Engine (IE) installation block immediately after the
`FROM` line of the existing Dockerfile.

```bash
export DOCKERFILE_PATH="${MCP_PROJECT_DIR}/Dockerfile"
sed -i "/^FROM /a \\
# --- Innovation Engine installation ---\\nARG IE_VERSION=${IE_VERSION}\\nRUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \\\\n+    && rm -rf /var/lib/apt/lists/* \\\\n+    && curl -fsSL -o /tmp/ie https://github.com/Azure/InnovationEngine/releases/download/${IE_VERSION}/ie \\\\n+    && chmod +x /tmp/ie \\\\n+    && install -Dm755 /tmp/ie /root/.local/bin/ie \\\\n+    && echo Innovation Engine installed to /root/.local/bin/ie\\nENV PATH=/root/.local/bin:\\$PATH\\n# --- End Innovation Engine installation ---" "$DOCKERFILE_PATH"
```

Summary: Innovation Engine installation commands have been added directly after the base image line in the Dockerfile.
-->

### Build the MCP server image and load it into Kind

This section builds the MCP server container image using the scaffolded project directory and loads the image into the Kind cluster for local development. This avoids the need to push images to a remote registry and ensures fast iteration.

Pre-flight validation helps avoid the `failed to detect project type: unknown project type` error which usually means `MCP_PROJECT_DIR` points somewhere that is not a KMCP scaffold (missing `kmcp.yaml`, `pyproject.toml`, `src/`, or missing `language: python` key in `kmcp.yaml`).

```bash
kmcp build --project-dir "${MCP_PROJECT_DIR}" \
  -t "${MCP_IMAGE_FULL}" \
  --kind-load-cluster "${CLUSTER_NAME}"

echo "Build succeeded: image ${MCP_IMAGE_FULL} loaded into kind cluster '${CLUSTER_NAME}'.";

```

Summary: Image is built and loaded into the Kind cluster (or a clear diagnostic is produced if pre-flight or build fails).

### Deploy the MCP server via KMCP controller

Create or updates an MCPServer custom resource using the configuration in
`kmcp.yaml`. Optionally suppress inspector launch by setting
`NO_INSPECTOR_FLAG=--no-inspector` before running the command.

```bash
kmcp deploy --file ${MCP_PROJECT_DIR}/kmcp.yaml --image ${MCP_IMAGE_FULL} ${NO_INSPECTOR_FLAG}
```

Summary: MCPServer resource has been applied and controller will create runtime
objects (Deployment, Service as defined by KMCP defaults).

### Inspect deployment status

Checks that pods are created and running. Replace label selectors if custom.

```bash
kubectl get mcpservers -A
kubectl get mcpservers -n ${MCP_SERVER_NAMESPACE}
kubectl get pods -n ${KMCP_NAMESPACE}
kubectl describe mcpserver -n ${MCP_SERVER_NAMESPACE} ${SERVER_NAME} || true
```

Summary: Resource and workload status information collected for verification.

Troubleshooting (NotFound describing MCPServer):
If `kubectl describe mcpserver -n ${KMCP_NAMESPACE} ${SERVER_NAME}` returns NotFound but
`kubectl get mcpservers -A` shows the resource (for example in `default`), the
issue is a namespace mismatch. The KMCP controller is installed in
`${KMCP_NAMESPACE}` (default: kmcp-system) but MCPServer custom resources can
reside in any namespace. Set `MCP_SERVER_NAMESPACE` to the namespace displayed
in the `kubectl get mcpservers -A` output or explicitly specify
`metadata.namespace` in `kmcp.yaml` to control placement.

### Forward MCP server ports locally

Enable local access to the MCP server HTTP endpoint by forwarding a local port to the in-cluster Service. This is useful for manual curl tests and for tools that expect a localhost endpoint.

```bash
kubectl port-forward -n "${MCP_SERVER_NAMESPACE}" svc/"${SERVER_NAME}" \
  "${MCP_LOCAL_PORT}:${MCP_SERVICE_PORT}" > /tmp/port-forward-${SERVER_NAME}.log 2>&1 &
export MCP_PORT_FORWARD_PID=$!
echo "Port forward PID=${MCP_PORT_FORWARD_PID}"
```

Summary: Local port ${MCP_LOCAL_PORT} exposes the MCP server service for testing and integration.

### Test the MCP server with a Python client

Use a minimal Python script with the `fastmcp` client (analogous to `IR_MCP_Server`) to validate tool invocation over the MCP protocol instead of raw HTTP.

#### Create test script

```bash
cat > /tmp/test_mcp_client.py <<'EOF'
import os
import asyncio
from fastmcp import Client

MCP_URL = os.environ.get("MCP_CLIENT_URL", "http://127.0.0.1:3000/mcp")

async def main():
  client = Client(MCP_URL)
  async with client:
    # Read raw content of the executable doc instead of passing a path
    doc_path = os.path.join(os.getcwd(), "tests", "hello_world.md")
    with open(doc_path, "r", encoding="utf-8") as f:
      raw = f.read()
    # Send full raw content; Innovation Engine will ignore non-executable text blocks
    params = {"content": raw}
    try:
      result = await client.call_tool("execute", params)
      print(f"Result from 'execute':", result)
    except Exception as exc:  # noqa: BLE001
      print(f"Tool 'execute' failed:", exc)

if __name__ == "__main__":
  asyncio.run(main())
EOF
```

Run the test:

```bash
cd innovation-engine-mcp
uv run python /tmp/test_mcp_client.py
```
