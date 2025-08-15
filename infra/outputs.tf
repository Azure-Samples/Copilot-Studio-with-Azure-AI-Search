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

output "resource_group_name" {
  description = "The name of the resource group containing all resources"
  value       = local.resource_group_name
}



output "openai_endpoint" {
  description = "The endpoint URL for the Azure OpenAI service"
  value       = module.azure_open_ai.endpoint
}

output "primary_azure_region" {
  description = "The primary Azure region for deployment"
  value       = local.primary_azure_region
}

output "secondary_azure_region" {
  description = "The secondary Azure region for deployment"
  value       = local.secondary_azure_region
}
