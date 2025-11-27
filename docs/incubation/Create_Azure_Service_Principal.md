# Create Azure Service Principal for AKS MCP

## Introduction

This executable guide creates an Azure service principal with appropriate
permissions for the AKS-MCP server to perform Azure Kubernetes Service
operations. The service principal receives Reader role assignment on the target
resource group, enabling read-only access to AKS cluster details and
diagnostic data.

The workflow validates Azure CLI authentication, creates the service principal,
assigns the necessary role, and exports environment variables that other
executable documents expect. All resource names stay parameterized so different
subscriptions and access levels can reuse the procedure.

Summary: Provides an end-to-end, variable-driven service principal creation
with credential export for AKS-MCP authentication.

## Prerequisites

Before starting, ensure Azure access with permissions to create service
principals and assign roles at the resource group level. The Azure CLI must be
authenticated to the target subscription.

- Azure CLI (`az`) with an authenticated session (`az login`)
- Permissions to create Azure AD applications and service principals
- Permissions to assign roles on the target resource group
- Optional: `jq` for parsing JSON responses

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v jq >/dev/null || echo "jq missing (optional)"
```

Summary: Azure CLI must be authenticated with sufficient privileges to manage
service principals and role assignments.

## Setting up the environment

Export the variables that control service principal naming, role assignment
scope, and credential storage. The `HASH` suffix ensures unique naming when
running the procedure multiple times. Resource group and AKS cluster names
should match the environment where AKS-MCP will be deployed.

```bash
export HASH=$(date -u +"%y%m%d%H%M")
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-mcp-rg}"
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-mcp-cluster}"
export SERVICE_PRINCIPAL_NAME="${SERVICE_PRINCIPAL_NAME:-aks-mcp-sp-${HASH}}"
export SERVICE_PRINCIPAL_ROLE="${SERVICE_PRINCIPAL_ROLE:-Reader}"
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
export AZURE_TENANT_ID="${AZURE_TENANT_ID:-}"
export AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"
export AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET:-}"
export CREDENTIAL_OUTPUT_FILE="${CREDENTIAL_OUTPUT_FILE:-/tmp/azure-sp-credentials-${HASH}.env}"
```

Summary: Variables establish naming conventions and role assignment scope for
the service principal creation workflow.

## Steps

Follow each step to create the service principal, assign permissions, and
export credentials. Review each command outcome before continuing to the next
step.

### Confirm Azure subscription and resource group

Verify the Azure CLI is authenticated and the target resource group exists.
Capture the subscription and tenant identifiers for service principal creation.

```bash
az account show --output table
export AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
export AZURE_TENANT_ID=$(az account show --query tenantId --output tsv)
echo "Subscription ID: ${AZURE_SUBSCRIPTION_ID}"
echo "Tenant ID: ${AZURE_TENANT_ID}"
az group show --name "${AZURE_RESOURCE_GROUP}" --output table
```

Summary: Azure subscription and tenant are identified, resource group existence
is confirmed.

### Create the service principal

Generate a new service principal with a client secret. The Azure CLI returns
the application ID and generated secret which must be captured for subsequent
authentication.

```bash
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "${SERVICE_PRINCIPAL_NAME}" \
  --role "${SERVICE_PRINCIPAL_ROLE}" \
  --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}" \
  --output json)
export AZURE_CLIENT_ID=$(echo "${SP_OUTPUT}" | jq -r '.appId')
export AZURE_CLIENT_SECRET=$(echo "${SP_OUTPUT}" | jq -r '.password')
echo "Service Principal Created"
echo "Client ID: ${AZURE_CLIENT_ID}"
echo "Client Secret: ${AZURE_CLIENT_SECRET:0:4}***"
```

Summary: Service principal exists with Reader role on the target resource
group. Application ID and secret are exported for authentication.

### Verify role assignment

Confirm the service principal has the expected role assignment on the resource
group. The assignment ensures AKS-MCP can query cluster details and diagnostic
information.

```bash
az role assignment list \
  --assignee "${AZURE_CLIENT_ID}" \
  --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}" \
  --output table
```

Summary: Role assignment is active and grants Reader permissions on the
resource group.

### Test service principal authentication

Validate the service principal credentials by performing a test login and
querying the AKS cluster. This confirms the credentials work before deploying
AKS-MCP.

```bash
az login --service-principal \
  -u "${AZURE_CLIENT_ID}" \
  -p "${AZURE_CLIENT_SECRET}" \
  --tenant "${AZURE_TENANT_ID}" \
  --output table
az account show --output table
az aks show \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --output table
az logout
az login
```

Summary: Service principal credentials authenticate successfully and can read
AKS cluster details. Original user session is restored.

### Export credentials to file

Write the service principal credentials to a file in shell variable export
format. This file can be sourced by other executable documents to populate the
required environment variables.

```bash
cat > "${CREDENTIAL_OUTPUT_FILE}" <<EOF
export AZURE_TENANT_ID="${AZURE_TENANT_ID}"
export AZURE_CLIENT_ID="${AZURE_CLIENT_ID}"
export AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET}"
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}"
EOF
chmod 600 "${CREDENTIAL_OUTPUT_FILE}"
echo "Credentials written to: ${CREDENTIAL_OUTPUT_FILE}"
echo "Source this file before running AKS-MCP deployment:"
echo "  source ${CREDENTIAL_OUTPUT_FILE}"
```

Summary: Credentials are persisted to a secure file that can be sourced to set
environment variables for subsequent workflows.

### Display credential export commands

Print the export statements to the console for manual copy-paste when file
sourcing is not available.

```bash
echo ""
echo "Alternatively, copy and paste these export statements:"
echo ""
cat "${CREDENTIAL_OUTPUT_FILE}"
echo ""
```

Summary: Credential export statements are displayed for manual environment
setup.

## Summary

You verified Azure access, created a service principal with Reader permissions
on the target resource group, validated the credentials through test
authentication, and exported the credential variables to a file and console
output.

The exported environment variables (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`,
`AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID`) are required by AKS-MCP for
Azure CLI authentication. Source the credential file or set these variables
before proceeding with AKS-MCP deployment.

Summary: Service principal is ready for AKS-MCP authentication with credentials
available for export.

## Next Steps

Source the credential file and proceed with AKS-MCP deployment.

1. Source the credential file to populate environment variables in the current
   shell session: `source ${CREDENTIAL_OUTPUT_FILE}`.
2. Run the [AKS-MCP deployment guide](AKS_MCP_On_AKS.md) to install the server
   on your AKS cluster using the service principal credentials.
3. For production use, consider storing credentials in Azure Key Vault or using
   managed identity instead of service principal secrets.

Summary: Credential file is ready to source before running AKS-MCP deployment
workflows.
