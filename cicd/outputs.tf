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

output "github_runner_subnet_id" {
  description = "ID of the GitHub runner subnet"
  value       = azurerm_subnet.github_runner.id
}


# output "container_app_environment_id" {
#   description = "The ID of the Container Apps Environment"
#   value       = var.deploy_github_runner ? module.github_runner_aca_primary[0].container_app_environment_id : null
# }

# output "github_runner_app_url" {
#   description = "The URL of the GitHub runner Container App"
#   value       = var.deploy_github_runner ? module.github_runner_aca_primary[0].github_runner_app_url : null
# }

# output "container_registry_id" {
#   description = "The ID of the Azure Container Registry"
#   value       = var.deploy_github_runner ? module.github_runner_aca_primary[0].container_registry_id : null
# }

# output "container_registry_login_server" {
#   description = "The login server URL for the Azure Container Registry"
#   value       = var.deploy_github_runner ? module.github_runner_aca_primary[0].container_registry_login_server : null
# }