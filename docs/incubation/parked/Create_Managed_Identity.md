# Create Azure Managed Identity

## Introduction

This document guides you through creating an Azure User-Assigned Managed
Identity and assigning it appropriate permissions on a resource group. Managed
identities provide a secure way for Azure resources to authenticate with Azure
services without storing credentials in code or configuration files.

This identity can be used across multiple scenarios including AKS workload
identity, GPU provisioning, and other Azure service integrations.

**Permission Options:**

1. **Virtual Machine Contributor** (default): Built-in role with permissions to
   manage virtual machines and scale sets. Sufficient for most GPU provisioning
   scenarios.
2. **Custom Role** (optional): Minimal permissions for GPU node provisioning
   only. Use this if organizational policies restrict broader permissions. Set
   `USE_CUSTOM_ROLE=true` to enable.

The custom role includes only these actions:

- Read/write/delete virtual machine scale sets
- Read/write network interfaces
- Join virtual network subnets
- Read resource groups

## Prerequisites

Before starting, ensure you have the following:

- Azure CLI installed and authenticated (`az login`)
- Sufficient permissions to create managed identities and assign roles
- An existing Azure resource group (or permissions to create one)
- Permission to create custom role definitions (if using custom role option)

## Setting up the environment

Define the environment variables used throughout this document. Each variable
has a sensible default value.

```bash
export HASH="${HASH:-$(
  date -u +"%y%m%d%H%M"
)}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg_shared_${HASH}}"
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"
export MANAGED_IDENTITY_NAME="${MANAGED_IDENTITY_NAME:-mi-shared_${HASH}}"
export TARGET_RESOURCE_GROUP="${TARGET_RESOURCE_GROUP:-${AZURE_RESOURCE_GROUP}}"
export ROLE_NAME="${ROLE_NAME:-Virtual Machine Contributor}"
export USE_CUSTOM_ROLE="${USE_CUSTOM_ROLE:-false}"
export CUSTOM_ROLE_NAME="${CUSTOM_ROLE_NAME:-GPU Provisioner Role}"
```

Summary: Environment variables are set with defaults for managed identity
creation and role assignment.

## Steps

### Create resource group

Create the Azure resource group that will contain the managed identity
resource.

```bash
if az group show --name "${AZURE_RESOURCE_GROUP}" &>/dev/null; then
  echo "Resource group ${AZURE_RESOURCE_GROUP} already exists"
else
  az group create \
    --name "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_LOCATION}"
  echo "Created resource group ${AZURE_RESOURCE_GROUP}"
fi
```

Summary: Resource group is created if it does not already exist, providing an
idempotent operation.

### Create managed identity

Create the user-assigned managed identity in the resource group.

```bash
if az identity show \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${MANAGED_IDENTITY_NAME}" &>/dev/null; then
  echo "Managed identity ${MANAGED_IDENTITY_NAME} already exists"
else
  az identity create \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${MANAGED_IDENTITY_NAME}" \
    --location "${AZURE_LOCATION}"
  echo "Created managed identity ${MANAGED_IDENTITY_NAME}"
fi
```

Summary: Managed identity is created in the specified resource group, or
reused if it already exists.

### Retrieve managed identity details

Export the managed identity's client ID, principal ID, and resource ID for use
in subsequent operations.

```bash
export MANAGED_IDENTITY_CLIENT_ID=$(
  az identity show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${MANAGED_IDENTITY_NAME}" \
    --query clientId \
    --output tsv
)
export MANAGED_IDENTITY_PRINCIPAL_ID=$(
  az identity show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${MANAGED_IDENTITY_NAME}" \
    --query principalId \
    --output tsv
)
export MANAGED_IDENTITY_RESOURCE_ID=$(
  az identity show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${MANAGED_IDENTITY_NAME}" \
    --query id \
    --output tsv
)
echo "Client ID: ${MANAGED_IDENTITY_CLIENT_ID}"
echo "Principal ID: ${MANAGED_IDENTITY_PRINCIPAL_ID}"
echo "Resource ID: ${MANAGED_IDENTITY_RESOURCE_ID}"
```

Summary: Managed identity details are retrieved and exported as environment
variables for use in role assignments and configuration.

### Retrieve target resource group ID

Get the resource ID of the target resource group where the managed identity
will be granted permissions.

```bash
export TARGET_RESOURCE_GROUP_ID=$(
  az group show \
    --name "${TARGET_RESOURCE_GROUP}" \
    --query id \
    --output tsv
)
echo "Target resource group ID: ${TARGET_RESOURCE_GROUP_ID}"
```

