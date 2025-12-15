output "resource_group_name" {
  description = "Name of the resource group (from data source)"
  value       = data.azurerm_resource_group.existing.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "aks_node_resource_group" {
  description = "Auto-generated resource group containing AKS cluster resources"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "kubernetes_version" {
  description = "Kubernetes version of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}

output "system_node_pool" {
  description = "System node pool configuration"
  value = {
    name       = var.aks_system_nodepool_name
    node_count = var.aks_system_node_count
    vm_size    = var.aks_node_vm_size
  }
}

output "user_node_pool" {
  description = "User node pool configuration (if created)"
  value = var.aks_user_node_count > 0 ? {
    name       = var.aks_user_nodepool_name
    node_count = var.aks_user_node_count
    vm_size    = var.aks_node_vm_size
  } : null
}

output "kube_config_command" {
  description = "Command to retrieve kubeconfig"
  value       = "az aks get-credentials --name ${azurerm_kubernetes_cluster.aks.name} --resource-group ${data.azurerm_resource_group.existing.name} --overwrite-existing"
}

output "computed_hash" {
  description = "The computed or provided hash used for resource naming"
  value       = local.computed_hash
}
