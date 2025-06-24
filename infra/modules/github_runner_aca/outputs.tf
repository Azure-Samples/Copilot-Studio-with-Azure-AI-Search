output "container_app_environment_id" {
  description = "The ID of the Container Apps Environment"
  value       = azurerm_container_app_environment.github_runners.id
}

output "github_runner_app_url" {
  description = "The URL of the GitHub runner Container App"
  value       = azurerm_container_app.github_runner.latest_revision_fqdn
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.github_runners.id
}

output "runner_name" {
  description = "The name of the GitHub runner"
  value       = local.runner_name
}

output "container_registry_id" {
  description = "The ID of the Azure Container Registry"
  value       = azurerm_container_registry.github_runners.id
}

output "container_registry_login_server" {
  description = "The login server URL for the Azure Container Registry"
  value       = azurerm_container_registry.github_runners.login_server
}

output "identity_id" {
  description = "Resource ID of the runner’s user-assigned identity"
  value       = azurerm_user_assigned_identity.github_runner.id
}

output "identity_principal_id" {
  description = "Principal ID of the runner’s user-assigned identity"
  value       = azurerm_user_assigned_identity.github_runner.principal_id
}
