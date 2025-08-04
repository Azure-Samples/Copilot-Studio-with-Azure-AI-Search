output "ai_search_resource_name" {
  description = "The name of the AI Search resource"
  value       = azurerm_search_service.ai_search.name
}

output "ai_search_endpoint" {
  description = "The endpoint URL of the AI Search service"
  value       = "https://${azurerm_search_service.ai_search.name}.search.windows.net"
}

output "ai_search_base_index_name" {
  description = "The base name used for AI Search resources"
  value       = var.ai_search_base_index_name
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

output "resource_group_name" {
  description = "The name of the resource group containing all resources"
  value       = azurerm_resource_group.this.name
}

output "container_app_environment_id" {
  description = "The ID of the Container Apps Environment"
  value       = var.deploy_github_runner ? module.github_runner_aca_primary[0].container_app_environment_id : null
}

output "github_runner_app_url" {
  description = "The URL of the GitHub runner Container App"
  value       = var.deploy_github_runner ? module.github_runner_aca_primary[0].github_runner_app_url : null
}

output "container_registry_id" {
  description = "The ID of the Azure Container Registry"
  value       = var.deploy_github_runner ? module.github_runner_aca_primary[0].container_registry_id : null
}

output "container_registry_login_server" {
  description = "The login server URL for the Azure Container Registry"
  value       = var.deploy_github_runner ? module.github_runner_aca_primary[0].container_registry_login_server : null
}

output "openai_endpoint" {
  description = "The endpoint URL for the Azure OpenAI service"
  value       = module.azure_open_ai.endpoint
}

output "copilot_studio_endpoint" {
  description = "The endpoint URL for Copilot Studio API"
  value       = "https://api.copilotstudio.microsoft.com"
}

output "copilot_studio_agent_id" {
  description = "The ID of the deployed Copilot Studio agent (placeholder - to be extracted from deployment)"
  value       = "crf6d_aiSearchConnectionExample" # This should match the bot name from the solution
}

output "azure_tenant_id" {
  description = "The Azure tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "azure_subscription_id" {
  description = "The Azure subscription ID"
  value       = data.azurerm_client_config.current.subscription_id
}
