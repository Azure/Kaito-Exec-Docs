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
  description = "Name of the Azure resource group"
  type        = string
  default     = ""
}

locals {
  # Generate hash if not provided
  computed_hash = var.hash != "" ? var.hash : formatdate("YYMMDDhhmm", timestamp())
  
  # Compute resource group name with hash
  resource_group_name = var.azure_resource_group != "" ? var.azure_resource_group : "rg_aks_${local.computed_hash}"
}
