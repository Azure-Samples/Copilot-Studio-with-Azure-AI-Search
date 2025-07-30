# Output values
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.tfstate.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.tfstate.id
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.tfstate.name
}

output "private_endpoint_ip" {
  description = "Private IP address of the storage account"
  value       = azurerm_private_endpoint.storage_blob.private_service_connection[0].private_ip_address
}

output "container_name" {
  description = "Name of the storage container"
  value       = azurerm_storage_container.tfstate.name
}

output "backend_config" {
  description = "Backend configuration for other Terraform projects"
  value = {
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
    resource_group_name  = azurerm_resource_group.tfstate.name
    subscription_id      = var.subscription_id
  }
}
