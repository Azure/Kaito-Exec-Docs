# Create Azure Resource Group with Terraform

## Introduction

This executable document creates an Azure Resource Group using Terraform
infrastructure-as-code. Resource groups are containers that hold related Azure
resources and are a prerequisite for deploying AKS clusters, storage accounts,
and other Azure services.

This guide demonstrates Terraform's idempotent behavior: running `terraform apply`
multiple times with the same configuration makes changes only on the first run.

Summary:

- Creates a single Azure Resource Group
- Demonstrates Terraform's declarative approach and idempotency
- Provides a reusable foundation for other Azure infrastructure
- Can be used as a dependency for AKS, ACR, and other Azure services

## Prerequisites

The following tooling and account access are required before running this guide.
Ensure you are authenticated to Azure using `az login` and have sufficient
permissions to create resource groups.

- Azure subscription with Owner or Contributor rights
- Azure CLI (`az`) authenticated
- Terraform >= 1.5.0 installed and in PATH

Check required CLI tools are available:

```bash
command -v az >/dev/null && echo "Azure CLI: OK" || echo "Azure CLI missing"
command -v terraform >/dev/null && echo "Terraform: OK" || echo "Terraform missing"
```

<!-- expected_similarity="OK" -->

```text
Azure CLI: OK
Terraform: OK
```

Verify Terraform version:

```bash
terraform version
```

<!-- expected_similarity="Terraform" -->

```text
Terraform v1.5.0
```

Check Azure authentication:

```bash
az account show
```

<!-- expected_similarity="\"id\":" -->

```text
{
  "id": "00000000-0000-0000-0000-000000000000",
  "name": "Azure Subscription"
}
```

Summary:

- Confirms necessary CLI tooling and Azure access are in place.
- Validates Terraform installation meets minimum version requirements.

## Configuration

### Navigate to Terraform directory

All Terraform configuration files are located in `docs/terraform/Create_Resource_Group`.
Navigate to this directory to execute Terraform commands.

```bash
cd docs/terraform/Create_Resource_Group
```

### Configure Terraform variables

Create a `terraform.tfvars` file from the example template. This file contains
your Azure subscription ID and optional overrides for resource group naming
and regional placement.

```bash
if [ ! -f terraform.tfvars ]; then
  cp terraform.tfvars.example terraform.tfvars
  echo "Created terraform.tfvars - please edit with your Azure subscription ID"
else
  echo "terraform.tfvars already exists"
fi
```

Edit `terraform.tfvars` and set your Azure subscription ID:

```bash
# Get your Azure subscription ID
AZURE_SUB_ID=$(az account show --query id -o tsv)
echo "Your Azure subscription ID: ${AZURE_SUB_ID}"

# Update terraform.tfvars with your subscription ID (if not already set)
if ! grep -q "^azure_subscription_id\s*=\s*\"[^\"]*\"" terraform.tfvars 2>/dev/null; then
  sed -i "s/azure_subscription_id = \"00000000-0000-0000-0000-000000000000\"/azure_subscription_id = \"${AZURE_SUB_ID}\"/" terraform.tfvars
  echo "Updated terraform.tfvars with your subscription ID"
fi
```

Review and customize additional variables in `terraform.tfvars` as needed:

```bash
cat terraform.tfvars
```

Summary:

- Terraform variables configured with Azure subscription and naming parameters.
- Default location is eastus2, customizable via terraform.tfvars.
- Resource group name includes unique hash by default.

## Terraform Infrastructure Files

The Terraform configuration uses multiple files for clarity:

