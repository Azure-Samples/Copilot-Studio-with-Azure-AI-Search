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
