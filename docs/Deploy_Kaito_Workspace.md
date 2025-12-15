# Deploy KAITO Workspace - Phi-3.5 Mini Instruct

## Introduction

This executable guide demonstrates how to deploy an AI inference service using
KAITO (Kubernetes AI Toolchain Operator). The workflow creates a Workspace
custom resource that automatically provisions GPU nodes and deploys the
phi-3.5-mini-instruct model with an OpenAI-compatible inference endpoint.

KAITO handles all the complexity of GPU node provisioning, model deployment,
and service configuration, allowing you to deploy large language models with
minimal manual intervention. All commands use environment variables so the
procedure can be reused for different models and configurations.

Summary: Deploys a production-ready AI inference service using KAITO with
automatic GPU provisioning and model deployment.

## Prerequisites

The commands in this document need to use `kubectl` and `jq` so lets ensure they are intstalled first.

```bash
command -v kubectl >/dev/null || echo "kubectl missing"
command -v jq >/dev/null || echo "jq missing (optional)"
```

Export the variables that control workspace naming, model selection, GPU
instance type, and validation helpers. Unique names append the timestamp based
`HASH` suffix to prevent collisions.

```bash
export HASH="${HASH:-$(
  date -u +"%y%m%d%H%M"
)}"
export WORKSPACE_NAME="${WORKSPACE_NAME:-workspace-phi-3-5-mini-${HASH}}"
export WORKSPACE_NAMESPACE="${WORKSPACE_NAMESPACE:-default}"
export MODEL_PRESET="${MODEL_PRESET:-phi-3.5-mini-instruct}"
export AZURE_VM_SIZE="${AZURE_VM_SIZE:-Standard_NC40ads_H100_v5}"
export WORKSPACE_LABEL_KEY="${WORKSPACE_LABEL_KEY:-app}"
export WORKSPACE_LABEL_VALUE="${WORKSPACE_LABEL_VALUE:-phi-3-5-${HASH}}"
export WORKSPACE_MANIFEST="${WORKSPACE_MANIFEST:-/tmp/kaito-workspace-\
${HASH}.yaml}"
export WORKSPACE_MDOEL="${WORKSPACE_MODEL:-phi-3.5-mini-instruct}"
export CURL_POD_NAME="${CURL_POD_NAME:-curl-test-${HASH}}"
```

The `AZURE_VM_SIZE` determines the Azure VM SKU used for the inference
workload. Standard_NC6s_v3 provides a single NVIDIA V100 GPU suitable for
smaller models. Larger models may require NC24ads_A100_v4 or similar SKUs.

Before proceeding, ensure KAITO is properly installed on your cluster by
following the [Install KAITO On AKS](./Install_Kaito_On_AKS.md) guide.

Summary: Establishes workspace naming, model selection, and GPU instance
configuration for the deployment.

## Steps

Follow each step to create the workspace, monitor deployment progress, and
validate the inference endpoint. Review each outcome before continuing.

### Verify KAITO installation

Confirm the KAITO workspace controller is running and operational before
creating workspace resources.

```bash
kubectl get pods -n kaito-workspace
kubectl get crd workspaces.kaito.sh
```

Summary: KAITO controller pods are running and Workspace CRD is registered.

### Create Workspace manifest

Generate the Workspace custom resource manifest with the selected model and
GPU configuration.

```bash
cat > "${WORKSPACE_MANIFEST}" <<EOF
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: ${WORKSPACE_NAME}
  namespace: ${WORKSPACE_NAMESPACE}
resource:
  instanceType: "${AZURE_VM_SIZE}"
  labelSelector:
    matchLabels:
      ${WORKSPACE_LABEL_KEY}: ${WORKSPACE_LABEL_VALUE}
inference:
  preset:
    name: ${MODEL_PRESET}
EOF
cat "${WORKSPACE_MANIFEST}"
```

Summary: Workspace manifest created with model preset and GPU requirements.

### Apply Workspace resource

Deploy the Workspace custom resource to trigger KAITO provisioning and model
deployment.

```bash
kubectl apply -f "${WORKSPACE_MANIFEST}"
kubectl get workspace "${WORKSPACE_NAME}" -n "${WORKSPACE_NAMESPACE}"
```

Summary: Workspace resource created and KAITO reconciliation initiated.

### Monitor workspace provisioning

Track the workspace status until all components are ready. This includes GPU
node provisioning, model image pulling, and service deployment.

