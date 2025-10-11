resource "random_uuid" "uid" {}

resource "azurerm_log_analytics_workspace" "monitoring" {
  count = var.include_log_analytics ? 1 : 0

  daily_quota_gb      = -1
  location            = local.primary_azure_region
  name                = azurecaf_name.main_names.results["azurerm_log_analytics_workspace"]
  resource_group_name = local.resource_group_name
  retention_in_days   = var.log_analytics_retention_in_days
  sku                 = "PerGB2018"
  tags                = var.tags
}

resource "azurerm_application_insights" "insights" {
  count = var.include_app_insights ? 1 : 0

  application_type    = "web"
  location            = local.primary_azure_region
  name                = "${var.resource_prefix}-appinsights-${var.resource_suffix}"
  resource_group_name = local.resource_group_name
}

resource "azurerm_application_insights_workbook" "workbook" {
  count = var.include_app_insights ? 1 : 0

  data_json = jsonencode({
    "version" : "Notebook/1.0",
    "items" : [
      {
        "type" : 1,
        "content" : {
          "json" : var.app_insights_workbook_description,
          "style" : "info"
        },
        "name" : "Notebook description"
      },
      {
        "type" : 3,
        "content" : {
          "version" : "KqlItem/1.0",
          "query" : var.app_insights_sections["section_1"].query,
          "size" : 0,
          "timeContext" : {
            "durationMs" : 1800000
          },
          "queryType" : 0,
          "resourceType" : "microsoft.insights/components",
          "crossComponentResources" : [
            "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.resource_group_name}/providers/Microsoft.Insights/components/${azurerm_application_insights.insights[0].name}"
          ],
          "visualization" : var.app_insights_sections["section_1"].chart
        },
        "name" : var.app_insights_sections["section_1"].name
      },
      {
        "type" : 3,
        "content" : {
          "version" : "KqlItem/1.0",
          "query" : var.app_insights_sections["section_2"].query,
          "size" : 0,
          "timeContext" : {
            "durationMs" : 1800000
          },
          "queryType" : 0,
          "resourceType" : "microsoft.insights/components",
          "crossComponentResources" : [
            "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.resource_group_name}/providers/Microsoft.Insights/components/${azurerm_application_insights.insights[0].name}"
          ],
          "visualization" : var.app_insights_sections["section_2"].chart
        },
        "name" : var.app_insights_sections["section_2"].name
      },
      {
        "type" : 3,
        "content" : {
          "version" : "KqlItem/1.0",
          "query" : var.app_insights_sections["section_3"].query,
          "size" : 0,
          "timeContext" : {
            "durationMs" : 1800000
          },
          "queryType" : 0,
          "resourceType" : "microsoft.insights/components",
          "crossComponentResources" : [
            "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.resource_group_name}/providers/Microsoft.Insights/components/${azurerm_application_insights.insights[0].name}"
          ],
          "visualization" : var.app_insights_sections["section_3"].chart
        },
        "name" : var.app_insights_sections["section_3"].name
      },
      {
        "type" : 3,
        "content" : {
          "version" : "KqlItem/1.0",
          "query" : var.app_insights_sections["section_4"].query,
          "size" : 0,
          "timeContext" : {
            "durationMs" : 1800000
          },
          "queryType" : 0,
          "resourceType" : "microsoft.insights/components",
          "crossComponentResources" : [
            "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.resource_group_name}/providers/Microsoft.Insights/components/${azurerm_application_insights.insights[0].name}"
          ],
          "visualization" : var.app_insights_sections["section_4"].chart
        },
        "name" : var.app_insights_sections["section_4"].name
      },
      {
        "type" : 3,
        "content" : {
          "version" : "KqlItem/1.0",
          "query" : var.app_insights_sections["section_5"].query,
          "size" : 0,
          "timeContext" : {
            "durationMs" : 1800000
          },
          "queryType" : 0,
          "resourceType" : "microsoft.insights/components",
          "crossComponentResources" : [
            "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.resource_group_name}/providers/Microsoft.Insights/components/${azurerm_application_insights.insights[0].name}"
          ],
          "visualization" : var.app_insights_sections["section_5"].chart
        },
        "name" : var.app_insights_sections["section_5"].name
      },
      {
        "type" : 3,
        "content" : {
          "version" : "KqlItem/1.0",
          "query" : var.app_insights_sections["section_6"].query,
          "size" : 0,
          "timeContext" : {
            "durationMs" : 1800000
          },
          "queryType" : 0,
          "resourceType" : "microsoft.insights/components",
          "crossComponentResources" : [
            "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.resource_group_name}/providers/Microsoft.Insights/components/${azurerm_application_insights.insights[0].name}"
          ],
          "visualization" : var.app_insights_sections["section_6"].chart
        },
        "name" : var.app_insights_sections["section_6"].name
      }
    ],
    "fallbackResourceIds" : [
      "azure monitor"
    ],
    "$schema" : "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
  })
  display_name        = "Azure Monitor Workbook"
  location            = local.primary_azure_region
  name                = random_uuid.uid.result
  resource_group_name = local.resource_group_name
}
