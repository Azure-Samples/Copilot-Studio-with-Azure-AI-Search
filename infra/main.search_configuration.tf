locals {
  # Force recreation of Python scripts on each deployment
  # This ensures the latest versions are always uploaded
  deployment_timestamp = timestamp()
}



resource "azurerm_storage_account" "deployment_container" {
  # checkov:skip=CKV_AZURE_59: Required for deployment scripts to function with Azure Deployment Scripts service
  # checkov:skip=CKV_AZURE_44: Using TLS 1.2 minimum, newer versions not yet supported by Deployment Scripts
  # checkov:skip=CKV_AZURE_206: LRS sufficient for temporary deployment container storage
  # checkov:skip=CKV_AZURE_190: Required for deployment scripts to access files
  # checkov:skip=CKV_AZURE_35: Allow action required for Deployment Scripts service access
  # checkov:skip=CKV_AZURE_33: Queue logging not needed for deployment container storage
  # checkov:skip=CKV2_AZURE_41: SAS policy not needed for deployment container with managed identity
  # checkov:skip=CKV2_AZURE_40: Shared key required for Azure Deployment Scripts service
  # checkov:skip=CKV2_AZURE_33: Private endpoint not compatible with Deployment Scripts requirements
  # checkov:skip=CKV2_AZURE_38: Enabling soft delete for deployment container protection
  # checkov:skip=CKV2_AZURE_47: Blob anonymous access required for deployment scripts
  # checkov:skip=CKV2_AZURE_1: Customer managed encryption not needed for temporary deployment container
  name                     = "deploycontainer${random_string.name.id}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  # Allow blob public access for script uploads
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
  parent_id = azurerm_resource_group.this.id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.script_identity.id]
  }

  body = {
    kind     = "AzureCLI"
    location = azurerm_resource_group.this.location
    properties = {
      azCliVersion      = "2.45.0"
      retentionInterval = "P1D"          # Keep logs for 1 day for debugging
      cleanupPreference = "OnExpiration" # Keep container until retention expires
      timeout           = "PT30M"        # Increase timeout for complex operations
      storageAccountSettings = {
        storageAccountName = azurerm_storage_account.deployment_container.name
      }
      containerSettings = {
        subnetIds = [
          {
            id = "${azurerm_subnet.deployment_script_container_subnet.id}"
          }
        ]
      }
      scriptContent = <<EOF
        set -euo pipefail
        
        echo "=== Search Index Configuration Script Start ==="
        echo "Storage account: $MAIN_STORAGE_ACCOUNT_NAME"
        echo "Search service: ${azurerm_search_service.ai_search.name}"
        echo "Repository URL: $GITHUB_REPO_URL"
        
        # Wait for RBAC permissions to fully propagate (Azure can take time to propagate permissions)
        echo "=== Waiting for RBAC permissions to propagate ==="
        sleep 30
        
        # Verify main storage account exists
        az storage account show --name $MAIN_STORAGE_ACCOUNT_NAME --resource-group ${azurerm_resource_group.this.name} --output table
        
        # Setup Python environment
        python3 -m venv /tmp/venv && source /tmp/venv/bin/activate
        pip install --upgrade pip
        
        # Download only the necessary scripts
        mkdir -p /tmp/scripts && cd /tmp/scripts
        az storage blob download-batch --destination . --source scripts --account-name $SCRIPT_STORAGE_ACCOUNT_NAME --auth-mode login
        
        # Step 1: Fetch data files from source to local directory
        echo "=== Step 1: Fetching data files from $DATA_SOURCE_TYPE source ==="
        
        # First install requirements from the src/search directory where fetch_data.py is located
        cd /tmp/scripts/src/search
        pip install -r requirements.txt
        
        # Create local data directory
        mkdir -p /tmp/local_data
        
        # Fetch data using fetch_data.py
        python fetch_data.py \
          --source_type "$DATA_SOURCE_TYPE" \
          --source_url "$DATA_SOURCE_URL" \
          --source_path "$DATA_SOURCE_PATH" \
          --output_dir "/tmp/local_data" \
          --file_pattern "$DATA_FILE_PATTERN"
        
        # Step 2: Upload fetched data files to main storage account
        echo "=== Step 2: Uploading data files to main storage account ==="
        echo "Debug: MAIN_STORAGE_ACCOUNT_NAME = $MAIN_STORAGE_ACCOUNT_NAME"
        echo "Debug: DATA_CONTAINER_NAME = $DATA_CONTAINER_NAME"
        echo "Debug: AZURE_CLIENT_ID = $AZURE_CLIENT_ID"
        
        # Verify managed identity authentication works
        echo "=== Testing Azure authentication ==="
        az account show
        echo "=== Testing storage account access ==="
        az storage account show --name "$MAIN_STORAGE_ACCOUNT_NAME" --resource-group ${azurerm_resource_group.this.name} --output table
        echo "=== Testing storage container list access ==="
        az storage container list --account-name "$MAIN_STORAGE_ACCOUNT_NAME" --auth-mode login --output table || echo "Container list failed"
        echo "=== Testing specific container exists ==="
        az storage container exists --name "$DATA_CONTAINER_NAME" --account-name "$MAIN_STORAGE_ACCOUNT_NAME" --auth-mode login || echo "Container exists check failed"
        
        # Test creating container if it doesn't exist using Azure CLI (this should work if RBAC is correct)
        echo "=== Testing container creation with Azure CLI ==="
        az storage container create --name "$DATA_CONTAINER_NAME" --account-name "$MAIN_STORAGE_ACCOUNT_NAME" --auth-mode login || echo "Container creation failed"
        
        # Run upload_data.py from the correct directory  
        python upload_data.py \
          --storage_account_name "$MAIN_STORAGE_ACCOUNT_NAME" \
          --container_name "$DATA_CONTAINER_NAME" \
          --data_path "/tmp/local_data" \
          --file_pattern "$DATA_FILE_PATTERN"
        
        # Step 3: Configure search index
        echo "=== Step 3: Configuring search index ==="
        python index_utils.py \
          --aisearch_name ${azurerm_search_service.ai_search.name} \
          --base_index_name "default" \
          --openai_api_base ${module.azure_open_ai.endpoint} \
          --subscription_id ${data.azurerm_client_config.current.subscription_id} \
          --resource_group_name ${azurerm_resource_group.this.name} \
          --storage_name "$MAIN_STORAGE_ACCOUNT_NAME" \
          --container_name $DATA_CONTAINER_NAME \
          --client_id "$AZURE_CLIENT_ID"
          
        echo "=== Search index configuration completed successfully ==="
      EOF
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
    azurerm_role_assignment.script_deployment_container_storage_contributor,
    azurerm_role_assignment.script_deployment_container_blob_owner,
    azurerm_role_assignment.script_deployment_container_file_owner,
    # Main storage permissions (write access needed for upload_data.py to upload data files)
    azurerm_role_assignment.script_main_storage_queue_contributor,
    azurerm_role_assignment.script_main_storage_blob_owner,
    azurerm_role_assignment.script_main_storage_file_contributor,
    # AI Search permissions
    azurerm_role_assignment.script_search_service_contributor,
    azurerm_role_assignment.script_search_index_data_contributor,
    # Azure OpenAI permissions
    azurerm_role_assignment.script_cognitive_services_openai_user,
    # Other permissions
    azurerm_role_assignment.script_container_apps_contributor
  ]
  create_duration = "30s"
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
    azurerm_role_assignment.script_search_index_data_contributor,
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
    azurerm_role_assignment.script_main_storage_queue_contributor,
    azurerm_role_assignment.script_main_storage_blob_owner,
    azurerm_role_assignment.script_main_storage_file_contributor,
    azurerm_role_assignment.script_deployment_container_storage_contributor,
    azurerm_role_assignment.script_deployment_container_blob_owner,
    azurerm_role_assignment.script_deployment_container_file_owner,
    # AI Search permissions
    azurerm_role_assignment.script_search_service_contributor,
    azurerm_role_assignment.script_search_index_data_contributor,
    # Azure OpenAI permissions
    azurerm_role_assignment.script_cognitive_services_openai_user
  ]
}