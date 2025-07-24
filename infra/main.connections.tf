# Power Platform connections

locals {
  search_connection_name         = "shared_azureaisearch"
  search_connection_display_name = "Azure AI Search Connection"
  search_connector_name          = "azureaisearch"

  ai_search_authentication = local.use_service_principal ? jsonencode({
    "name" : "oauthSP",
    "values" : {
      "token" : {
        "value" : "https://global.consent.azure-apim.net/redirect/azureaisearch"
      },
      "ConnectionEndpoint" : {
        "value" : local.search_endpoint_url
      },
      "token:TenantId" : {
        "value" : data.azurerm_client_config.current.tenant_id
      },
      "token:clientId" : {
        "value" : var.azure_ai_search_service_principal.client_id
      },
      "token:clientSecret" : {
        "value" : var.azure_ai_search_service_principal.client_secret
      }
    }
  }) : jsonencode(
    {
      "name" : "adminkey",
      "values" : {
        "ConnectionEndpoint" : {
          "value" :  local.search_endpoint_url
        },
        "AdminKey" : {
          "value" : azurerm_search_service.ai_search.primary_key
        }
      }
  })
}

# Create the Power Platform connection for Azure AI Search
resource "powerplatform_connection" "ai_search_connection" {
  environment_id = module.copilot_studio.power_platform_environment_id
  name           = local.search_connection_name
  display_name   = local.search_connection_display_name
  # PowerPlatform connection resource doesn't accept connector_name directly
  
  connection_parameters_set = local.ai_search_authentication

  lifecycle {
    ignore_changes = [
      connection_parameters_set
    ]
  }
}

# # Share the connection with an interactive user for direct administration (if specified)
# resource "powerplatform_connection_share" "share_ai_search_connection" {
#   for_each = var.resource_share_user

#   environment_id = module.copilot_studio.power_platform_environment_id
#   connector_name = local.search_connector_name
#   connection_id  = powerplatform_connection.ai_search_connection.id
#   role_name      = "CanEdit"
#   principal = {
#     entra_object_id = each.value
#   }
# }
