# Output values
output "backend_config" {
  description = "Backend configuration for other Terraform projects"
  value = {
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
    resource_group_name  = azurerm_resource_group.tfstate.name
    subscription_id      = var.subscription_id
  }
}