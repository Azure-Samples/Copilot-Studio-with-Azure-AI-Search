# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

locals {
  # Force recreation of Python scripts on each deployment
  # This ensures the latest versions are always uploaded
  deployment_timestamp = timestamp()
}

resource "azurerm_storage_account" "deployment_container" {
  # checkov:skip=CKV_AZURE_59: Public network access required - Deployment Scripts service accesses storage over public endpoint with managed identity auth
  # checkov:skip=CKV_AZURE_206: LRS sufficient for temporary deployment artifacts - data has 24-hour retention and is not business-critical
  # checkov:skip=CKV_AZURE_35: Network default action 'Allow' required - Deployment Scripts service does not support storage firewall restrictions per Azure docs
  # checkov:skip=CKV_AZURE_33: Queue service logging not applicable - deployment container only uses Blob and File storage services
  # checkov:skip=CKV2_AZURE_41: SAS expiration policy not applicable - using managed identity RBAC authentication instead of SAS tokens
  # checkov:skip=CKV2_AZURE_40: Shared key access required - Azure Container Instances can only mount file shares via storage account keys per platform limitation
  # checkov:skip=CKV2_AZURE_33: Private endpoint not required - public network access with managed identity auth is deployment scripts architecture pattern
  # checkov:skip=CKV2_AZURE_1: Customer-managed key encryption not required - temporary deployment artifacts with 24-hour retention, platform-managed keys sufficient
  name                     = azurecaf_name.deployment_script_names.results["azurerm_storage_account"]
  resource_group_name      = local.resource_group_name
  location                 = local.primary_azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  # Disable anonymous blob access - deployment scripts authenticate via managed identity
  allow_nested_items_to_be_public = false
  # Ensure public network access is enabled for deployment scripts
  public_network_access_enabled = true
  tags                          = var.tags

  # Explicit network rules with proper bypass for Azure services
  # This ensures Azure Deployment Scripts can access the storage account
  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  # Enable soft delete for blob protection and recovery
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  # Ensure subnet timing is handled for main storage account dependencies
  depends_on = [
    time_sleep.wait_for_subnets
  ]
}

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

# Enable diagnostic logging for blob service
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

# Enable diagnostic logging for file service (used by Deployment Scripts)
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

# Force recreation of Python scripts on each deployment
resource "terraform_data" "force_script_update" {
  input = local.deployment_timestamp
}

resource "azapi_resource" "configure_search_index" {

  # Ensure all script files are uploaded and RBAC is fully propagated before running
  depends_on = [
    azurerm_storage_blob.upload_data_script,
    azurerm_storage_blob.fetch_data_script,
    azurerm_storage_blob.data_requirements,
    azurerm_storage_blob.search_index_utils,
    azurerm_storage_blob.search_common_utils,
    azurerm_storage_blob.document_data_source,
    azurerm_storage_blob.document_index,
    azurerm_storage_blob.document_indexer,
    azurerm_storage_blob.document_skillset,
    null_resource.verify_rbac_propagation,
    time_sleep.wait_for_storage_network,
    time_sleep.wait_for_search_permissions, # Wait for Search Service permissions
    azurerm_storage_account.deployment_container,
    module.storage_account_and_container,
    module.azure_open_ai
  ]

  type      = "Microsoft.Resources/deploymentScripts@2023-08-01"
  name      = "configure-search-index"
  parent_id = local.use_existing_resource_group ? data.azurerm_resource_group.existing[0].id : azurerm_resource_group.this[0].id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.script_identity.id]
  }

  body = {
    kind     = "AzureCLI"
    location = local.primary_azure_region
    properties = {
      azCliVersion      = "2.45.0"
      forceUpdateTag    = local.deployment_timestamp
      retentionInterval = "PT24H"        # Retain script artifacts for 24 hours (max supported)
      cleanupPreference = "OnExpiration" # Keep artifacts for the retention window regardless of outcome
      timeout           = "PT30M"        # Increase timeout for complex operations
      storageAccountSettings = {
        storageAccountName = azurerm_storage_account.deployment_container.name
      }
      containerSettings = {
        subnetIds = [
          {
            id = "${local.deployment_script_container_subnet_id}"
          }
        ]
      }
      scriptContent = file("${path.module}/scripts/configure-search-index.sh")
      environmentVariables = [
        {
          name  = "SCRIPT_STORAGE_ACCOUNT_NAME"
          value = "${azurerm_storage_account.deployment_container.name}"
        },
        {
          name  = "MAIN_STORAGE_ACCOUNT_NAME"
          value = "${module.storage_account_and_container.name}"
        },
        {
          name  = "DATA_CONTAINER_NAME"
          value = "${var.cps_container_name}"
        },
        {
          name  = "AZURE_CLIENT_ID"
          value = "${azurerm_user_assigned_identity.script_identity.client_id}"
        },
        {
          name  = "DATA_SOURCE_TYPE"
          value = var.data_source_type
        },
        {
          name  = "DATA_SOURCE_URL"
          value = var.data_source_url
        },
        {
          name  = "DATA_SOURCE_PATH"
          value = var.data_source_path
        },
        {
          name  = "DATA_FILE_PATTERN"
          value = var.data_file_pattern
        },
        {
          name  = "GITHUB_REPO_URL"
          value = var.data_source_url
        },
        {
          name  = "SEARCH_SERVICE_NAME"
          value = "${azurerm_search_service.ai_search.name}"
        },
        {
          name  = "RESOURCE_GROUP_NAME"
          value = "${local.resource_group_name}"
        },
        {
          name  = "BASE_INDEX_NAME"
          value = "${var.ai_search_base_index_name}"
        },
        {
          name  = "OPENAI_ENDPOINT"
          value = "${module.azure_open_ai.endpoint}"
        },
        {
          name  = "SUBSCRIPTION_ID"
          value = "${data.azurerm_client_config.current.subscription_id}"
        }
      ]
    }
  }
}

