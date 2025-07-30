# GitHub repository variables

# Set the storage account name as a GitHub repository variable
resource "github_actions_variable" "rs_storage_account" {
  repository    = var.github_repository
  variable_name = "RS_STORAGE_ACCOUNT"
  value         = azurerm_storage_account.tfstate.name
}

# Optional: Also set the resource group name for completeness
resource "github_actions_variable" "rs_resource_group" {
  repository    = var.github_repository
  variable_name = "RS_RESOURCE_GROUP"
  value         = azurerm_resource_group.tfstate.name
}

# Optional: Also set the container name for completeness
resource "github_actions_variable" "rs_container_name" {
  repository    = var.github_repository
  variable_name = "RS_CONTAINER_NAME"
  value         = azurerm_storage_container.tfstate.name
}