- **providers.tf** - Azure provider configuration and version constraints (provided)
- **variables.tf** - Input variables and default values (provided)
- **resource_group.tf** - Resource group definition (you'll create this)
- **outputs.tf** - Output values for downstream use (provided)
- **terraform.tfvars** - Your customized variable values (you'll create this)
- **.gitignore** - Excludes state files and sensitive data (provided)

Supporting reference file:
- **resource_group.tf.example** - Example resource group configuration

You can review these files to understand the infrastructure:

```bash
# List Terraform configuration files
ls -la *.tf *.tf.example *.tfvars* .gitignore 2>/dev/null
```

Summary:

- Foundation files (providers, variables, outputs) are provided and ready.
- You'll create resource_group.tf following the guide.
- Example file available for quick-start or reference.

## Steps

Execute each step sequentially to experience Terraform's idempotent workflow.

### Check Azure subscription context

Verify the active Azure subscription and ensure required resource providers
are registered.

```bash
az account show --query id -o tsv
az provider register --namespace Microsoft.Resources
```

Summary:

- Azure subscription context confirmed and required providers registered.

### Initialize Terraform

Initialize the Terraform working directory. This downloads the Azure provider
and prepares the backend for state management.

```bash
terraform init
```

This command:
- Downloads required provider plugins (azurerm)
- Initializes backend for state storage
- Creates `.terraform/` directory (git-ignored)
- Creates `.terraform.lock.hcl` dependency lock file

Summary:

- Terraform initialized and ready to plan infrastructure changes.

## Building the Resource Group

Now you'll create the `resource_group.tf` file that defines your Azure
Resource Group.

### Create Resource Group Configuration

Create the `resource_group.tf` file with the resource group definition:

```bash
cat > resource_group.tf << 'EOF'
# Azure Resource Group
# Container for all Azure resources in this deployment

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.azure_location
  
  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Hash        = local.computed_hash
  }
}
EOF
```

Alternatively, copy the example file:

```bash
cp resource_group.tf.example resource_group.tf
```

Summary:

- Created resource_group.tf defining a single Azure resource group.
- Resource name computed from variables (includes unique hash).
- Tags added for management and cost tracking.

### Review execution plan

Generate and review a Terraform execution plan. This shows what resources will
be created without making any actual changes to your infrastructure.

```bash
terraform plan
```

Expected output shows:
- `+` prefix indicates resources to be **created**
- `azurerm_resource_group.main` will be created
- Plan shows 1 resource to add, 0 to change, 0 to destroy

Key attributes to review:
- `name` - The computed resource group name
- `location` - Your configured Azure region
- `tags` - Management metadata

Summary:

- Terraform execution plan shows exactly what will be created.
- No changes made yet - plan is a preview only.

### Apply Terraform configuration

Execute the planned infrastructure changes. Terraform will create the resource
group in Azure.

```bash
terraform apply
```

Type `yes` when prompted to confirm the action.

Expected output:
- Progress indicator as resource is created
- Final summary: "Apply complete! Resources: 1 added, 0 changed, 0 destroyed"
- Output values displayed (resource group name, location, etc.)

Expected duration: 10-15 seconds for resource group creation.

Summary:

- Resource group created successfully in Azure.
- Terraform state file created to track the resource.

### Demonstrate Idempotency

A key feature of Terraform is idempotency: running the same configuration
multiple times produces the same result. Let's verify this behavior.

Run `terraform apply` again without making any changes:

```bash
terraform apply
```

Expected output:

<!-- expected_similarity="No changes" -->

```text
No changes. Your infrastructure matches the configuration.
```

This demonstrates that Terraform:
- Compares desired state (configuration) with actual state (Azure)
- Detects no differences
- Makes no API calls to modify resources

**What Terraform checked:**
- Resource group name matches configuration
- Location matches configuration
- Tags match configuration

Try running apply a third time to further confirm idempotent behavior:

```bash
terraform apply
```

Again, you'll see "No changes" confirming that infrastructure state is stable.

Summary:

- Terraform's idempotent behavior verified.
- Running apply multiple times is safe - no unwanted changes occur.
- Infrastructure matches configuration perfectly.

### Review Terraform outputs

Display Terraform output values that provide resource group details for use
in downstream configurations.

```bash
terraform output
```

Key outputs include:
- `resource_group_name` - Name of the created resource group
- `resource_group_location` - Azure region where the resource group exists
- `resource_group_id` - Full Azure resource ID
- `computed_hash` - The hash value used in resource naming

You can reference these outputs programmatically:

```bash
# Get resource group name for use in scripts
RG_NAME=$(terraform output -raw resource_group_name)
echo "Resource Group: ${RG_NAME}"

# Get location
RG_LOCATION=$(terraform output -raw resource_group_location)
echo "Location: ${RG_LOCATION}"
```

Summary:

- Terraform outputs provide key resource information.
- Outputs can be consumed by other Terraform configurations or scripts.

## Verification

Confirm the resource group exists and is correctly configured.

### Verify with Terraform

Check Terraform state to confirm the resource is tracked:

```bash
# List managed resources
terraform state list

# Show detailed resource information
terraform state show azurerm_resource_group.main
```

Summary:

- Terraform state confirms resource is tracked and managed.

### Verify with Azure CLI

Query Azure directly to confirm resource group exists:

```bash
RG_NAME=$(terraform output -raw resource_group_name)

az group show \
  --name "${RG_NAME}" \
  --query "{name:name,location:location,provisioningState:provisioningState}" \
  --output table
```

Expected output showing resource group in `Succeeded` state.

List tags applied to the resource group:

```bash
az group show \
  --name "${RG_NAME}" \
  --query "tags" \
  --output json
```

Summary:

- Azure confirms resource group exists and is properly configured.
- Tags applied correctly for management.

## Making Changes

### Modifying the resource group

To change resource group configuration (e.g., update tags):

1. Edit `resource_group.tf` with desired changes
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

Example - add a new tag:

```bash
# Edit resource_group.tf to add a new tag
# For example, add: Project = "MCPaaS"
# Then preview and apply
terraform plan
terraform apply
```

Terraform will show:
- `azurerm_resource_group.main` - **will be updated in-place**
- Only the `tags` attribute shows changes
- Name and location remain unchanged

**Demonstrate idempotency after the change:**

```bash
terraform apply
```

Output shows no changes again - the updated infrastructure now matches the
new configuration.

Summary:

- Changes are declarative: update configuration, Terraform handles the rest.
- Plan shows exactly what will change before applying.
- Terraform minimizes changes: only modified attributes are updated.

### Limitations

Note that some attributes cannot be changed after creation:
- **location** - Cannot be changed (would require destroy and recreate)
- **name** - Cannot be changed (would require destroy and recreate)

For these attributes, changing the value will cause Terraform to destroy the
old resource group and create a new one. This would delete all resources
inside the resource group.

## Using This Resource Group in Other Configurations

This resource group can be used as a foundation for other Terraform
configurations (e.g., AKS clusters, storage accounts).

### Option 1: Shared State (Same Workspace)

Deploy other resources in the same Terraform workspace:

```bash
# In the same directory, create additional .tf files
# They will automatically share the same state and can reference this resource

# Example in aks.tf:
# resource "azurerm_kubernetes_cluster" "aks" {
#   resource_group_name = azurerm_resource_group.main.name
#   location            = azurerm_resource_group.main.location
#   ...
# }
```

### Option 2: Remote State Data Source

Reference this resource group from a separate Terraform configuration:

```hcl
# In another Terraform workspace
data "terraform_remote_state" "rg" {
  backend = "local"
  config = {
    path = "../Create_Resource_Group/terraform.tfstate"
  }
}

# Reference the resource group
resource "azurerm_kubernetes_cluster" "aks" {
  resource_group_name = data.terraform_remote_state.rg.outputs.resource_group_name
  location            = data.terraform_remote_state.rg.outputs.resource_group_location
  ...
}
```

### Option 3: Data Source Lookup

Look up the existing resource group by name:

```hcl
# In another Terraform workspace
data "azurerm_resource_group" "existing" {
  name = "rg_aks_2512081900"  # Or use a variable
}

resource "azurerm_kubernetes_cluster" "aks" {
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location
  ...
}
```

The AKS deployment guide (`Create_AKS.md`) uses this resource group as a
prerequisite and demonstrates Option 3 (data source lookup).

Summary:

- Three patterns available for reusing this resource group.
- Choose based on whether you want shared or separate state management.
- Data source lookup (Option 3) provides loose coupling between configurations.

## Cleanup

### Destroy infrastructure

When finished with the resource group, use Terraform to destroy it.

**Warning:** Destroying the resource group will delete all resources contained
within it. Only proceed if you're certain you want to remove everything.

```bash
# Preview resources to be destroyed
terraform plan -destroy

# Destroy the resource group
terraform destroy
```

Terraform will prompt for confirmation. Type `yes` to proceed.

Alternative non-interactive destroy:

```bash
terraform destroy -auto-approve
```

Verify the resource group is deleted:

```bash
RG_NAME=$(terraform output -raw resource_group_name)
az group show --name "${RG_NAME}" 2>&1 | grep -q "ResourceGroupNotFound" && echo "Resource group successfully deleted"
```

Summary:

- Terraform destroy removes the resource group cleanly.
- Warning displayed about cascading deletion of contained resources.

## Summary

The Azure Resource Group has been created using Terraform infrastructure-as-code,
providing a reusable foundation for deploying Azure services.

Key accomplishments:

- **Declarative Configuration** - Resource group defined as code
- **State Management** - Terraform tracks the resource for safe updates
- **Idempotency Verified** - Demonstrated that repeated applies make no changes
- **Outputs Available** - Resource information ready for downstream use
- **Reusable Foundation** - Can be referenced by AKS, ACR, and other services

Summary:

- Resource group infrastructure provisioned and verified via Terraform.
- Ready to be used as a prerequisite for AKS cluster deployment.

## Next Steps

- Proceed with `docs/terraform/Create_AKS.md` to deploy AKS cluster in this resource group
- Deploy Azure Container Registry (ACR) in this resource group
- Add storage accounts, networking, or other Azure resources
- Configure remote state backend for team collaboration

## Terraform Best Practices Applied

This configuration follows Terraform best practices:

- ✅ Version constraints for Terraform and providers
- ✅ Variables with descriptions and defaults
- ✅ Outputs for downstream consumption
- ✅ Resource tagging for management and cost tracking
- ✅ Computed values (hash, names) in locals
- ✅ .gitignore for state and sensitive files
- ✅ Example file for onboarding
- ✅ Clear documentation of idempotent behavior

Summary:

- Terraform configuration ready for production use and team adoption.
- Foundation established for expanding infrastructure-as-code coverage.
