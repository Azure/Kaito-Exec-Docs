# Deploy Additional KAITO Model Workspaces

## Introduction

This executable document shows how to deploy additional KAITO
workspaces for different models on an existing AKS cluster. It follows
the same pattern as the initial workspace but customizes instance types
and presets.

Summary: Adds more model workspaces to an existing KAITO deployment.

## Prerequisites

You must have KAITO installed and at least one workspace already
running.

- Completed [Installing Kaito on Azure Kubernetes Service (AKS)](Install_Kaito_On_AKS.md)

```bash
command -v kubectl >/dev/null || echo "kubectl missing"
```

Summary: Confirms KAITO is installed and kubectl is available.

## Setting up the environment

Define base variables for workspace naming and GPU instance type.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"  # YYMMDDHHMM stamp
export WORKSPACE_NAMESPACE="${WORKSPACE_NAMESPACE:-default}"
export GPU_INSTANCE_TYPE="${GPU_INSTANCE_TYPE:-Standard_NC12s_v3}"

VARS=(
  HASH
  WORKSPACE_NAMESPACE
  GPU_INSTANCE_TYPE
)

for v in "${VARS[@]}"; do
  printf "%s=%s\n" "$v" "${!v}"
done
```

Summary: Establishes namespace and GPU VM SKU for new workspaces.

## Steps

### Create workspace manifest for an additional model

Generate a workspace manifest for an example model (e.g., LLaMA) and
apply it.

```bash
export WORKSPACE_NAME="${WORKSPACE_NAME:-workspace-llama-2-7b-${HASH}}"
export WORKSPACE_MANIFEST="${WORKSPACE_MANIFEST:-/tmp/kaito-workspace-llama-${HASH}.yaml}"

cat > "${WORKSPACE_MANIFEST}" <<EOF
apiVersion: kaito.sh/v1beta1
kind: Workspace
metadata:
  name: ${WORKSPACE_NAME}
  namespace: ${WORKSPACE_NAMESPACE}
resource:
  instanceType: "${GPU_INSTANCE_TYPE}"
  labelSelector:
    matchLabels:
      apps: llama
inference:
  preset:
    name: llama-2-7b
EOF

kubectl apply -f "${WORKSPACE_MANIFEST}"
kubectl get workspace "${WORKSPACE_NAME}" -n "${WORKSPACE_NAMESPACE}"
```

Summary: Creates and applies a new workspace for an additional model.

## Verification

Check that the new workspace moves to a succeeded state.

```bash
echo "Waiting for workspace ${WORKSPACE_NAME} to become ready..."
for i in {1..60}; do
  STATUS=$(kubectl get workspace "${WORKSPACE_NAME}" -n "${WORKSPACE_NAMESPACE}" \
    -o jsonpath='{.status.conditions[?(@.type=="WorkspaceSucceeded")].status}' 2>/dev/null || echo "Unknown")
  if [ "${STATUS}" = "True" ]; then
    echo "Workspace ${WORKSPACE_NAME} is ready."
    break
  fi
  echo "Attempt $i/60: status=${STATUS}"
  sleep 10
done

kubectl get workspace "${WORKSPACE_NAME}" -n "${WORKSPACE_NAMESPACE}"
```

Summary: Confirms the additional workspace has successfully provisioned
GPU nodes and model deployment.

## Summary

You created and verified an additional KAITO workspace for a new model,
reusing the same deployment pattern as the initial workspace.

Summary: Extends KAITO with more model workspaces sharing the cluster.

## Next Steps

- Add service-level tests or RAG layers on top of the new workspace.
- Adjust GPU instance types and presets to match model requirements.
