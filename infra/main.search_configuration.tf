locals {
  # Dynamically discover all PDF files in the data directory
  data_pdf_files = fileset("${path.root}/../data", "*.pdf")
  
  # Create a map of PDF files for for_each
  pdf_files_map = {
    for pdf_file in local.data_pdf_files : 
    replace(pdf_file, ".pdf", "") => pdf_file
  }
  
  # Force recreation of Python scripts on each deployment
  # This ensures the latest versions are always uploaded
  deployment_timestamp = timestamp()
}

resource "azurerm_storage_account" "deployment_scripts" {
  name                     = "deploy${random_string.name.id}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  # Allow blob public access for script uploads
  allow_nested_items_to_be_public = true
  # Ensure public network access is enabled for deployment scripts
  public_network_access_enabled = true
  # Enable shared key access for deployment scripts
  shared_access_key_enabled      = true
  tags = var.tags

  # Explicit network rules with proper bypass for Azure services
  # This ensures Azure Deployment Scripts can access the storage account
  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  # Ensure subnet timing is handled for main storage account dependencies
  depends_on = [
    time_sleep.wait_for_subnets
  ]
}

resource "azurerm_storage_account" "deployment_container" {
  name                     = "deploycontainer${random_string.name.id}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  # Allow blob public access for script uploads
  allow_nested_items_to_be_public = true
  # Ensure public network access is enabled for deployment scripts
  public_network_access_enabled = true
  # Enable shared key access for deployment scripts
  shared_access_key_enabled      = true
  tags = var.tags

  # Explicit network rules with proper bypass for Azure services
  # This ensures Azure Deployment Scripts can access the storage account
  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices", "Logging", "Metrics"]
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

resource "azapi_resource" "run_python_from_storage" {
  
  # Ensure all script files are uploaded and RBAC is fully propagated before running
  depends_on = [
    azurerm_storage_blob.data_requirements,
    azurerm_storage_blob.data_upload_script,
    azurerm_storage_blob.search_requirements,
    azurerm_storage_blob.search_index_utils,
    azurerm_storage_blob.search_common_utils,
    azurerm_storage_blob.document_data_source,
    azurerm_storage_blob.document_index,
    azurerm_storage_blob.document_indexer,
    azurerm_storage_blob.document_skillset,
    azurerm_storage_blob.pdf_data_files,  # PDF files
    null_resource.verify_rbac_propagation,
    time_sleep.wait_for_storage_network,
    time_sleep.wait_for_search_permissions,  # Wait for Search Service permissions
    azurerm_storage_account.deployment_scripts,
    azurerm_storage_account.deployment_container,
    module.storage_account_and_container,
  ]

  type = "Microsoft.Resources/deploymentScripts@2023-08-01"
  name = "run-python-from-github"
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
            id = "${azurerm_subnet.deployment_script_container.id}"
          }
        ]
      }
      scriptContent = <<EOF
        set -euo pipefail
        
        echo "=== Deployment Script Start ==="
        echo "Storage accounts: $MAIN_STORAGE_ACCOUNT_NAME, $SCRIPT_STORAGE_ACCOUNT_NAME"
        
        # Verify storage accounts exist
        az storage account show --name $MAIN_STORAGE_ACCOUNT_NAME --resource-group ${azurerm_resource_group.this.name} --output table
        az storage account show --name $SCRIPT_STORAGE_ACCOUNT_NAME --resource-group ${azurerm_resource_group.this.name} --output table
        
        # Setup Python environment
        python3 -m venv /tmp/venv && source /tmp/venv/bin/activate
        pip install --upgrade pip
        
        # Download scripts and data
        mkdir -p /tmp/scripts && cd /tmp/scripts
        az storage blob download-batch --destination . --source scripts --account-name $SCRIPT_STORAGE_ACCOUNT_NAME --auth-mode login
        
        # Upload data files
        cd data
        pip install -r requirements.txt
        python upload_data.py --storage_name $MAIN_STORAGE_ACCOUNT_NAME --container_name $DATA_CONTAINER_NAME
        
        # Configure search index
        cd ../src/search
        pip install -r requirements.txt
        python index_utils.py \
          --aisearch_name ${azurerm_search_service.ai_search.name} \
          --base_index_name "default-index" \
          --openai_api_base ${module.azure_open_ai.endpoint} \
          --subscription_id ${data.azurerm_client_config.current.subscription_id} \
          --resource_group_name ${azurerm_resource_group.this.name} \
          --storage_name "$MAIN_STORAGE_ACCOUNT_NAME" \
          --container_name $DATA_CONTAINER_NAME \
          --aisearch_key "$AI_SEARCH_ADMIN_KEY"
          
        echo "=== Deployment script completed successfully ==="
      EOF
      environmentVariables = [
        {
          name  = "SCRIPT_STORAGE_ACCOUNT_NAME"
          value = "${azurerm_storage_account.deployment_scripts.name}"
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
          name  = "AI_SEARCH_ADMIN_KEY"
          value = "${azurerm_search_service.ai_search.primary_key}"
        }
      ]
    }
  }
}

