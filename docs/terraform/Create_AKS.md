# Create Azure AKS Infrastructure with Terraform

## Introduction

This executable document provisions the core Azure resources required for a
production-ready AKS deployment using Terraform infrastructure-as-code. Unlike
imperative bash scripts, we'll build up the infrastructure incrementally,
demonstrating Terraform's idempotent behavior at each step.

You'll create `aks.tf` from scratch, adding one resource at a time:

1. AKS Cluster with System Node Pool
2. Optional User Node Pool

At each step, you'll run `terraform plan` and `terraform apply` to see how
Terraform only changes what's needed to match your configuration.

Summary:

- Deploys AKS cluster into an existing Azure Resource Group
- Demonstrates Terraform's idempotent behavior and incremental additions
- Shows how to reference existing infrastructure via data sources
- Builds on the reusable Resource Group created in a separate guide

## Prerequisites

You must [create a resource group.md](./Create_Resource_Group.md) before proceeding with this guide. The AKS cluster requires an existing Azure Resource Group.

Verify you have created the resource group:

```bash
cd Create_Resource_Group
terraform output resource_group_name
```

You'll need the resource group name for AKS configuration.

### Required Tooling

The following tooling and account access are required:

- Azure subscription with quota for AKS in the selected region
- Azure CLI (`az`) with Owner or Contributor rights
- Terraform >= 1.5.0 installed and in PATH
- kubectl configured locally for cluster access
- jq (optional) for parsing JSON output during verification

```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v terraform >/dev/null || echo "Terraform missing"
command -v kubectl >/dev/null || echo "kubectl missing"
command -v jq >/dev/null || echo "jq missing (optional)"
```

Verify Terraform version:

```bash
terraform version
```

Summary:

- Confirms necessary CLI tooling and Azure access are in place.
- Validates Terraform installation meets minimum version requirements.

## Configuration

### Navigate to Terraform directory

All Terraform configuration files are located in `docs/terraform/Create_AKS`.
Navigate to this directory to execute Terraform commands.

```bash
cd docs/terraform/Create_AKS
```

### Configure Terraform variables

Create a `terraform.tfvars` file from the example template. This file contains
your Azure subscription ID, the existing resource group name, and optional
overrides for cluster naming and sizing.

```bash
if [ ! -f terraform.tfvars ]; then
  cp terraform.tfvars.example terraform.tfvars
  echo "Created terraform.tfvars - please edit with required values"
else
  echo "terraform.tfvars already exists"
fi
```

Edit `terraform.tfvars` and set required values:

```bash
# Get your Azure subscription ID
AZURE_SUB_ID=$(az account show --query id -o tsv)
echo "Your Azure subscription ID: ${AZURE_SUB_ID}"

# Get the resource group name from the Create_Resource_Group deployment
RG_NAME=$(cd ../Create_Resource_Group && terraform output -raw resource_group_name)
echo "Your Resource Group: ${RG_NAME}"

# Update terraform.tfvars with subscription ID
if ! grep -q "^azure_subscription_id\s*=\s*\"[^\"]*\"" terraform.tfvars 2>/dev/null; then
  sed -i "s/azure_subscription_id = \"00000000-0000-0000-0000-000000000000\"/azure_subscription_id = \"${AZURE_SUB_ID}\"/" terraform.tfvars
  echo "Updated terraform.tfvars with your subscription ID"
fi

# Update terraform.tfvars with resource group name
sed -i "s/azure_resource_group = \"rg_aks_[0-9]*\"/azure_resource_group = \"${RG_NAME}\"/" terraform.tfvars
echo "Updated terraform.tfvars with your resource group name"
```

Review and customize additional variables in `terraform.tfvars` as needed:

```bash
cat terraform.tfvars
```

Summary:

- Terraform variables configured with Azure subscription and deployment
  parameters.
- Default values provide a minimal proof-of-concept footprint suitable for
  experimentation.

## Terraform Infrastructure Files

The Terraform configuration uses multiple files for clarity and maintainability:

