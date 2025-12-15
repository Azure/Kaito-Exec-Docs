# Bash vs Terraform: AKS Deployment Comparison

This document compares the bash-based approach (`docs/Create_AKS.md`) with the
Terraform-based approach (`docs/terraform/Create_AKS.md`) for creating AKS
infrastructure.

The Terraform guide uses an **incremental building approach** where you create
`main.tf` from scratch, adding one resource at a time to demonstrate Terraform's
idempotent behavior.

## Side-by-Side Command Comparison

### Check Prerequisites

**Bash:**
```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v kubectl >/dev/null || echo "kubectl missing"
```

**Terraform:**
```bash
command -v az >/dev/null || echo "Azure CLI missing"
command -v terraform >/dev/null || echo "Terraform missing"
command -v kubectl >/dev/null || echo "kubectl missing"
terraform version
```

### Set Configuration

**Bash:**
```bash
export HASH="${HASH:-$(date -u +"%y%m%d%H%M")}"
export AZURE_LOCATION="${AZURE_LOCATION:-eastus2}"
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg_aks_${HASH}}"
export AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-${HASH}}"
export AKS_VERSION="${AKS_VERSION:-}"
export AKS_SYSTEM_NODE_COUNT="${AKS_SYSTEM_NODE_COUNT:-1}"
export AKS_USER_NODE_COUNT="${AKS_USER_NODE_COUNT:-1}"
export AKS_NODE_VM_SIZE="${AKS_NODE_VM_SIZE:-Standard_D4s_v5}"
```

**Terraform:**
```hcl
# In terraform.tfvars
azure_subscription_id = "your-sub-id"
azure_location = "eastus2"
aks_system_node_count = 1
aks_user_node_count = 1
aks_node_vm_size = "Standard_D4s_v5"
# Hash computed automatically
```

### Create Resource Group

**Bash:**
```bash
az group create \
  --name "${AZURE_RESOURCE_GROUP}" \
  --location "${AZURE_LOCATION}" \
  --output table
```

**Terraform:**
```hcl
# In main.tf (declarative)
resource "azurerm_resource_group" "aks" {
  name     = local.resource_group_name
  location = var.azure_location
}
```

### Create AKS Cluster

**Bash:**
```bash
if az aks show \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "AKS cluster ${AKS_CLUSTER_NAME} already exists";
else
  az aks create \
    --name "${AKS_CLUSTER_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --location "${AZURE_LOCATION}" \
    --generate-ssh-keys \
    --node-count "${AKS_SYSTEM_NODE_COUNT}" \
    --nodepool-name "${AKS_SYSTEM_NODEPOOL_NAME}" \
    --node-vm-size "${AKS_NODE_VM_SIZE}" \
    ${AKS_VERSION:+--kubernetes-version "${AKS_VERSION}"} \
    --output table
fi
```

**Terraform:**
```hcl
# In main.tf (declarative, idempotent automatically)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
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
}
```

### Add User Node Pool

**Bash:**
```bash
if [ "${AKS_USER_NODE_COUNT}" -gt 0 ]; then
  if az aks nodepool show \
    --cluster-name "${AKS_CLUSTER_NAME}" \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AKS_USER_NODEPOOL_NAME}" >/dev/null 2>&1; then
    echo "Node pool ${AKS_USER_NODEPOOL_NAME} already exists";
  else
    az aks nodepool add \
      --cluster-name "${AKS_CLUSTER_NAME}" \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${AKS_USER_NODEPOOL_NAME}" \
      --node-count "${AKS_USER_NODE_COUNT}" \
      --node-vm-size "${AKS_NODE_VM_SIZE}" \
      --no-wait
    az aks nodepool wait \
      --cluster-name "${AKS_CLUSTER_NAME}" \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${AKS_USER_NODEPOOL_NAME}" \
      --created
  fi
fi
```

**Terraform:**
```hcl
# In main.tf (conditional creation)
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.aks_user_node_count > 0 ? 1 : 0

  name                  = var.aks_user_nodepool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.aks_node_vm_size
  node_count            = var.aks_user_node_count
  mode                  = "User"
}
```

### Get Credentials

**Bash:**
```bash
az aks get-credentials \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --overwrite-existing
kubectl get nodes -o wide
```

**Terraform:**
```bash
# Output provides command
eval $(terraform output -raw kube_config_command)
kubectl get nodes -o wide
```

### Verification

**Bash:**
```bash
az aks show \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --query "{name:name,provisioningState:provisioningState,location:location}" \
  --output table
```

**Terraform:**
```bash
terraform output
terraform state list
terraform show
```

### Cleanup

**Bash:**
```bash
az group delete \
  --name "${AZURE_RESOURCE_GROUP}" \
  --yes \
  --no-wait
```

**Terraform:**
```bash
terraform destroy
```

## Feature Comparison Matrix