# Time sleep to allow all RBAC assignments to propagate before blob operations
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    # Terraform storage access
    azurerm_role_assignment.terraform_deployment_scripts_file_access,
    azurerm_role_assignment.terraform_deployment_container_storage_access,
    azurerm_role_assignment.terraform_deployment_container_file_access,
    # Script identity storage permissions
    azurerm_role_assignment.script_deployment_scripts_storage_owner,
    azurerm_role_assignment.script_deployment_scripts_blob_owner,
    azurerm_role_assignment.script_deployment_scripts_file_owner,
    azurerm_role_assignment.script_deployment_container_storage_owner,
    azurerm_role_assignment.script_deployment_container_blob_owner,
    azurerm_role_assignment.script_deployment_container_file_owner,
    # Main storage permissions
    azurerm_role_assignment.script_main_storage_blob_contributor,
    azurerm_role_assignment.script_main_storage_file_contributor,
    azurerm_role_assignment.script_main_storage_reader,
    # AI Search permissions
    azurerm_role_assignment.script_search_service_contributor,
    azurerm_role_assignment.script_search_index_data_contributor,
    azurerm_role_assignment.script_search_index_data_reader,
    # Azure OpenAI permissions
    azurerm_role_assignment.script_cognitive_services_openai_user,
    azurerm_role_assignment.script_cognitive_services_contributor,
    # Other permissions
    azurerm_role_assignment.script_container_apps_contributor
  ]
  create_duration = "180s" # Increased to 3 minutes for better propagation of all roles including Search Service
}

# Additional time sleep for storage account to be fully ready for network access
resource "time_sleep" "wait_for_storage_network" {
  depends_on = [
    azurerm_storage_account.deployment_scripts,
    time_sleep.wait_for_rbac
  ]
  create_duration = "30s"
}

# Additional wait specifically for Search Service permissions to propagate
resource "time_sleep" "wait_for_search_permissions" {
  depends_on = [
    azurerm_role_assignment.script_search_service_contributor,
    azurerm_role_assignment.script_search_index_data_contributor,
    azurerm_role_assignment.script_search_index_data_reader,
    time_sleep.wait_for_rbac
  ]
  create_duration = "60s" # Extra wait for Search Service permissions
}

# Upload scripts to storage for deployment script execution
resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_id    = azurerm_storage_account.deployment_scripts.id
  container_access_type = "blob"

  depends_on = [
    azurerm_storage_account.deployment_scripts,
    time_sleep.wait_for_rbac  # Ensure RBAC is ready for script execution
  ]
}

# Upload data directory files
resource "azurerm_storage_blob" "data_requirements" {
  name                   = "data/requirements.txt"
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../data/requirements.txt"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac  # Only need RBAC propagation for script execution
  ]
  
  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

resource "azurerm_storage_blob" "data_upload_script" {
  name                   = "data/upload_data.py"
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../data/upload_data.py"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]
  
  # Force recreation on each deployment to ensure latest version
  lifecycle {
    replace_triggered_by = [terraform_data.force_script_update]
  }
}

# Upload src/search directory files
resource "azurerm_storage_blob" "search_requirements" {
  name                   = "src/search/requirements.txt"
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
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
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
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
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
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
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
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
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
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
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
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
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
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

# Upload all PDF data files to deployment script storage dynamically
resource "azurerm_storage_blob" "pdf_data_files" {
  for_each = local.pdf_files_map
  
  name                   = "data/${each.value}"
  storage_account_name   = azurerm_storage_account.deployment_scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.root}/../data/${each.value}"

  depends_on = [
    azurerm_storage_container.scripts,
    time_sleep.wait_for_rbac
  ]
}

# Null resource to verify RBAC propagation before script execution
resource "null_resource" "verify_rbac_propagation" {
  depends_on = [
    time_sleep.wait_for_rbac,
    # Storage permissions
    azurerm_role_assignment.script_main_storage_blob_contributor,
    azurerm_role_assignment.script_main_storage_file_contributor,
    azurerm_role_assignment.script_main_storage_reader,
    azurerm_role_assignment.script_deployment_scripts_storage_owner,
    azurerm_role_assignment.script_deployment_scripts_blob_owner,
    azurerm_role_assignment.script_deployment_scripts_file_owner,
    azurerm_role_assignment.script_deployment_container_storage_owner,
    azurerm_role_assignment.script_deployment_container_blob_owner,
    azurerm_role_assignment.script_deployment_container_file_owner,
    # AI Search permissions
    azurerm_role_assignment.script_search_service_contributor,
    azurerm_role_assignment.script_search_index_data_contributor,
    azurerm_role_assignment.script_search_index_data_reader,
    # Azure OpenAI permissions
    azurerm_role_assignment.script_cognitive_services_openai_user,
    azurerm_role_assignment.script_cognitive_services_contributor
  ]

  # Use local-exec to test storage access with the managed identity
  provisioner "local-exec" {
    command = <<EOF
      echo "Verifying RBAC propagation for script identity..."
      # Test will be done within the deployment script itself
      echo "RBAC verification placeholder completed"
    EOF
  }

  # Trigger re-run if any role assignments change
  triggers = {
    script_identity_id = azurerm_user_assigned_identity.script_identity.principal_id
    storage_account_id = module.storage_account_and_container.resource_id
    deployment_storage_id = azurerm_storage_account.deployment_scripts.id
  }
}