# Deploy RAG Service On KAITO Workspace - Phi-3.5 Mini

This executable guide shows how to add a simple Retrieval-Augmented
Generation (RAG) API on top of a KAITO Workspace running on Azure
Kubernetes Service (AKS). It assumes KAITO is already installed and a
`Workspace` is deployed with an OpenAI-compatible inference endpoint (for
example, the phi-3.5-mini-instruct model). See the prerequisites section beliw for information on how to deploy this configuration.

The RAG service is deployed as a Kubernetes `Deployment` and `Service`
that stores a small in-memory document collection for demo purposes,
performs a naive similarity search client-side, and calls the KAITO
OpenAI-compatible endpoint for final answer generation.

Summary: Adds an in-cluster RAG API on top of an existing KAITO
workspace using only Kubernetes-native resources.

## Prerequisites

This section defines all environment variables used in this document.
Defaults are provided and can be overridden before execution. Values that
must be globally unique use the `${HASH}` suffix for reproducible
uniqueness. Environment variables are established first so they are
available to any prerequisite executable documents that you may choose to
run.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"

# Core Azure / AKS context (must match your existing KAITO workspace setup)
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-aks-kaito-rg_${HASH}}"
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-kaito-${HASH}}"

# Existing KAITO workspace and namespace (from Deploy_Kaito_Workspace.md)
export WORKSPACE_NAMESPACE="${WORKSPACE_NAMESPACE:-default}"
export WORKSPACE_NAME="${WORKSPACE_NAME:-workspace-phi-3-5-mini-${HASH}}"

# RAG service configuration
export RAG_NAMESPACE="${RAG_NAMESPACE:-${WORKSPACE_NAMESPACE}}"
export RAG_APP_NAME="${RAG_APP_NAME:-rag-service-${HASH}}"
export RAG_SERVICE_NAME="${RAG_SERVICE_NAME:-${RAG_APP_NAME}}"
export RAG_DEPLOYMENT_NAME="${RAG_DEPLOYMENT_NAME:-${RAG_APP_NAME}}"

# KAITO model preset (used for OpenAI-style requests)
export MODEL_PRESET="${MODEL_PRESET:-phi-3.5-mini-instruct}"

# Simple in-cluster RAG image (demo microservice)
# Replace with your own image if desired.
export RAG_IMAGE="${RAG_IMAGE:-ghcr.io/azure/aks-mcp/rag-demo:latest}"

# Optional: control RAG pod resources
export RAG_CPU_REQUEST="${RAG_CPU_REQUEST:-100m}"
export RAG_MEMORY_REQUEST="${RAG_MEMORY_REQUEST:-256Mi}"
export RAG_CPU_LIMIT="${RAG_CPU_LIMIT:-500m}"
export RAG_MEMORY_LIMIT="${RAG_MEMORY_LIMIT:-512Mi}"
```

Let's dump the values for reference:

```bash
# Variable summary for traceability
VARS=(
  HASH
  AZURE_SUBSCRIPTION_ID
  AZURE_LOCATION
  AZURE_RESOURCE_GROUP
  AKS_CLUSTER_NAME
  WORKSPACE_NAMESPACE
  WORKSPACE_NAME
  RAG_NAMESPACE
  RAG_APP_NAME
  RAG_SERVICE_NAME
  RAG_DEPLOYMENT_NAME
  MODEL_PRESET
  RAG_IMAGE
  RAG_CPU_REQUEST
  RAG_MEMORY_REQUEST
  RAG_CPU_LIMIT
  RAG_MEMORY_LIMIT
)

for var in "${VARS[@]}"; do
  printf "%s=%s\n" "${var}" "${!var}"
done
```

Before starting this guide, you must complete the following executable
documents. With the environment now configured, these documents can safely
reuse the variables defined above.

- [Install KAITO on AKS](Install_Kaito_On_AKS.md)
- [Deploy KAITO workspace](Deploy_Kaito_Workspace.md)

Summary: Ensures KAITO and a workspace are already running before layering
the RAG service on top.

## Steps

Follow each step in order. Commands are idempotent where possible to allow
re-runs.

### Verify KAITO workspace and service

Confirm that the KAITO `Workspace` and associated inference `Service` from
the earlier guide are present and ready.

```bash
set -e