# Time sleep to allow all RBAC assignments to propagate before blob operations
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    # Terraform storage access
    azurerm_role_assignment.terraform_deployment_container_storage_access,
    azurerm_role_assignment.terraform_deployment_container_file_access,
    # Script identity storage permissions
    azurerm_role_assignment.script_deployment_container_blob_contributor,
    azurerm_role_assignment.script_deployment_container_file_contributor,
    # Main storage permissions (write access needed for upload_data.py to upload data files)
    azurerm_role_assignment.script_main_storage_blob_contributor,
    # AI Search permissions
    azurerm_role_assignment.script_search_service_contributor,
    # Azure OpenAI permissions
    azurerm_role_assignment.script_cognitive_services_openai_user,
  ]
  create_duration = "60s"
}

# Additional time sleep for storage account to be fully ready for network access
resource "time_sleep" "wait_for_storage_network" {
  depends_on = [
    azurerm_storage_account.deployment_container,
    time_sleep.wait_for_rbac
  ]
  create_duration = "30s"
}

# Additional wait specifically for Search Service permissions to propagate
resource "time_sleep" "wait_for_search_permissions" {
  depends_on = [
    azurerm_role_assignment.script_search_service_contributor,
    # azurerm_role_assignment.script_search_index_data_contributor,
    time_sleep.wait_for_rbac
  ]
  create_duration = "30s"
}

# Upload scripts to storage for deployment script execution
resource "azurerm_storage_container" "scripts" {
  # checkov:skip=CKV_AZURE_34: Blob access required for deployment scripts to download files
  # checkov:skip=CKV2_AZURE_21: Logging not needed for temporary deployment scripts container
  name                  = "scripts"
  storage_account_id    = azurerm_storage_account.deployment_container.id
  container_access_type = "private"

  depends_on = [
    azurerm_storage_account.deployment_container,
    time_sleep.wait_for_rbac # Ensure RBAC is ready for script execution
  ]
}

# Upload data directory files
resource "azurerm_storage_blob" "upload_data_script" {
  name                   = "src/search/upload_data.py"
  storage_account_name   = azurerm_storage_account.deployment_container.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../src/search/upload_data.py"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]

  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

resource "azurerm_storage_blob" "fetch_data_script" {
  name                   = "src/search/fetch_data.py"
  storage_account_name   = azurerm_storage_account.deployment_container.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../src/search/fetch_data.py"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]

  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

resource "azurerm_storage_blob" "data_requirements" {
  name                   = "src/search/requirements.txt"
  storage_account_name   = azurerm_storage_account.deployment_container.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../src/search/requirements.txt"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]

  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

resource "azurerm_storage_blob" "search_index_utils" {
  name                   = "src/search/index_utils.py"
  storage_account_name   = azurerm_storage_account.deployment_container.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../src/search/index_utils.py"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]

  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

resource "azurerm_storage_blob" "search_common_utils" {
  name                   = "src/search/common_utils.py"
  storage_account_name   = azurerm_storage_account.deployment_container.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../src/search/common_utils.py"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]

  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

# Upload index configuration files
resource "azurerm_storage_blob" "document_data_source" {
  name                   = "src/search/index_config/documentDataSource.json"
  storage_account_name   = azurerm_storage_account.deployment_container.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../src/search/index_config/documentDataSource.json"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]

  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

resource "azurerm_storage_blob" "document_index" {
  name                   = "src/search/index_config/documentIndex.json"
  storage_account_name   = azurerm_storage_account.deployment_container.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../src/search/index_config/documentIndex.json"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]

  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

resource "azurerm_storage_blob" "document_indexer" {
  name                   = "src/search/index_config/documentIndexer.json"
  storage_account_name   = azurerm_storage_account.deployment_container.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../src/search/index_config/documentIndexer.json"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]

  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

resource "azurerm_storage_blob" "document_skillset" {
  name                   = "src/search/index_config/documentSkillSet.json"
  storage_account_name   = azurerm_storage_account.deployment_container.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../src/search/index_config/documentSkillSet.json"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]

  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

# Null resource to verify RBAC propagation before script execution
resource "null_resource" "verify_rbac_propagation" {
  depends_on = [
    time_sleep.wait_for_rbac,
    # Storage permissions
    azurerm_role_assignment.script_main_storage_reader,
    azurerm_role_assignment.script_main_storage_blob_contributor,
    azurerm_role_assignment.script_deployment_container_blob_contributor,
    azurerm_role_assignment.script_deployment_container_file_contributor,
    # AI Search permissions
    azurerm_role_assignment.script_search_service_contributor,
    # Azure OpenAI permissions
    azurerm_role_assignment.script_cognitive_services_openai_user
  ]
}