- **providers.tf** - Azure provider configuration and version constraints (provided)
- **variables.tf** - Input variables and default values (provided)
- **aks.tf** - AKS cluster resources (you'll build this incrementally)
- **outputs.tf** - Output values for verification (provided)
- **terraform.tfvars** - Your customized variable values (you'll create this)
- **.gitignore** - Excludes state files and sensitive data (provided)

Supporting reference files for each incremental step:

- **aks-step1-cluster.tf.example** - Data source + AKS cluster
- **aks-step2-user-nodepool.tf.example** - Complete configuration with node pool

**Note:** The example files are for reference only. You'll build your own
`aks.tf` by following the step-by-step instructions. You can review these files to understand the infrastructure being provisioned:

```bash
# List Terraform configuration files
ls -la *.tf *.tf.example *.tfvars* .gitignore 2>/dev/null
```

Summary:

- Foundation files (providers, variables, outputs) are provided and ready.
- You'll build aks.tf incrementally to understand Terraform's behavior.
- Example files show each step for reference or quick-start copying.

## Steps

Execute each step sequentially. You'll build `aks.tf` incrementally, and at
each step Terraform will only apply the changes needed to bring your
infrastructure in line with the configuration.

### Check Azure subscription context

Verify the active Azure subscription and ensure required resource providers
are registered.

```bash
az account show --query id -o tsv
az provider register --namespace Microsoft.ContainerService
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

## Building Infrastructure Incrementally

Now you'll build `aks.tf` from scratch, adding one resource at a time. After
each addition, you'll run `terraform plan` and `terraform apply` to see
Terraform's idempotent behavior in action.

### Reference Existing Resource Group

Start by creating `aks.tf` with a data source that references the existing
resource group you created in the `Create_Resource_Group` guide.

```bash
cat > aks.tf << 'EOF'
# Reference existing Resource Group
# This assumes you've already created a resource group using Create_Resource_Group.md

data "azurerm_resource_group" "existing" {
  name = var.azure_resource_group
}
EOF
```

Verify the data source can find your resource group:

```bash
terraform plan
```

Expected output shows:

- `data.azurerm_resource_group.existing` will be **read**
- No resources to create yet
- Plan shows 0 to add, 0 to change, 0 to destroy

This confirms Terraform can locate your existing resource group. The data source
will fetch its attributes (location, tags, etc.) for use in the AKS configuration.

You can also verify by checking what Terraform will read:

```bash
terraform plan 2>&1 | grep "data.azurerm_resource_group.existing"
```

Summary:

- Data source configured to reference existing resource group.
- Terraform validates the resource group exists.
- No resources created yet - just reading existing infrastructure.

### Add AKS Cluster

Now add the AKS cluster to your existing `aks.tf`. The cluster will be deployed
into the resource group referenced by the data source.

```bash
cat >> aks.tf << 'EOF'

# AKS Cluster with System Node Pool
# Managed Kubernetes control plane and system nodes

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  dns_prefix          = local.cluster_name
  kubernetes_version  = var.aks_version != "" ? var.aks_version : null

  default_node_pool {
    name       = var.aks_system_nodepool_name
    node_count = var.aks_system_node_count
    vm_size    = var.aks_node_vm_size
    type       = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Hash        = local.computed_hash
  }
}
EOF
```

Run `terraform plan` to see what will change:

```bash
terraform plan
```

Expected output shows:

- `data.azurerm_resource_group.existing` - **will be read** (data source)
- `azurerm_kubernetes_cluster.aks` - **will be created**
- Plan shows 1 to add, 0 to change, 0 to destroy

**This demonstrates data source usage:** Terraform reads the existing resource
group's attributes (location) and uses them to configure the AKS cluster.

Apply the configuration:

```bash
terraform apply
```

Type `yes` when prompted. This takes 5-8 minutes as Azure provisions the AKS
cluster and nodes.

**Demonstrate Idempotency Again:**

```bash
terraform apply
```

Output shows:

```
No changes. Your infrastructure matches the configuration.
```

The data source will be refreshed and the AKS cluster checked, but no changes made.

Summary:

- AKS cluster created in the existing resource group.
- Data source automatically provides location from existing RG.
- Terraform state now tracks the AKS cluster.
- Expected duration: 5-8 minutes for cluster creation.
- Expected duration: 5-8 minutes for cluster creation.

### Add User Node Pool (Optional)

Finally, add an user node pool for workload separation.

```bash
cat >> aks.tf << 'EOF'
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.aks_user_node_count > 0 ? 1 : 0

  name                  = var.aks_user_nodepool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.aks_node_vm_size
  node_count            = var.aks_user_node_count
  mode                  = "User"

  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Hash        = local.computed_hash
  }
}
EOF
```

Run `terraform plan`:

```bash
terraform plan
```

Expected output shows:

- `azurerm_resource_group.aks` - **no changes**
- `azurerm_kubernetes_cluster.aks` - **no changes**
- `azurerm_kubernetes_cluster_node_pool.user[0]` will be **created** (if count > 0)
- Plan shows 1 to add, 0 to change, 0 to destroy

Apply the configuration:

```bash
terraform apply -auto-approve
```

Type `yes` when prompted. The user node pool is added to the existing cluster.

**Final Idempotency Check:**

```bash
terraform apply -auto-approve
```

Output confirms:

```
No changes. Your infrastructure matches the configuration.
```

All three resources (resource group, AKS cluster, user node pool) are now
stable and match your configuration.

Summary:

- User node pool added to existing AKS cluster.
- Previous resources (RG, AKS) unchanged (idempotent).
- Complete infrastructure now provisioned.
- Terraform state tracks all three resources.

### Understanding Terraform's Behavior

What you've just experienced:

1. **Idempotency:** Running `terraform apply` multiple times with the same
   configuration makes changes only on the first run. Subsequent runs detect
   no drift and make no changes.

2. **Incremental Changes:** Adding new resources to `aks.tf` causes Terraform
   to create only those new resources. The data source is refreshed each time
   to get current attributes from the existing resource group.

3. **State Tracking:** Terraform's state file tracks what's deployed in this
   workspace (AKS cluster, node pool). Data sources query existing infrastructure
   managed elsewhere (resource group from separate workspace).

4. **Plan Before Apply:** The `terraform plan` command shows exactly what will
   change before you commit to it, providing safety and predictability.

### Review Terraform outputs

Display Terraform output values that provide cluster connection details and
verification commands.

```bash
terraform output
```

Key outputs include:

- `resource_group_name` - Created resource group
- `aks_cluster_name` - AKS cluster name
- `kubernetes_version` - Deployed Kubernetes version
- `kube_config_command` - Command to configure kubectl

Get the kubeconfig command:

```bash
echo "Run this command to configure kubectl:"
terraform output -raw kube_config_command
```

Summary:

- Terraform outputs provide key cluster information for verification and access.

### Retrieve cluster credentials

Configure kubectl to connect to the newly created AKS cluster using the command
from Terraform outputs.

```bash
eval $(terraform output -raw kube_config_command)
kubectl get nodes -o wide
```

Alternative manual approach:

```bash
CLUSTER_NAME=$(terraform output -raw aks_cluster_name)
RG_NAME=$(terraform output -raw resource_group_name)