echo "Checking workspace ${WORKSPACE_NAME} in namespace ${WORKSPACE_NAMESPACE}..."
kubectl get workspace "${WORKSPACE_NAME}" -n "${WORKSPACE_NAMESPACE}"

SERVICE_NAME="${WORKSPACE_NAME}"
echo "Checking inference service ${SERVICE_NAME} in namespace ${WORKSPACE_NAMESPACE}..."
kubectl get svc "${SERVICE_NAME}" -n "${WORKSPACE_NAMESPACE}"

CLUSTER_IP="$(
  kubectl get svc "${SERVICE_NAME}" \
    -n "${WORKSPACE_NAMESPACE}" \
    -o jsonpath='{.spec.clusterIP}'
)"

if [ -z "${CLUSTER_IP}" ]; then
  echo "Inference service has no cluster IP; ensure Deploy_Kaito_Workspace.md completed" >&2
  exit 1
fi

export CLUSTER_IP
echo "KAITO inference service cluster IP: ${CLUSTER_IP}"
```

Summary: Confirms the KAITO workspace and inference service are running and
reachable inside the cluster.

### Create RAG service manifest

Create a Kubernetes manifest for a simple RAG microservice. The service
reads documents from a built-in corpus and calls the KAITO OpenAI-compatible
endpoint using the in-cluster service DNS name.

```bash
export RAG_MANIFEST="${RAG_MANIFEST:-/tmp/rag-service-${HASH}.yaml}"

cat > "${RAG_MANIFEST}" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${RAG_DEPLOYMENT_NAME}
  namespace: ${RAG_NAMESPACE}
  labels:
    app: ${RAG_APP_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${RAG_APP_NAME}
  template:
    metadata:
      labels:
        app: ${RAG_APP_NAME}
    spec:
      containers:
      - name: rag-service
        image: ${RAG_IMAGE}
        imagePullPolicy: IfNotPresent
        env:
        - name: OPENAI_BASE_URL
          value: "http://${SERVICE_NAME}.${WORKSPACE_NAMESPACE}.svc.cluster.local"
        - name: OPENAI_MODEL
          value: "${MODEL_PRESET}"
        - name: OPENAI_API_KEY
          value: "unused-demo-key"
        - name: RAG_COLLECTION_NAME
          value: "kaito-demo"
        resources:
          requests:
            cpu: ${RAG_CPU_REQUEST}
            memory: ${RAG_MEMORY_REQUEST}
          limits:
            cpu: ${RAG_CPU_LIMIT}
            memory: ${RAG_MEMORY_LIMIT}
---
apiVersion: v1
kind: Service
metadata:
  name: ${RAG_SERVICE_NAME}
  namespace: ${RAG_NAMESPACE}
  labels:
    app: ${RAG_APP_NAME}
spec:
  selector:
    app: ${RAG_APP_NAME}
  ports:
  - name: http
    port: 80
    targetPort: 8080
EOF

cat "${RAG_MANIFEST}"
```

Summary: Generates a Kubernetes manifest that connects the RAG service to
the KAITO inference endpoint using environment variables.

### Apply RAG deployment and service

Apply the manifest to create or update the RAG deployment and service.

```bash
set -e

kubectl apply -f "${RAG_MANIFEST}"

echo "Current RAG deployment and service:"
kubectl get deploy "${RAG_DEPLOYMENT_NAME}" -n "${RAG_NAMESPACE}"
kubectl get svc "${RAG_SERVICE_NAME}" -n "${RAG_NAMESPACE}"
```

Summary: Deploys the RAG microservice and exposes it via a ClusterIP
service.

### Wait for RAG pods to become ready

Wait until the RAG deployment has at least one ready replica.

```bash
set -e

echo "Waiting for RAG deployment ${RAG_DEPLOYMENT_NAME} in namespace ${RAG_NAMESPACE}..."
kubectl rollout status deploy/"${RAG_DEPLOYMENT_NAME}" -n "${RAG_NAMESPACE}" --timeout=300s

echo "RAG pods:"
kubectl get pods -n "${RAG_NAMESPACE}" -l app="${RAG_APP_NAME}" -o wide
```

Summary: Ensures the RAG pods are running and ready to accept requests.

### Test RAG endpoint in-cluster

Use a temporary curl pod in the same namespace to send a sample RAG query
through the RAG service.

```bash
set -e

RAG_TEST_POD_NAME="rag-curl-${HASH}"

kubectl run "${RAG_TEST_POD_NAME}" \
  --image=curlimages/curl \
  --restart=Never \
  --rm \
  -i \
  --namespace="${RAG_NAMESPACE}" \
  -- \
  curl -sS -X POST "http://${RAG_SERVICE_NAME}.${RAG_NAMESPACE}.svc.cluster.local/rag/chat" \
    -H "Content-Type: application/json" \
    -d '{
      "query": "Explain the basics of Kubernetes.",
      "top_k": 3
    }' || {
      echo "RAG request failed; check pod logs with:" >&2
      echo "kubectl logs deploy/${RAG_DEPLOYMENT_NAME} -n ${RAG_NAMESPACE}" >&2
      exit 1
    }
