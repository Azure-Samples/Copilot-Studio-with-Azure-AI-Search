# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# DIAGNOSTIC SETTINGS FOR ALL AZURE RESOURCES
# This file centralizes all diagnostic settings to enable comprehensive
# monitoring and logging across the infrastructure when Log Analytics is enabled.
# Only includes resources that actually support Azure Monitor diagnostic settings.

# STORAGE ACCOUNT DIAGNOSTIC SETTINGS

# Enable diagnostic logging for deployment container storage account
resource "azapi_resource" "deployment_container_diagnostics" {
  count = var.include_log_analytics ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "deployment-container-diagnostics"
  parent_id = azurerm_storage_account.deployment_container.id

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      metrics = [
        {
          category = "Transaction"
          enabled  = true
        },
        {
          category = "Capacity"
          enabled  = true
        }
      ]
    }
  }
}

# Enable diagnostic logging for deployment container blob service
resource "azapi_resource" "deployment_container_blob_diagnostics" {
  count = var.include_log_analytics ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "deployment-container-blob-diagnostics"
  parent_id = "${azurerm_storage_account.deployment_container.id}/blobServices/default"

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      logs = [
        {
          category = "StorageRead"
          enabled  = true
        },
        {
          category = "StorageWrite"
          enabled  = true
        },
        {
          category = "StorageDelete"
          enabled  = true
        }
      ]
      metrics = [
        {
          category = "Transaction"
          enabled  = true
        },
        {
          category = "Capacity"
          enabled  = true
        }
      ]
    }
  }
}

# Enable diagnostic logging for deployment container file service (used by Deployment Scripts)
resource "azapi_resource" "deployment_container_file_diagnostics" {
  count = var.include_log_analytics ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "deployment-container-file-diagnostics"
  parent_id = "${azurerm_storage_account.deployment_container.id}/fileServices/default"

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      logs = [
        {
          category = "StorageRead"
          enabled  = true
        },
        {
          category = "StorageWrite"
          enabled  = true
        },
        {
          category = "StorageDelete"
          enabled  = true
        }
      ]
      metrics = [
        {
          category = "Transaction"
          enabled  = true
        },
        {
          category = "Capacity"
          enabled  = true
        }
      ]
    }
  }
}

# Enable diagnostic logging for main storage account
resource "azapi_resource" "main_storage_diagnostics" {
  count = var.include_log_analytics ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "main-storage-diagnostics"
  parent_id = module.storage_account_and_container.resource_id

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      metrics = [
        {
          category = "Transaction"
          enabled  = true
        },
        {
          category = "Capacity"
          enabled  = true
        }
      ]
    }
  }
}

# Enable diagnostic logging for main storage blob service
resource "azapi_resource" "main_storage_blob_diagnostics" {
  count = var.include_log_analytics ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "main-storage-blob-diagnostics"
  parent_id = "${module.storage_account_and_container.resource_id}/blobServices/default"

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      logs = [
        {
          category = "StorageRead"
          enabled  = true
        },
        {
          category = "StorageWrite"
          enabled  = true
        },
        {
          category = "StorageDelete"
          enabled  = true
        }
      ]
      metrics = [
        {
          category = "Transaction"
          enabled  = true
        }
      ]
    }
  }
}

# AI SEARCH SERVICE DIAGNOSTIC SETTINGS

# Enable diagnostic logging for Azure AI Search
resource "azapi_resource" "ai_search_diagnostics" {
  count = var.include_log_analytics ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "ai-search-diagnostics"
  parent_id = azurerm_search_service.ai_search.id

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      logs = [
        {
          category = "OperationLogs"
          enabled  = true
        },
        {
          category = "SearchSlowLog"
          enabled  = true
        }
      ]
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ]
    }
  }
}

# AZURE OPENAI SERVICE DIAGNOSTIC SETTINGS

# Enable diagnostic logging for Azure OpenAI
resource "azapi_resource" "openai_diagnostics" {
  count = var.include_log_analytics ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "openai-diagnostics"
  parent_id = module.azure_open_ai.resource_id

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      logs = [
        {
          category = "Audit"
          enabled  = true
        },
        {
          category = "RequestResponse"
          enabled  = true
        },
        {
          category = "Trace"
          enabled  = true
        }
      ]
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ]
    }
  }
}

# NETWORK SECURITY GROUP DIAGNOSTIC SETTINGS
# Note: VNets and Private Endpoints do not support diagnostic settings.
# NSGs support diagnostic settings for security events and rule counters.

# Enable diagnostic logging for Power Platform primary NSG
resource "azapi_resource" "power_platform_primary_nsg_diagnostics" {
  count = var.include_log_analytics && !local.create_network_infrastructure ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "power-platform-primary-nsg-diagnostics"
  parent_id = azurerm_network_security_group.power_platform_primary_nsg[0].id

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      logs = [
        {
          category = "NetworkSecurityGroupEvent"
          enabled  = true
        },
        {
          category = "NetworkSecurityGroupRuleCounter"
          enabled  = true
        }
      ]
    }
  }
}

# Enable diagnostic logging for Power Platform failover NSG
resource "azapi_resource" "power_platform_failover_nsg_diagnostics" {
  count = var.include_log_analytics && !local.create_network_infrastructure ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "power-platform-failover-nsg-diagnostics"
  parent_id = azurerm_network_security_group.power_platform_failover_nsg[0].id

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      logs = [
        {
          category = "NetworkSecurityGroupEvent"
          enabled  = true
        },
        {
          category = "NetworkSecurityGroupRuleCounter"
          enabled  = true
        }
      ]
    }
  }
}

# Enable diagnostic logging for deployment script NSG
resource "azapi_resource" "deployment_script_nsg_diagnostics" {
  count = var.include_log_analytics && !local.create_network_infrastructure ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "deployment-script-nsg-diagnostics"
  parent_id = azurerm_network_security_group.deployment_script_nsg[0].id

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      logs = [
        {
          category = "NetworkSecurityGroupEvent"
          enabled  = true
        },
        {
          category = "NetworkSecurityGroupRuleCounter"
          enabled  = true
        }
      ]
    }
  }
}

# APPLICATION INSIGHTS DIAGNOSTIC SETTINGS

# Enable diagnostic logging for Application Insights
resource "azapi_resource" "app_insights_diagnostics" {
  count = var.include_app_insights && var.include_log_analytics ? 1 : 0

  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "app-insights-diagnostics"
  parent_id = azurerm_application_insights.insights[0].id

  body = {
    properties = {
      workspaceId = azurerm_log_analytics_workspace.monitoring[0].id
      logs = [
        {
          category = "AppAvailabilityResults"
          enabled  = true
        },
        {
          category = "AppBrowserTimings"
          enabled  = true
        },
        {
          category = "AppEvents"
          enabled  = true
        },
        {
          category = "AppMetrics"
          enabled  = true
        },
        {
          category = "AppDependencies"
          enabled  = true
        },
        {
          category = "AppExceptions"
          enabled  = true
        },
        {
          category = "AppPageViews"
          enabled  = true
        },
        {
          category = "AppPerformanceCounters"
          enabled  = true
        },
        {
          category = "AppRequests"
          enabled  = true
        },
        {
          category = "AppSystemEvents"
          enabled  = true
        },
        {
          category = "AppTraces"
          enabled  = true
        }
      ]
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ]
    }
  }
}