az aks get-credentials \
  --name "${CLUSTER_NAME}" \
  --resource-group "${RG_NAME}" \
  --overwrite-existing

kubectl get nodes -o wide
```

Summary:

- kubectl context updated and node connectivity verified.
- Cluster is ready for workload deployment.

## Verification

Confirm the AKS cluster exists and responds to queries from both Terraform
and kubectl perspectives.

### Verify with Terraform

Check Terraform state and outputs to confirm successful deployment:

```bash
# List managed resources
terraform state list

# Show cluster details
terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="azurerm_kubernetes_cluster") | {name, location, kubernetes_version, node_count: .values.default_node_pool[0].node_count}'
```

Summary:

- Terraform state confirms all resources are tracked and healthy.

### Verify with Azure CLI

Query Azure directly to confirm cluster provisioning state:

```bash
CLUSTER_NAME=$(terraform output -raw aks_cluster_name)
RG_NAME=$(terraform output -raw resource_group_name)

az aks show \
  --name "${CLUSTER_NAME}" \
  --resource-group "${RG_NAME}" \
  --query "{name:name,provisioningState:provisioningState,location:location,kubernetesVersion:kubernetesVersion}" \
  --output table
```

Expected output showing cluster in `Succeeded` state.

Summary:

- Azure confirms cluster is provisioned and operational.

### Verify with kubectl

Confirm kubectl can communicate with the cluster and enumerate nodes:

```bash
kubectl cluster-info
```

This command will output status of the current cluster:

<!-- expected_similarity="(?s).*control plane is running.*" -->

```text
Kubernetes control plane is running at ...
CoreDNS is running at https://...
Metrics-server is running at https://...
```

Check node pools are correctly configured:

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.labels.agentpool}{"\n"}{end}' |
  sort |
  uniq -c
```

Expected output showing system and user node counts:

<!-- expected_similarity=".*[0-9]+.*system\n.*[0-9]+.*user" -->

```text
      1 system
      1 user
```

List all nodes with details:

```bash
kubectl get nodes -o wide
```

Summary:

- kubectl verifies cluster is healthy and all node pools are ready.
- Both system and user node pools are available for workload scheduling.

### Review Terraform-managed resources

Display a summary of all resources managed by this Terraform configuration:

```bash
terraform state list
```

Get detailed information about the AKS cluster resource:

```bash
terraform state show azurerm_kubernetes_cluster.aks | head -30
```

Summary:

- Terraform state tracking all provisioned infrastructure.
- Resources are under declarative infrastructure-as-code management.

## Making Changes

### Modifying the infrastructure

Terraform's idempotent behavior makes changes safe and predictable. You simply
update your configuration files, and Terraform calculates the minimal changes
needed.

Example - scale user node pool from 1 to 3 nodes:

```bash
# Edit terraform.tfvars
sed -i 's/aks_user_node_count = 1/aks_user_node_count = 3/' terraform.tfvars

# Preview the change
terraform plan
```

The plan output shows:

- `azurerm_resource_group.aks` - **no changes**
- `azurerm_kubernetes_cluster.aks` - **no changes**
- `azurerm_kubernetes_cluster_node_pool.user[0]` - **will be updated in-place**
  (node_count: 1 → 3)

