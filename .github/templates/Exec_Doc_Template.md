# <TITLE_PLACEHOLDER>

## Introduction

This executable document describes an example workflow for <HIGH_LEVEL_GOAL>.
It demonstrates how to structure environment-driven, idempotent procedures
that can be safely re-run and validated.

Summary:

- High-level overview of what this executable document achieves.

## Prerequisites

Before starting, ensure you have the required tools installed, environment
access configured, and any dependent resources created.

### Required CLI tools

The following CLI tools are required to complete this example workflow:

- Example CLI (`example`) with an authenticated session
- `kubectl` (if interacting with Kubernetes)
- `jq` for inspecting JSON payloads during validation (optional)

The following commands validate these dependencies and install or update
them where appropriate. Replace these with the actual tools for your
scenario.

```bash
MIN_EXAMPLE_VERSION="1.0.0"

version_ge() {
  # returns 0 (true) if $1 >= $2
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

if ! command -v example >/dev/null; then
  echo "Example CLI missing, installing..."
  # TODO: Add installation command for your CLI
  # curl -sL https://example.com/install.sh | bash
else
  echo "Checking Example CLI version..."
  example_version=$(example --version 2>/dev/null | awk 'NR==1 {print $NF}')
  echo "Found example ${example_version}"
  if ! version_ge "${example_version}" "${MIN_EXAMPLE_VERSION}"; then
    echo "Example CLI version is below ${MIN_EXAMPLE_VERSION}, upgrading..."
    # TODO: Add upgrade command for your CLI
  fi
fi

command -v kubectl >/dev/null || echo "kubectl missing (optional)"
command -v jq >/dev/null || echo "jq missing (optional)"
```

<!-- expected_similarity="Found example.*" -->

```text
Checking Example CLI version...
Found example 1.2.3
```

### Deployment Configuration

To facilitate reuse, export environment variables that define your deployment
parameters and validation helpers. If a variable already has a value, that
value will be preserved.

Unique names append a timestamp-based `HASH` suffix to prevent collisions.

```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"
```

Define core Azure or platform context variables (update naming to match your
scenario). All variables must follow the ALL_CAPS underscore convention.

```bash
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-example-rg_${HASH}}"
```

Define workload- or application-specific variables. Adjust names and defaults
to your use case.

```bash
export APP_NAMESPACE="${APP_NAMESPACE:-example-namespace}"
export APP_NAME="${APP_NAME:-example-app}"
export APP_CONFIG_VALUE="${APP_CONFIG_VALUE:-default-config}"
```

Summary:

- Established reproducible defaults using environment variables.
- Ensured tooling and platform context are configured.
- Prepared application-specific configuration values for later steps.

## Steps

Follow each step to perform the example workflow. Replace each section with
commands appropriate to your scenario, keeping them idempotent and
variable-driven.

### Validate access and context

Verify platform access (for example Azure subscription and Kubernetes
cluster) and confirm that credentials are valid. Adjust these commands to
match your platform.

```bash
az account show --output table || echo "az account show failed"
# If using Kubernetes:
# kubectl get nodes || echo "kubectl get nodes failed"
```

Summary:

- Validates that you can reach the target platform.

### Create or update core resources

Create or update core resources required by this workflow, such as
resource groups, clusters, or namespaces. Ensure commands are idempotent
by checking for existing resources before creating new ones.

```bash
echo "Ensuring resource group ${AZURE_RESOURCE_GROUP} exists in ${AZURE_LOCATION}..."
az group create \
  --name "${AZURE_RESOURCE_GROUP}" \
  --location "${AZURE_LOCATION}" \
  --output table
```

<!-- expected_similarity=".*Succeeded.*" -->

```text
Location    Name                    ProvisioningState
----------  ----------------------  -------------------
eastus2     example-rg_2511132113   Succeeded
```

Summary: Core resources are present and ready for application deployment.

### Deploy application components

Deploy or configure the application or service components. This might
involve Helm charts, `kubectl` manifests, or other deployment tools.