Summary: Target resource group ID is retrieved for scoping the role assignment.

### Create custom role definition (optional)

If using a custom role with minimal permissions, create the role definition.
This step is skipped if USE_CUSTOM_ROLE is false.

```bash
if [ "${USE_CUSTOM_ROLE}" = "true" ]; then
  CUSTOM_ROLE_DEF_FILE="/tmp/gpu-provisioner-role_${HASH}.json"
  SUBSCRIPTION_ID=$(az account show --query id --output tsv)
  cat > "${CUSTOM_ROLE_DEF_FILE}" <<EOF
{
  "Name": "${CUSTOM_ROLE_NAME}",
  "Description": "Minimal permissions for GPU node provisioning",
  "Actions": [
    "Microsoft.Compute/virtualMachineScaleSets/read",
    "Microsoft.Compute/virtualMachineScaleSets/write",
    "Microsoft.Compute/virtualMachineScaleSets/delete",
    "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read",
    "Microsoft.Network/networkInterfaces/read",
    "Microsoft.Network/networkInterfaces/write",
    "Microsoft.Network/virtualNetworks/subnets/join/action",
    "Microsoft.Resources/subscriptions/resourceGroups/read"
  ],
  "NotActions": [],
  "AssignableScopes": [
    "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${TARGET_RESOURCE_GROUP}"
  ]
}
EOF
  if az role definition list --name "${CUSTOM_ROLE_NAME}" \
    --query "[0].name" --output tsv &>/dev/null; then
    echo "Custom role ${CUSTOM_ROLE_NAME} already exists"
  else
    az role definition create --role-definition "${CUSTOM_ROLE_DEF_FILE}"
    echo "Created custom role ${CUSTOM_ROLE_NAME}"
  fi
  ROLE_NAME="${CUSTOM_ROLE_NAME}"
  rm -f "${CUSTOM_ROLE_DEF_FILE}"
fi
```

Summary: Custom role with minimal GPU provisioning permissions is created if
enabled, otherwise the standard role is used.

### Assign role to managed identity

Assign the specified role to the managed identity on the target resource group
scope.

```bash
EXISTING_ASSIGNMENT=$(
  az role assignment list \
    --assignee "${MANAGED_IDENTITY_PRINCIPAL_ID}" \
    --role "${ROLE_NAME}" \
    --scope "${TARGET_RESOURCE_GROUP_ID}" \
    --query "[0].id" \
    --output tsv
)
if [ -n "${EXISTING_ASSIGNMENT}" ]; then
  echo "Role assignment already exists: ${EXISTING_ASSIGNMENT}"
else
  az role assignment create \
    --assignee "${MANAGED_IDENTITY_PRINCIPAL_ID}" \
    --role "${ROLE_NAME}" \
    --scope "${TARGET_RESOURCE_GROUP_ID}"
  echo "Assigned ${ROLE_NAME} role to ${MANAGED_IDENTITY_NAME}"
fi
```

Summary: Managed identity is granted the specified role permissions on the
target resource group, allowing it to manage required resources within that
scope.

### Verify role assignment

Confirm that the role assignment was created successfully by listing all role
assignments for the managed identity.

```bash
az role assignment list \
  --assignee "${MANAGED_IDENTITY_PRINCIPAL_ID}" \
  --all \
  --query "[].{Role:roleDefinitionName,Scope:scope}" \
  --output table
```

Summary: Role assignments are displayed showing the managed identity has the
expected permissions.

### Save managed identity details

Write the managed identity details to a file for reference in other
executable documents.

```bash
IDENTITY_INFO_FILE="${IDENTITY_INFO_FILE:-managed-identity-info_${HASH}.env}"
cat > "${IDENTITY_INFO_FILE}" <<EOF
# Managed Identity Details (Generated $(date -u +"%Y-%m-%d %H:%M:%S UTC"))
export MANAGED_IDENTITY_NAME="${MANAGED_IDENTITY_NAME}"
export MANAGED_IDENTITY_CLIENT_ID="${MANAGED_IDENTITY_CLIENT_ID}"
export MANAGED_IDENTITY_PRINCIPAL_ID="${MANAGED_IDENTITY_PRINCIPAL_ID}"
export MANAGED_IDENTITY_RESOURCE_ID="${MANAGED_IDENTITY_RESOURCE_ID}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}"
export TARGET_RESOURCE_GROUP="${TARGET_RESOURCE_GROUP}"
export AZURE_LOCATION="${AZURE_LOCATION}"
EOF
echo "Saved managed identity details to ${IDENTITY_INFO_FILE}"
echo "Source this file in other scripts: source ${IDENTITY_INFO_FILE}"
```