Only the changed attribute is modified. Apply the change:

```bash
terraform apply
```

**Demonstrate idempotency after the change:**

```bash
terraform apply
```

Output shows no changes again - the infrastructure now matches the updated
configuration.

You can also modify `aks.tf` directly. For example, to add additional tags
to the AKS cluster:

```bash
# Edit aks.tf to add a new tag to the AKS cluster
# For example, add: Project = "MCPaaS"
# Then run plan to preview
terraform plan

# Apply if the changes look correct
terraform apply
```

**Note:** To modify the resource group tags, edit the resource group
configuration in the `Create_Resource_Group` workspace.

Summary:

- Changes are declarative: update configuration, Terraform handles the rest.
- Plan always shows exactly what will change before applying.
- Idempotency ensures safety: re-running apply after no config changes does nothing.
- Terraform minimizes changes: only modified resources/attributes are updated.

## Cleanup

### Destroy infrastructure

When finished with the cluster, use Terraform to destroy the AKS resources.
**Note:** This only destroys the AKS cluster and node pools, not the resource
group (which is managed in a separate workspace).

```bash
# Preview resources to be destroyed
terraform plan -destroy

# Destroy AKS cluster and node pools
terraform destroy
```

Terraform will prompt for confirmation before destroying resources. Type `yes`
to proceed.

Alternative non-interactive destroy:

```bash
terraform destroy -auto-approve
```

**To also destroy the resource group**, navigate to the Create_Resource_Group
workspace:

```bash
cd ../Create_Resource_Group
terraform destroy
```

**Warning:** Destroying the resource group will delete all resources contained
within it. Only proceed after destroying the AKS cluster first.

Summary:

- Terraform destroy removes AKS-managed resources cleanly.
- Resource group managed separately - destroy it only after AKS is removed.
- Proper cleanup order: AKS first, then resource group.

## Summary

The AKS cluster has been provisioned using Terraform infrastructure-as-code,
providing several advantages over imperative scripting:

- **Declarative Configuration** - Infrastructure defined as code in version control
- **State Management** - Terraform tracks resource state for safe updates
- **Idempotency** - Repeated applies only make necessary changes
- **Change Preview** - Plan command shows exactly what will change
- **Clean Destruction** - Destroy removes all resources without orphans

The cluster is ready for any containerized workloads. Use dedicated deployment
documents for specific services.

Summary:

- AKS infrastructure provisioned and verified via Terraform.
- Infrastructure-as-code enables repeatable, reviewable deployments.

## Comparison with Bash Approach

This Terraform approach replaces the bash-based workflow in `docs/Create_AKS.md`
with declarative infrastructure-as-code. Key differences:

| Aspect                 | Bash (Create_AKS.md)           | Terraform (This Guide)        |
| ---------------------- | ------------------------------ | ----------------------------- |
| **Style**              | Imperative commands            | Declarative configuration     |
| **State**              | No state tracking              | Terraform state file          |
| **Idempotency**        | Manual checks required         | Automatic                     |
| **Change preview**     | Not available                  | `terraform plan`              |
| **Version control**    | Script only                    | Full infrastructure as code   |
| **Cleanup**            | Manual resource deletion       | `terraform destroy`           |
| **Repeatability**      | Environment variable dependent | Configuration file based      |
| **Team collaboration** | Script sharing                 | State sharing + config review |

Choose Terraform when:

- Managing long-lived infrastructure
- Working in teams with code review
- Need state tracking and drift detection
- Want preview-before-apply safety

Choose Bash when:

- One-off cluster creation
- Learning AKS concepts interactively
- Scripting dynamic workflows
- Minimal tooling requirements

Summary:

- Both approaches create identical AKS infrastructure.
- Terraform adds IaC benefits for production and team environments.
- Bash approach offers simplicity for learning and experimentation.

## Next Steps

- Proceed with `docs/OpenWebSearch_On_AKS.md` to deploy KMCP and MCP servers
- Configure role assignments or network policies specific to your security posture
- Integrate Azure Monitor or Log Analytics for operational visibility
- Store Terraform state remotely (Azure Storage, Terraform Cloud) for team collaboration
- Add Terraform modules to manage related resources (ACR, networking, monitoring)

## Terraform Best Practices Applied

This configuration follows Terraform best practices:

- ✅ Version constraints for Terraform and providers
- ✅ Variables with descriptions and defaults
- ✅ Outputs for downstream consumption
- ✅ Resource tagging for management and cost tracking
- ✅ Computed values (hash, names) in locals
- ✅ Conditional resource creation (user node pool)
- ✅ .gitignore for state and sensitive files
- ✅ Example tfvars for onboarding
- ✅ Organized file structure by concern

Summary:

- Terraform configuration ready for production use and team adoption.
- Foundation established for expanding infrastructure-as-code coverage.
