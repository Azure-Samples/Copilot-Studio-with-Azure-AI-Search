output "ai_search_resource_name" {
  description = "The name of the AI Search resource"
  value       = azurerm_search_service.ai_search.name
}

output "app_insights_instrumentation_key" {
  sensitive = true
  value     = var.include_app_insights ? azurerm_application_insights.insights[0].instrumentation_key : null
}

output "openai_resource_id" {
  description = "The ID of the OpenAI resource"
  value       = module.azure_open_ai.resource_id
}

output "power_platform_environment_id" {
  description = "The ID of the Power Platform environment"
  value       = module.copilot_studio.power_platform_environment_id
}