| Feature | Bash | Terraform | Winner |
|---------|------|-----------|--------|
| **Lines of Code** | ~300 | ~150 (excluding docs) | Terraform |
| **Idempotency** | Manual checks | Automatic | Terraform |
| **State Tracking** | None | Built-in | Terraform |
| **Change Preview** | ❌ | ✅ `terraform plan` | Terraform |
| **Rollback** | Manual | `terraform apply` previous | Terraform |
| **Version Control** | Script only | Full IaC | Terraform |
| **Learning Curve** | Lower | Higher | Bash |
| **Setup Time** | Faster | Requires init | Bash |
| **Team Collaboration** | Script sharing | State + code review | Terraform |
| **Drift Detection** | ❌ | ✅ `terraform plan` | Terraform |
| **Dependencies** | Just `az` CLI | Terraform + `az` CLI | Bash |
| **Debugging** | Echo statements | Plan output | Terraform |
| **Reusability** | Copy/paste | Modules | Terraform |
| **Documentation** | Inline comments | HCL self-documenting | Tie |
| **Cleanup** | Manual resource tracking | `terraform destroy` | Terraform |

## Execution Time Comparison

| Phase | Bash | Terraform | Notes |
|-------|------|-----------|-------|
| **Setup** | < 1 min | 1-2 min | Terraform needs init |
| **Resource Group** | 10-15 sec | N/A | Bundled in apply |
| **AKS Creation** | 5-8 min | 5-8 min | Same Azure API |
| **Node Pool** | 2-3 min | N/A | Bundled in apply |
| **Total** | 7-12 min | 7-12 min | Similar overall |
| **Updates** | 3-5 min | 2-3 min | Terraform faster on updates |
| **Destroy** | 5-10 min | 5-10 min | Same Azure API |

## Code Complexity

### Bash Complexity
- **Manual idempotency:** Requires `if` checks for existing resources
- **Error handling:** Must handle each command's exit code
- **State management:** Environment variables only, lost on session end
- **Async operations:** Manual `--no-wait` and `wait` commands
- **Conditional logic:** Shell scripting patterns

### Terraform Complexity
- **Automatic idempotency:** Built into Terraform core
- **Error handling:** Automatic rollback on failure
- **State management:** Persistent state file with locking
- **Async operations:** Handled automatically
- **Conditional logic:** HCL `count` and ternary expressions

## When to Choose Each Approach

### Choose Bash When:
1. **Learning:** Exploring Azure and AKS interactively
2. **One-off deployments:** Quick experimentation or demos
3. **Minimal tooling:** Don't want to install Terraform
4. **Dynamic workflows:** Need shell scripting flexibility
5. **Quick prototyping:** Fast iteration without state management
6. **Educational:** Teaching Azure CLI commands

### Choose Terraform When:
1. **Production infrastructure:** Long-lived, managed resources
2. **Team collaboration:** Code review and change tracking
3. **State tracking:** Need to track infrastructure state
4. **Change preview:** Want to see changes before applying
5. **Drift detection:** Need to detect manual changes
6. **Reusability:** Building modules for repeated use
7. **Compliance:** Infrastructure-as-code requirements
8. **CI/CD integration:** Automated infrastructure pipelines

## Migration Path

If starting with Bash and moving to Terraform:

1. **Import existing resources:**
   ```bash
   terraform import azurerm_resource_group.aks /subscriptions/<sub-id>/resourceGroups/<rg-name>
   terraform import azurerm_kubernetes_cluster.aks /subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.ContainerService/managedClusters/<cluster-name>
   ```

2. **Verify state:**
   ```bash
   terraform plan  # Should show no changes
   ```

3. **Manage going forward with Terraform**

## Hybrid Approach

You can use both approaches together:

- **Terraform:** Manage core infrastructure (RG, AKS, networking)
- **Bash:** Handle dynamic operations (deployments, troubleshooting)
- **kubectl:** Manage Kubernetes resources

Example workflow:
```bash
# Create infrastructure with Terraform
cd docs/terraform/Create_AKS
terraform apply

# Get credentials with bash
eval $(terraform output -raw kube_config_command)

# Deploy workloads with kubectl
kubectl apply -f deployment.yaml

# Update infrastructure with Terraform
terraform apply

# Troubleshoot with bash/Azure CLI
az aks show --name $(terraform output -raw aks_cluster_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

## Conclusion

Both approaches create identical AKS infrastructure. The choice depends on:

- **Use case:** Learning vs. production
- **Team size:** Individual vs. team
- **Duration:** Temporary vs. long-lived
- **Compliance:** Ad-hoc vs. IaC requirements
- **Expertise:** Azure CLI familiarity vs. Terraform knowledge

**Recommendation:**
- Start with **Bash** for learning and exploration
- Move to **Terraform** for production and team environments
- Use **both** where appropriate for your workflow

The MCPaaS project maintains both approaches to serve different user needs
and learning styles.