```bash
echo "Monitoring workspace ${WORKSPACE_NAME} provisioning..."
MAX_ATTEMPTS=120
ATTEMPT=0
while [ ${ATTEMPT} -lt ${MAX_ATTEMPTS} ]; do
  RESOURCE_READY=$(
    kubectl get workspace "${WORKSPACE_NAME}" \
      -n "${WORKSPACE_NAMESPACE}" \
      -o jsonpath='{.status.conditions[?(@.type=="ResourceReady")].status}' \
      2>/dev/null || echo "Unknown"
  )
  INFERENCE_READY=$(
    kubectl get workspace "${WORKSPACE_NAME}" \
      -n "${WORKSPACE_NAMESPACE}" \
      -o jsonpath='{.status.conditions[?(@.type=="InferenceReady")].status}' \
      2>/dev/null || echo "Unknown"
  )
  if [ "${INFERENCE_READY}" = "True" ]; then
    echo "Workspace provisioning completed successfully (inference ready)"
    break
  fi
  WORKSPACE_STATUS=$(
    kubectl get workspace "${WORKSPACE_NAME}" \
      -n "${WORKSPACE_NAMESPACE}" \
      -o jsonpath='{.status.conditions[?(@.type=="WorkspaceSucceeded")].status}' \
      2>/dev/null || echo "Unknown"
  )
  echo "Status - ResourceReady: ${RESOURCE_READY}, InferenceReady: \
${INFERENCE_READY}, WorkspaceSucceeded: ${WORKSPACE_STATUS} (attempt \
${ATTEMPT}/${MAX_ATTEMPTS})"
  sleep 10
  ATTEMPT=$((ATTEMPT + 1))
done
if [ ${ATTEMPT} -ge ${MAX_ATTEMPTS} ]; then
  echo "Timeout waiting for workspace provisioning" >&2
  kubectl describe workspace "${WORKSPACE_NAME}" \
    -n "${WORKSPACE_NAMESPACE}"
  exit 1
fi
```

Summary: Workspace provisioning completed with GPU nodes ready and inference
service deployed.

### Display workspace details

Show the final workspace status including instance type, readiness conditions,
and age.

```bash
kubectl get workspace "${WORKSPACE_NAME}" \
  -n "${WORKSPACE_NAMESPACE}" \
  -o wide
```

Summary: Workspace details displayed showing successful deployment.

### Verify GPU node provisioning

List the GPU nodes created by KAITO for this workspace.

```bash
kubectl get nodes \
  -l "${WORKSPACE_LABEL_KEY}=${WORKSPACE_LABEL_VALUE}" \
  -o wide
```

Summary: GPU nodes are provisioned and ready for inference workloads.

### Get inference service endpoint

Retrieve the cluster IP of the inference service endpoint.

```bash
SERVICE_NAME="${WORKSPACE_NAME}"
SERVICE_IP=$(
  kubectl get svc "${SERVICE_NAME}" \
    -n "${WORKSPACE_NAMESPACE}" \
    -o jsonpath='{.spec.clusterIP}'
)
if [ -z "${SERVICE_IP}" ]; then
  echo "Service ${SERVICE_NAME} not found in namespace \
${WORKSPACE_NAMESPACE}" >&2
  kubectl get svc -n "${WORKSPACE_NAMESPACE}"
  exit 1
fi
export SERVICE_IP
echo "Service endpoint: ${SERVICE_IP}"
kubectl get svc "${SERVICE_NAME}" -n "${WORKSPACE_NAMESPACE}"
```

Summary: Inference service endpoint retrieved and accessible within the
cluster.

### Test inference endpoint

Make a sample inference request to validate the model is serving predictions.

For safety we will ensure that there is no existing question pod in the cluster. In production you would likely use a pod thatcan be reused, but for now we will keep things simple.

```bash
kubectl delete pod question --ignore-not-found
```

Now we can start the pod and submit our question.

```bash
kubectl run question \
  --image=curlimages/curl \
  --restart=Never \
  -- \
  sh -c 'curl -sS -X POST "http://'"${SERVICE_IP}"'/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${WORKSPACE_MODEL}\",\"messages\":[{\"role\":\"system\",\"content\":\"You are a programmer answers questions in a direct and concise way.\"},{\"role\":\"user\",\"content\":\"What is Python?\"}],\"max_tokens\":200}"'
```

Now lets wait for the response to be completed, then output the answer.

```bash
for i in {1..20}; do
  phase=$(kubectl get pod question -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  if [ "$phase" = "Running" ] || [ "$phase" = "Succeeded" ] || [ "$phase" = "Failed" ]; then
    break
  fi
  sleep 1
done

kubectl logs question | jq -r '.choices[0].message.content'
```

Summary: Inference endpoint successfully processed the request and returned a
model response.

## Summary

You created a KAITO Workspace that automatically provisioned GPU nodes,
deployed the phi-3.5-mini-instruct model, and exposed an OpenAI-compatible
inference endpoint. The service is operational and ready to handle inference
requests from applications within the cluster.

Summary: AI inference service deployed successfully using KAITO with automatic
GPU provisioning and model management.

## Next Steps

Consider extending the deployment with one or more of the following paths.

1. Expose the inference service externally using an Ingress controller or Azure
   Load Balancer for access from outside the cluster.
2. Deploy additional models by creating new Workspace resources with different
   preset configurations.
3. Integrate the inference endpoint with your application using the OpenAI
   Python or JavaScript client libraries.
4. Configure horizontal pod autoscaling based on request load or GPU
   utilization metrics.
5. Set up monitoring and logging to track model performance, latency, and
   resource consumption.

Summary: Suggested next steps support production operationalization and
integration of the AI inference service.
