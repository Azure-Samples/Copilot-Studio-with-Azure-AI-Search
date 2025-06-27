resource "azurerm_storage_account" "deployment_scripts" {
  name                     = "deploy${random_string.name.id}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Allow blob public access for script uploads
  allow_nested_items_to_be_public = true
  
  # Configure network rules to allow Azure trusted services
  network_rules {
    default_action             = "Allow"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.primary_subnet.id]
  }
  
  tags = var.tags
}

resource "azapi_resource" "run_python_from_storage" {
  type = "Microsoft.Resources/deploymentScripts@2023-08-01"
  name                = "run-python-from-github"
  //location            = azurerm_resource_group.this.location
  parent_id           = azurerm_resource_group.this.id
  
  # Ensure all script files are uploaded before running
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
    azurerm_role_assignment.script_deployment_storage_access,
  ]
  
identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.script_identity.id]
  }
  body = {
    kind = "AzureCLI"
    location= azurerm_resource_group.this.location
    properties = {
      azCliVersion = "2.45.0"
      retentionInterval  = "P1D"
      cleanupPreference = "OnSuccess"
      timeout            = "PT15M"
      storageAccountSettings = {
        storageAccountName = azurerm_storage_account.deployment_scripts.name
      }
      containerSettings = {
        subnetIds = [
          {
            id = "${azurerm_subnet.primary_subnet.id}"
          }
        ]
      }
      scriptContent = <<EOF
        set -e  # Exit on any error
        
        echo "Starting deployment script..."
        
        # Upgrade pip first to avoid version conflicts
        echo "Upgrading pip..."
        pip install --upgrade pip
        
        echo "Downloading scripts and dependencies from storage..."
        
        # Create working directory
        mkdir -p /tmp/scripts
        cd /tmp/scripts
        
        # Download data upload files
        echo "Downloading data upload files..."
        az storage blob download-batch \
          --destination ./data \
          --source scripts \
          --pattern "data/*" \
          --account-name $STORAGE_ACCOUNT_NAME \
          --auth-mode login
        
        # Download search configuration files  
        echo "Downloading search configuration files..."
        az storage blob download-batch \
          --destination ./src/search \
          --source scripts \
          --pattern "src/search/*" \
          --account-name $STORAGE_ACCOUNT_NAME \
          --auth-mode login
        
        echo "Installing data upload dependencies..."
        cd data
        pip install -r requirements.txt
        
        echo "Uploading data files to storage..."
        python upload_data.py --storage_name $MAIN_STORAGE_ACCOUNT_NAME --container_name $DATA_CONTAINER_NAME
        
        echo "Moving to search directory..."
        cd ../src/search
        
        echo "Installing search dependencies..."
        pip install -r requirements.txt
        
        echo "Running search index configuration..."
        python index_utils.py \
          --aisearch_name ${azurerm_search_service.ai_search.name} \
          --base_index_name "default-index" \
          --openai_api_base ${module.azure_open_ai.endpoint} \
          --subscription_id ${data.azurerm_client_config.current.subscription_id} \
          --resource_group_name ${azurerm_resource_group.this.name} \
          --storage_name $MAIN_STORAGE_ACCOUNT_NAME \
          --container_name $DATA_CONTAINER_NAME
          
        echo "Deployment script completed successfully!"
      EOF
      environmentVariables = [
        {
          name = "STORAGE_ACCOUNT_NAME"
          value = "${azurerm_storage_account.deployment_scripts.name}"
        },
        {
          name = "MAIN_STORAGE_ACCOUNT_NAME"
          value = "${module.storage_account_and_container.name}"
        },
        {
          name = "DATA_CONTAINER_NAME"
          value = "${var.cps_container_name}"
        }
      ]  
    }
  }
}

# Role assignment to allow Terraform to upload blobs
resource "azurerm_role_assignment" "terraform_storage_access" {
  scope                = azurerm_storage_account.deployment_scripts.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Time sleep to allow role assignment to propagate
resource "time_sleep" "wait_for_rbac" {
  depends_on = [azurerm_role_assignment.terraform_storage_access]
  create_duration = "30s"
}

# Role assignments for the script identity to access both storage accounts
resource "azurerm_role_assignment" "script_deployment_storage_access" {
  scope                = azurerm_storage_account.deployment_scripts.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}

# Upload scripts to storage for deployment script execution
resource "azurerm_storage_container" "scripts" {
  name                 = "scripts"
  storage_account_id   = azurerm_storage_account.deployment_scripts.id
  container_access_type = "blob"
  
  depends_on = [
    azurerm_storage_account.deployment_scripts,
    time_sleep.wait_for_rbac
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
    time_sleep.wait_for_rbac
  ]
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
}