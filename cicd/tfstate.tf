# Generate a random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Local values for common configurations
locals {
  location            = var.location
  resource_group_name = "rg-tfstate-${random_id.suffix.hex}"
  storage_name        = "sttfstate${random_id.suffix.hex}"
  vnet_name           = "vnet-tfstate-${random_id.suffix.hex}"
  subnet_name         = "snet-storage-${random_id.suffix.hex}"
  nsg_name            = "nsg-storage-${random_id.suffix.hex}"
  pe_name             = "pe-storage-${random_id.suffix.hex}"
}

# Create Resource Group
resource "azurerm_resource_group" "tfstate" {
  name     = local.resource_group_name
  location = local.location
  tags     = var.tags
}

# Create Storage Account with private access only
resource "azurerm_storage_account" "tfstate" {
  # checkov:skip=CKV_AZURE_33:Queue service not required for Terraform state storage

  # Note: Customer Managed Key (CMK) encryption not implemented
  # For Terraform state storage, Microsoft-managed keys provide adequate security
  # CMK adds significant operational complexity for key rotation and management

  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"

  # Disable public network access
  public_network_access_enabled = false

  # Enable HTTPS traffic only
  https_traffic_only_enabled = true

  # Set minimum TLS version
  min_tls_version = "TLS1_2"

  # Disable shared key access to enforce RBAC
  shared_access_key_enabled = false

  # Disable blob anonymous access
  allow_nested_items_to_be_public = false

  # Configure blob properties
  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Assign Storage Blob Data Contributor role to current user/service principal
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Assign Storage Account Contributor role for container management
resource "azurerm_role_assignment" "storage_account_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Create Log Analytics Workspace for storage logging
resource "azurerm_log_analytics_workspace" "storage" {
  name                = "law-${local.storage_name}"
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Configure diagnostic settings for storage account blob service
resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name                       = "diag-${local.storage_name}-blob"
  target_resource_id         = "${azurerm_storage_account.tfstate.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.storage.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }
}

# Create storage container for Terraform state
resource "azurerm_storage_container" "tfstate" {
  #checkov:skip=CKV2_AZURE_21:Blob service logging is properly configured via azurerm_monitor_diagnostic_setting.storage_blob with StorageRead, StorageWrite, and StorageDelete enabled

  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"

  # Ensure role assignments exist before container creation
  depends_on = [
    azurerm_role_assignment.storage_blob_data_contributor,
    azurerm_role_assignment.storage_account_contributor
  ]
}
