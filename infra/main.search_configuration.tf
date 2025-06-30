locals {
  # Dynamically discover all PDF files in the data directory
  data_pdf_files = fileset("${path.root}/../data", "*.pdf")
  
  # Create a map of PDF files for for_each
  pdf_files_map = {
    for pdf_file in local.data_pdf_files : 
    replace(pdf_file, ".pdf", "") => pdf_file
  }
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
  tags = var.tags

  # Explicit network rules with proper bypass for Azure services
  # This ensures Azure Deployment Scripts can access the storage account
  network_rules {
    default_action = "Allow"  # Allow by default - no firewall restrictions
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  # Ensure subnet timing is handled for main storage account dependencies
  depends_on = [
    time_sleep.wait_for_subnets
  ]
}

resource "azapi_resource" "run_python_from_storage" {
  type = "Microsoft.Resources/deploymentScripts@2023-08-01"
  name = "run-python-from-github"
  //location            = azurerm_resource_group.this.location
  parent_id = azurerm_resource_group.this.id

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
    null_resource.verify_rbac_propagation,
    time_sleep.wait_for_storage_network,
    module.storage_account_and_container, # Ensure main storage is ready
  ]

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
      # Let Azure Deployment Scripts create its own managed storage account
      # This avoids network rule conflicts with subnet configurations
      # The script will use managed identity and RBAC to access both storage accounts
      scriptContent = <<EOF
        set -euo pipefail  # Exit on any error, undefined variables, and pipe failures
        
        echo "=== Deployment Script Start: $(date) ==="
        echo "Script execution ID: $AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY"
        echo "Container hostname: $(hostname)"
        echo "Working directory: $(pwd)"
        echo "Current user: $(whoami)"
        
        # Enhanced logging of environment
        echo "=== Environment Variables ==="
        env | grep -E "(AZURE_|STORAGE_|MAIN_)" | sort || echo "No relevant environment variables found"
        echo "=== End Environment ==="
        
        # Test storage access early to verify RBAC propagation
        echo "=== Testing Storage Access ==="
        echo "Testing access to main storage account..."
        
        # Test with retries to handle RBAC propagation delays
        max_retries=5
        retry_count=0
        while [ $retry_count -lt $max_retries ]; do
          if az storage container list --account-name $MAIN_STORAGE_ACCOUNT_NAME --auth-mode login --output table; then
            echo "Main storage account access successful on attempt $((retry_count + 1))"
            break
          else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
              wait_time=$((retry_count * 30))
              echo "Main storage account access failed on attempt $retry_count. Retrying in $wait_time seconds..."
              sleep $wait_time
            else
              echo "ERROR: Cannot access main storage account after $max_retries attempts. RBAC may not be fully propagated."
              exit 1
            fi
          fi
        done
        
        echo "Testing access to script files storage..."
        retry_count=0
        while [ $retry_count -lt $max_retries ]; do
          if az storage container list --account-name $SCRIPT_STORAGE_ACCOUNT_NAME --auth-mode login --output table; then
            echo "Script storage account access successful on attempt $((retry_count + 1))"
            break
          else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
              wait_time=$((retry_count * 30))
              echo "Script storage account access failed on attempt $retry_count. Retrying in $wait_time seconds..."
              sleep $wait_time
            else
              echo "ERROR: Cannot access script storage account after $max_retries attempts. RBAC may not be fully propagated."
              exit 1
            fi
          fi
        done
        echo "=== Storage Access Test Passed ==="
        
        # Create a virtual environment to avoid system package conflicts
        echo "Creating virtual environment..."
        python3 -m venv /tmp/venv
        source /tmp/venv/bin/activate
        
        # Upgrade pip in the virtual environment
        echo "Upgrading pip in virtual environment..."
        pip install --upgrade pip
        
        echo "Downloading scripts and dependencies from storage..."
        
        # Create working directory 
        mkdir -p /tmp/scripts
        cd /tmp/scripts
        
        # Download data upload files with retry mechanism
        echo "Downloading data upload files..."
        max_retries=3
        retry_count=0
        while [ $retry_count -lt $max_retries ]; do
          if az storage blob download-batch \
            --destination . \
            --source scripts \
            --pattern "data/*" \
            --account-name $SCRIPT_STORAGE_ACCOUNT_NAME \
            --auth-mode login; then
            echo "Data files download successful on attempt $((retry_count + 1))"
            # Verify the files are in the right location
            echo "Data files downloaded:"
            ls -la data/ || echo "Data directory not found"
            break
          else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
              wait_time=$((retry_count * 30))
              echo "Data files download failed on attempt $retry_count. Retrying in $wait_time seconds..."
              sleep $wait_time
            else
              echo "ERROR: Failed to download data files after $max_retries attempts"
              exit 1
            fi
          fi
        done
        
        # Download search configuration files with retry mechanism
        echo "Downloading search configuration files..."
        retry_count=0
        while [ $retry_count -lt $max_retries ]; do
          if az storage blob download-batch \
            --destination . \
            --source scripts \
            --pattern "src/search/*" \
            --account-name $SCRIPT_STORAGE_ACCOUNT_NAME \
            --auth-mode login; then
            echo "Search configuration files download successful on attempt $((retry_count + 1))"
            # Verify the files are in the right location
            echo "Search files downloaded:"
            ls -la src/search/ || echo "Search directory not found"
            break
          else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
              wait_time=$((retry_count * 30))
              echo "Search configuration files download failed on attempt $retry_count. Retrying in $wait_time seconds..."
              sleep $wait_time
            else
              echo "ERROR: Failed to download search configuration files after $max_retries attempts"
              exit 1
            fi
          fi
        done
        
        echo "Installing data upload dependencies..."
        cd data
        if [ -f requirements.txt ]; then
          pip install -r requirements.txt
        else
          echo "WARNING: requirements.txt not found in data directory"
        fi
        
        echo "Downloading PDF files from deployment storage to local directory..."
        # Download PDF files from deployment storage account
        az storage blob download-batch \
          --destination . \
          --source scripts \
          --pattern "data/*.pdf" \
          --account-name $SCRIPT_STORAGE_ACCOUNT_NAME \
          --auth-mode login
        
        echo "PDF files downloaded to data directory:"
        ls -la *.pdf || echo "No PDF files found"
        
        echo "Uploading data files to main storage..."
        echo "Target storage: $MAIN_STORAGE_ACCOUNT_NAME"
        echo "Target container: $DATA_CONTAINER_NAME"
        
        # Retry upload with exponential backoff in case of authorization delays
        max_retries=5
        retry_count=0
        while [ $retry_count -lt $max_retries ]; do
          if python upload_data.py --storage_name $MAIN_STORAGE_ACCOUNT_NAME --container_name $DATA_CONTAINER_NAME; then
            echo "Data upload successful on attempt $((retry_count + 1))"
            break
          else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
              wait_time=$((retry_count * 30))  # 30, 60, 90, 120 seconds
              echo "Data upload failed on attempt $retry_count. Retrying in $wait_time seconds..."
              sleep $wait_time
            else
              echo "ERROR: Failed to upload data files after $max_retries attempts"
              exit 1
            fi
          fi
        done
        
        echo "Moving to search directory..."
        cd ../src/search
        
        echo "Installing search dependencies..."
        if [ -f requirements.txt ]; then
          pip install -r requirements.txt
        else
          echo "WARNING: requirements.txt not found in search directory"
        fi
        
        echo "Running search index configuration..."
        # Retry search configuration with exponential backoff
        max_retries=3
        retry_count=0
        while [ $retry_count -lt $max_retries ]; do
          if python index_utils.py \
            --aisearch_name ${azurerm_search_service.ai_search.name} \
            --base_index_name "default-index" \
            --openai_api_base ${module.azure_open_ai.endpoint} \
            --subscription_id ${data.azurerm_client_config.current.subscription_id} \
            --resource_group_name ${azurerm_resource_group.this.name} \
            --storage_name $MAIN_STORAGE_ACCOUNT_NAME \
            --container_name $DATA_CONTAINER_NAME; then
            echo "Search index configuration successful on attempt $((retry_count + 1))"
            break
          else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
              wait_time=$((retry_count * 60))  # 60, 120 seconds
              echo "Search index configuration failed on attempt $retry_count. Retrying in $wait_time seconds..."
              sleep $wait_time
            else
              echo "ERROR: Failed to configure search index after $max_retries attempts"
              exit 1
            fi
          fi
        done
          
        echo "=== Deployment script completed successfully: $(date) ==="
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

# Role assignments for the script identity to access both storage accounts
resource "azurerm_role_assignment" "script_deployment_storage_access" {
  scope                = azurerm_storage_account.deployment_scripts.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}

# Time sleep to allow all RBAC assignments to propagate before blob operations
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    azurerm_role_assignment.terraform_storage_access,
    azurerm_role_assignment.script_deployment_storage_access,
    azurerm_role_assignment.blob_data_contributor,
    azurerm_role_assignment.file_data_privileged_contributor,
    azurerm_role_assignment.privileged_contributor_to_ai_search
  ]
  create_duration = "120s" # Increased to 2 minutes for better propagation
}

# Additional time sleep for storage account to be fully ready for network access
resource "time_sleep" "wait_for_storage_network" {
  depends_on = [
    azurerm_storage_account.deployment_scripts,
    time_sleep.wait_for_rbac
  ]
  create_duration = "30s"
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
    azurerm_role_assignment.blob_data_contributor,
    azurerm_role_assignment.file_data_privileged_contributor,
    azurerm_role_assignment.script_deployment_storage_access
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