```bash
echo "Deploying ${APP_NAME} into namespace ${APP_NAMESPACE}..."
# Example placeholder for Kubernetes-based deployment
kubectl create namespace "${APP_NAMESPACE}" 2>/dev/null || \
  echo "Namespace ${APP_NAMESPACE} already exists"

kubectl apply -n "${APP_NAMESPACE}" -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}-config
  namespace: ${APP_NAMESPACE}
data:
  example-key: "${APP_CONFIG_VALUE}"
EOF
```

<!-- expected_similarity=".*configmap.*(created|configured).*" -->

```text
deployment.apps/example-app created
configmap/example-app-config created
```

Summary:

- Application components are deployed or updated using manifests
  and configuration driven by environment variables.

### Validate application behavior

Validate that the application or service is running and behaving as
expected. Replace these checks with ones appropriate to your workload.

```bash
echo "Validating application components in namespace ${APP_NAMESPACE}..."
# Example placeholder for validation logic
kubectl get configmap "${APP_NAME}-config" -n "${APP_NAMESPACE}" -o yaml
```

<!-- expected_similarity=".*example-key:.*" -->

```text
apiVersion: v1
data:
  example-key: default-config
kind: ConfigMap
metadata:
  name: example-app-config
  namespace: example-namespace
```

Summary:

- Confirms application components are present and configured
  according to the expected values.

## Verification

Add verification logic to determine whether the workflow has already been
successfully executed. Verification steps must only read state and must not
mutate any resources. If verification passes, the rest of the document can
be safely skipped.

```bash
echo "=== Checking example resource group ==="
RG_STATE=$(az group show \
  --name "${AZURE_RESOURCE_GROUP}" \
  --query "properties.provisioningState" -o tsv 2>/dev/null || echo "NotFound")

if [ "${RG_STATE}" != "Succeeded" ]; then
  echo "FAIL: Resource group ${AZURE_RESOURCE_GROUP} not found or not ready"
  exit 1
fi

echo "=== Checking example application namespace and config ==="
NS_EXISTS=$(kubectl get namespace "${APP_NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo 0)

if [ "${NS_EXISTS}" -lt 1 ]; then
  echo "FAIL: Namespace ${APP_NAMESPACE} not found"
  exit 1
fi

CONFIG_VALUE=$(kubectl get configmap "${APP_NAME}-config" -n "${APP_NAMESPACE}" \
  -o jsonpath='{.data.example-key}' 2>/dev/null || echo "")

if [ -z "${CONFIG_VALUE}" ]; then
  echo "FAIL: ConfigMap ${APP_NAME}-config missing or misconfigured"
  exit 1
fi

echo "PASS: Example workflow resources are present and correctly configured"
exit 0
```

<!-- expected_similarity="PASS: Example workflow resources.*" -->

```text
=== Checking example resource group ===
=== Checking example application namespace and config ===
PASS: Example workflow resources are present and correctly configured
```

### Environment Variables

For convenience, dump key environment variables to the console for
inspection. Extend this list as needed, following the ALL_CAPS naming
convention.

```bash
VARS=(
  HASH
  AZURE_
  APP_
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

<!-- expected_similarity="=== Variables starting with HASH ===" -->

```text
=== Variables starting with HASH ===
HASH=2511132113

=== Variables starting with AZURE_ ===
AZURE_SUBSCRIPTION_ID=00000000-0000-0000-0000-000000000000
AZURE_LOCATION=eastus2
AZURE_RESOURCE_GROUP=example-rg_2511132113

=== Variables starting with APP_ ===
APP_NAMESPACE=example-namespace
APP_NAME=example-app
APP_CONFIG_VALUE=default-config
```

Summary:

- Verification checks confirm that the example workflow resources
  are deployed and correctly configured.
- Dump config environment variables to the console ouput

## Summary

This section summarizes the actions performed by the executable document
and the resulting system state. Replace this text with a concise summary of
your actual workflow.

## Next Steps

Introduce follow-on executable documents or related workflows that build on
this one. Replace the following bullets with links into your own docs.

- [Example Follow-on Workflow 1](../path/to/Follow_On_Workflow_1.md)
- [Example Follow-on Workflow 2](../path/to/Follow_On_Workflow_2.md)
- [Example Cleanup Workflow](../path/to/Cleanup_Workflow.md)
