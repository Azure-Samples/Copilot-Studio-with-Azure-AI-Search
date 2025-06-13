# Power Platform connections

locals {
  search_connection_name         = "shared_azureaisearch"
  search_connection_display_name = "Azure AI Search Connection"
  search_connector_name          = "azureaisearch"
}

# Create the Power Platform connection for Azure AI Search
resource "powerplatform_connection" "ai_search_connection" {
  environment_id = module.copilot_studio.power_platform_environment_id
  name           = local.search_connection_name
  display_name   = local.search_connection_display_name
  # PowerPlatform connection resource doesn't accept connector_name directly
  connection_parameters = jsonencode({
    ConnectionEndpoint = local.search_endpoint_url
    AdminKey           = azurerm_search_service.ai_search.primary_key
  })

  lifecycle {
    ignore_changes = [
      connection_parameters
    ]
  }
}

# Share the connection with an interactive user for direct administration (if specified)
resource "powerplatform_connection_share" "share_ai_search_connection" {
  for_each = var.resource_share_user

  environment_id = module.copilot_studio.power_platform_environment_id
  connector_name = local.search_connector_name
  connection_id  = powerplatform_connection.ai_search_connection.id
  role_name      = "CanEdit"
  principal = {
    entra_object_id = each.value
  }
}
