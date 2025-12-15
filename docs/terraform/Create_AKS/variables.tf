variable "hash" {
  description = "Unique timestamp identifier for resource naming (YYMMDDHHMM format)"
  type        = string
  default     = ""
}

variable "azure_location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "eastus2"
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "azure_resource_group" {
  description = "Name of the existing Azure resource group (created via Create_Resource_Group.md)"
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = ""
}

variable "aks_version" {
  description = "Kubernetes version for the AKS cluster (empty for latest)"
  type        = string
  default     = ""
}

variable "aks_system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 1
}

variable "aks_user_node_count" {
  description = "Number of nodes in the user node pool (0 to skip)"
  type        = number
  default     = 1
}

variable "aks_node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "aks_system_nodepool_name" {
  description = "Name of the system node pool"
  type        = string
  default     = "system"
}

variable "aks_user_nodepool_name" {
  description = "Name of the user node pool"
  type        = string
  default     = "user"
}

locals {
  # Generate hash if not provided
  computed_hash = var.hash != "" ? var.hash : formatdate("YYMMDDhhmm", timestamp())

  # Compute cluster name with hash
  cluster_name = var.aks_cluster_name != "" ? var.aks_cluster_name : "aks-${local.computed_hash}"
}