Summary: Managed identity configuration is saved to a file that can be sourced
by other executable documents.

## Verification

Use this section for /execute style automated validation. If all checks pass,
the document does not need to be re-run.

```bash
# Ensure baseline variables (do not mutate existing values if already set)
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg_shared_${HASH}}"
export MANAGED_IDENTITY_NAME="${MANAGED_IDENTITY_NAME:-mi-shared_${HASH}}"
export TARGET_RESOURCE_GROUP="${TARGET_RESOURCE_GROUP:-${AZURE_RESOURCE_GROUP}}"
export ROLE_NAME="${ROLE_NAME:-Virtual Machine Contributor}"
export USE_CUSTOM_ROLE="${USE_CUSTOM_ROLE:-false}"
export CUSTOM_ROLE_NAME="${CUSTOM_ROLE_NAME:-GPU Provisioner Role}"

FAILED=0

echo "[VERIFY] Identity exists"
az identity show \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${MANAGED_IDENTITY_NAME}" \
  --query "{clientId:clientId,principalId:principalId}" -o table || {
  echo "[ERROR] Managed identity missing" >&2; FAILED=1; }

echo "[VERIFY] Role definition (custom only)"
if [ "${USE_CUSTOM_ROLE}" = "true" ]; then
  az role definition list --name "${CUSTOM_ROLE_NAME}" \
    --query "[0].permissions[0].actions" -o table || {
    echo "[ERROR] Custom role definition missing" >&2; FAILED=1; }
else
  echo "[SKIP] Custom role not in use"
fi

echo "[VERIFY] Role assignment"
PRINCIPAL_ID=$(az identity show --resource-group "${AZURE_RESOURCE_GROUP}" --name "${MANAGED_IDENTITY_NAME}" --query principalId -o tsv)
TARGET_RESOURCE_GROUP_ID=$(az group show --name "${TARGET_RESOURCE_GROUP}" --query id -o tsv)
ASSIGNMENT_COUNT=$(az role assignment list --assignee "${PRINCIPAL_ID}" --scope "${TARGET_RESOURCE_GROUP_ID}" --query "length(@)" -o tsv || echo 0)
if [ "${ASSIGNMENT_COUNT}" = "0" ]; then
  echo "[ERROR] No role assignment found at scope ${TARGET_RESOURCE_GROUP_ID}" >&2; FAILED=1
else
  az role assignment list --assignee "${PRINCIPAL_ID}" --scope "${TARGET_RESOURCE_GROUP_ID}" --query "[].{Role:roleDefinitionName,Scope:scope}" -o table
fi

echo "[VERIFY] Environment file (optional)"
IDENTITY_INFO_FILE="managed-identity-info_${HASH}.env"
if [ -f "${IDENTITY_INFO_FILE}" ]; then
  echo "[OK] Found ${IDENTITY_INFO_FILE}"; grep MANAGED_IDENTITY_CLIENT_ID "${IDENTITY_INFO_FILE}" || true
else
  echo "[WARN] Env file not found (will be created during execution)"
fi

if [ "${FAILED}" -ne 0 ]; then
  echo "[RESULT] Verification FAILED" >&2; exit 1
else
  echo "[RESULT] Verification PASSED"
fi
```

Summary: Automated verification checks identity existence, optional custom role, role assignment, and env file presence.

## Summary

You have created an Azure User-Assigned Managed Identity and granted it either
the built-in Virtual Machine Contributor role or (optionally) a custom minimal
GPU provisioning role scoped to the target resource group. Identity metadata
can be persisted to an env file for reuse.

This managed identity can be used for:

- AKS workload identity federation
- GPU provisioner authentication (with minimal or VM Contributor scope)
- Secure Azure API access without stored secrets
- Scoped resource management operations

Least-privilege guidance: Prefer the custom role (`USE_CUSTOM_ROLE=true`) when
organizational policy restricts broad roles; fall back to Virtual Machine
Contributor if custom role creation is disallowed.

Summary: Managed identity and role assignment are established and verifiable.

## Next Steps

1. Configure AKS workload identity to use this managed identity
2. Set up federated credentials for Kubernetes service accounts
3. If using custom role, verify permissions are sufficient for your use case
4. Assign additional role scopes as needed for specific use cases
5. Source the saved environment file in other executable documents using:
   `source managed-identity-info_${HASH}.env`

Summary: The managed identity foundation is in place for building secure Azure
integrations with minimal required permissions.
