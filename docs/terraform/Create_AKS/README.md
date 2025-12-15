# AKS Infrastructure with Terraform - Incremental Build Approach

This directory contains Terraform configuration for deploying Azure Kubernetes
Service (AKS) using an **incremental building methodology** that demonstrates
Terraform's idempotent behavior.

**Prerequisites:** You must complete [`../Create_Resource_Group.md`](../Create_Resource_Group.md)
before using this configuration. The AKS cluster requires an existing Azure
Resource Group.

## Quick Links

- **Prerequisite:** [`../Create_Resource_Group.md`](../Create_Resource_Group.md) - Create RG first
- **Full Guide:** [`../Create_AKS.md`](../Create_AKS.md) - AKS deployment
- **Comparison:** [`COMPARISON.md`](COMPARISON.md) - Bash vs Terraform

## Files Overview

### Core Configuration (Provided)

- **providers.tf** - Azure provider and Terraform version constraints
- **variables.tf** - Input variables with defaults matching bash guide
- **outputs.tf** - Output values for cluster information and verification
- **terraform.tfvars.example** - Template for your configuration
- **.gitignore** - Protects state files and sensitive data

### Main Configuration (You Build This)

- **aks.tf** - AKS cluster resources (you create incrementally)

### Reference Examples

- **aks-step1-cluster.tf.example** - Step 1: Data source + AKS cluster
- **aks-step2-user-nodepool.tf.example** - Step 2: Complete with node pool

## Two Approaches

### Approach 1: Incremental Learning (Recommended)

Build `aks.tf` from scratch following the guide. This approach:
- Demonstrates Terraform's idempotent behavior
- Shows data source usage to reference existing infrastructure
- Shows how adding resources only creates new ones
- Teaches the plan-before-apply workflow
- Demonstrates loose coupling between Terraform workspaces

**Steps:**
1. Ensure resource group exists (from Create_Resource_Group)
2. Create `aks.tf` with data source
3. Add AKS cluster, apply
4. Add user node pool, apply (cluster unchanged)
5. At each step, observe idempotency by running apply twice

See [`../Create_AKS.md`](../Create_AKS.md) for detailed instructions.

### Approach 2: Quick Start (Skip Learning)

Use the complete example file (after creating resource group):

```bash
# Ensure resource group exists first
cd ../Create_Resource_Group && terraform apply && cd ../Create_AKS

# Quick deploy AKS
cp aks-step2-user-nodepool.tf.example aks.tf
terraform init
terraform plan
terraform apply
```

This deploys all resources at once but doesn't demonstrate incremental behavior.

## Important Notes

### Expected Validation Behavior

When you have an incomplete `main.tf` (e.g., just the resource group), running
`terraform validate` may show errors because `outputs.tf` references resources
that don't exist yet. This is **expected** and **normal**.

**Example with Step 1 (resource group only):**
```bash
$ terraform validate
Error: Reference to undeclared resource
  on outputs.tf line 8, in output "aks_cluster_name":
   8:   value = azurerm_kubernetes_cluster.aks.name
```

**This is fine!** The error disappears once you add the AKS cluster resource
in Step 2. Terraform validates the entire configuration, including outputs.

**Workaround options:**
1. **Recommended:** Ignore the validation error and proceed with `terraform plan`
   and `terraform apply` - these commands work fine with partial configurations.
2. **Alternative:** Temporarily comment out the outputs that reference missing
   resources, then uncomment them as you add resources.

### Idempotency Demonstrations

Throughout the guide, you'll run `terraform apply` multiple times with the same
configuration to observe:

```
No changes. Your infrastructure matches the configuration.
```

This demonstrates Terraform's core behavior: it only makes changes when the
actual state differs from the desired configuration.

### State Management

After running `terraform apply`, you'll have:
- **terraform.tfstate** - Current infrastructure state (git-ignored)
- **.terraform/** - Provider plugins and modules (git-ignored)
- **.terraform.lock.hcl** - Provider version lock file (should be committed)

The state file is critical - it tracks what resources Terraform manages.

## Workflow Summary

```bash
# 1. Setup
cd docs/terraform/Create_AKS
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Azure subscription ID
terraform init

# 2. Verify Resource Group Exists
cd ../Create_Resource_Group
terraform output resource_group_name  # Get RG name
cd ../Create_AKS

# 3. Step 1 - Reference Resource Group
cat > aks.tf << 'EOF'
data "azurerm_resource_group" "existing" {
  name = var.azure_resource_group
}
EOF

terraform plan    # Shows data source will be read
terraform apply   # No changes, just validates RG exists

# 4. Step 2 - AKS Cluster
# Append AKS resource to aks.tf (see guide for full config)
cat >> aks.tf << 'EOF'
resource "azurerm_kubernetes_cluster" "aks" {
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  # ... configuration ...
}
EOF

terraform plan    # Shows AKS to add, data source refreshed
terraform apply   # Creates AKS cluster (5-8 min)
terraform apply   # Shows no changes (idempotent!)

# 5. Step 3 - User Node Pool
# Append user node pool to aks.tf
cat >> aks.tf << 'EOF'
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  # ... configuration ...
}
EOF

terraform plan    # Shows node pool to add, others unchanged
terraform apply   # Adds user node pool
terraform apply   # Shows no changes (idempotent!)

# 5. Get Credentials
eval $(terraform output -raw kube_config_command)
kubectl get nodes

# 6. Cleanup
terraform destroy
```

## Making Changes After Deployment

Edit `terraform.tfvars` or `main.tf`, then:

```bash
terraform plan     # Preview changes
terraform apply    # Apply changes
```

Terraform calculates the minimal diff and only updates what changed.

## Troubleshooting

**Issue:** Validation errors about missing resources  
**Solution:** Expected when building incrementally. Use `terraform plan` instead.

**Issue:** State conflicts or lock errors  
**Solution:** Only one person/process should manage this state. Consider remote
state backends for teams.

**Issue:** Plan shows unexpected changes  
**Solution:** Review `terraform show` to see current state, compare with config.

**Issue:** Authentication errors  
**Solution:** Run `az login` and verify `az account show`.

## Next Steps

After deploying AKS:
1. Deploy KMCP and MCP servers: `docs/OpenWebSearch_On_AKS.md`
2. Install KAITO for AI workloads: `docs/Install_Kaito_On_AKS.md`
3. Configure monitoring and observability
4. Set up remote state backend for team collaboration

## Learning Resources

- [Terraform AKS Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
- [Terraform State Documentation](https://developer.hashicorp.com/terraform/language/state)
- [Azure AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)

## Contributing

When improving this configuration:
- Keep the incremental approach - it's pedagogically valuable
- Test all three steps validate correctly (step 2 and 3)
- Update example files and main guide together
- Document any new variables in terraform.tfvars.example
