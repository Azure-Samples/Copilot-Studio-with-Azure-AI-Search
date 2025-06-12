output "ai_search_resource_name" {
  description = "The name of the AI Search resource"
  value       = azurerm_search_service.ai_search.name
}

output "app_insights_instrumentation_key" {
  sensitive = true
  value     = var.include_app_insights ? azurerm_application_insights.insights[0].instrumentation_key : null
}

output "power_platform_environment_id" {
  description = "The ID of the Power Platform environment"
  value       = module.copilot_studio.power_platform_environment_id
}

output "aisearch_connection_id" {
  description = "The ID of the AI Search connector in Power Platform"
  value       = powerplatform_connection.ai_search_connection.id
}

output "container_app_environment_id" {
  description = "The ID of the Container Apps Environment"
  value       = var.enable_vm_github_runner ? null : (length(module.github_runner_aca_primary) > 0 ? module.github_runner_aca_primary[0].container_app_environment_id : null)
}

output "github_runner_app_url" {
  description = "The URL of the GitHub runner Container App"
  value       = var.enable_vm_github_runner ? null : (length(module.github_runner_aca_primary) > 0 ? module.github_runner_aca_primary[0].github_runner_app_url : null)
}

output "container_registry_id" {
  description = "The ID of the Azure Container Registry"
  value       = module.github_runner_aca_primary.container_registry_id
}

output "container_registry_login_server" {
  description = "The login server URL for the Azure Container Registry"
  value       = module.github_runner_aca_primary.container_registry_login_server
}
output "github_runner_vm_name" {
  description = "The name of the GitHub runner VM"
  value       = var.enable_vm_github_runner ? (length(module.github_runner_vm) > 0 ? module.github_runner_vm[0].github_runner_vm_name : null) : null
}
