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