```

Summary: Verifies that the RAG service can perform retrieval and generation
through the KAITO workspace model.

## Verification

This section can be run independently to confirm that the RAG service is
deployed and functional without re-applying manifests or modifying
resources.

```bash
set -e

echo "Verifying KAITO workspace and inference service..."
kubectl get workspace "${WORKSPACE_NAME}" -n "${WORKSPACE_NAMESPACE}" >/dev/null

SERVICE_NAME="${WORKSPACE_NAME}"
kubectl get svc "${SERVICE_NAME}" -n "${WORKSPACE_NAMESPACE}" >/dev/null

echo "Verifying RAG deployment and service..."
kubectl get deploy "${RAG_DEPLOYMENT_NAME}" -n "${RAG_NAMESPACE}" >/dev/null
kubectl get svc "${RAG_SERVICE_NAME}" -n "${RAG_NAMESPACE}" >/dev/null

echo "Listing RAG pods:"
kubectl get pods -n "${RAG_NAMESPACE}" -l app="${RAG_APP_NAME}"

echo "Performing lightweight RAG health check..."
RAG_TEST_POD_NAME="rag-verify-${HASH}"

kubectl run "${RAG_TEST_POD_NAME}" \
  --image=curlimages/curl \
  --restart=Never \
  --rm \
  -i \
  --namespace="${RAG_NAMESPACE}" \
  -- \
  curl -sS "http://${RAG_SERVICE_NAME}.${RAG_NAMESPACE}.svc.cluster.local/health" || {
    echo "RAG health endpoint failed; inspect logs:" >&2
    echo "kubectl logs deploy/${RAG_DEPLOYMENT_NAME} -n ${RAG_NAMESPACE}" >&2
    exit 1
  }

echo "Verification succeeded."
```

Summary: Confirms that the KAITO workspace, inference service, and RAG
microservice are all present and responding to basic health checks.

## Summary

In this document you extended an existing KAITO workspace on AKS by
deploying a simple RAG service that connects to the KAITO OpenAI-compatible
inference endpoint, maintains a small in-memory document collection for
retrieval, and exposes an HTTP API for RAG-style question answering inside
the cluster.

Summary: RAG capabilities were successfully layered on top of the KAITO
workspace, enabling retrieval-augmented generation entirely within the AKS
cluster.

## Next Steps

To move this demo toward a production-grade solution, consider:

1. Replacing the demo RAG container with your own microservice that
   integrates a managed vector database such as Azure Cosmos DB for MongoDB,
   Azure AI Search, or PostgreSQL with pgvector.
2. Exposing the RAG service externally via an Ingress controller, Azure
   Application Gateway, or Azure Load Balancer and securing it with OAuth or
   workload identity.
3. Adding observability for both KAITO and the RAG service using Azure
   Monitor, Prometheus, or OpenTelemetry for tracing.
4. Implementing request logging, rate limiting, and safe prompt patterns to
   harden the external interface.
5. Creating additional executable documents that automate data ingestion for
   your own documents and domain-specific knowledge.

Summary: Recommended enhancements help productionize the RAG stack,
including security, observability, and scalable vector storage.
