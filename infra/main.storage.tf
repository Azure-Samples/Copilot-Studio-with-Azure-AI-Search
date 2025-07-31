# ============================================================================
# PRIVATE DNS CONFIGURATION FOR STORAGE PRIVATE ENDPOINTS
# ============================================================================

# Private DNS zone for blob storage private endpoints
resource "azurerm_private_dns_zone" "blob_storage" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

# Link the private DNS zone to the primary virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "blob_storage_vnet_link" {
  name                  = "blob-storage-vnet-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob_storage.name
  virtual_network_id    = local.primary_virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# ============================================================================
# STORAGE ACCOUNT CONFIGURATION
# ============================================================================

# Wait for subnets to be fully provisioned before creating storage account
resource "time_sleep" "wait_for_subnets" {
  depends_on = [
    azurerm_subnet.primary_subnet[0],
    azurerm_subnet_nat_gateway_association.primary_subnet_nat,
    azurerm_subnet.deployment_script_container_subnet[0],
    azurerm_subnet_nat_gateway_association.deployment_script_nat
  ]
  create_duration = "90s" # Wait for subnets to exit 'Updating' state
}

# Additional verification that subnets are ready for storage account creation
resource "null_resource" "verify_subnet_readiness" {
  depends_on = [
    time_sleep.wait_for_subnets
  ]
}

module "storage_account_and_container" {
  # checkov:skip=CKV_AZURE_36: "Ensure 'Trusted Microsoft Services' is enabled for Storage Account access"
  # checkov:skip=CKV_AZURE_35: "Ensure default network access rule for Storage Accounts is set to deny"
  # checkov:skip=CKV_AZURE_190: Not supported in the AVM.
  # checkov:skip=CKV_AZURE_244: Not supported in the AVM.
  # checkov:skip=CKV_TF_1: Using published module version for maintainability. See decision-log/001-avm-usage-and-version.md for details.
  # checkov:skip=CKV_AZURE_33: Logging is enabled.
  # checkov:skip=CKV2_AZURE_38: Soft delete is enabled.
  source                          = "Azure/avm-res-storage-storageaccount/azurerm"
  version                         = "0.6.4"
  account_replication_type        = var.cps_storage_replication_type
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  location                        = local.primary_azure_region
  name                            = replace("cps${random_string.name.id}", "/[^a-z0-9-]/", "")
  resource_group_name             = local.resource_group_name
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  managed_identities = {
    system_assigned = true
  }

  tags             = var.tags
  enable_telemetry = var.enable_telemetry

  network_rules = {
    bypass         = ["AzureServices", "Logging", "Metrics"]
    default_action = "Deny"
    virtual_network_subnet_ids = toset([
      local.primary_subnet_id,
      local.deployment_script_container_subnet_id,
      local.pe_primary_subnet_id
    ])

    logging = {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 10
    }
  }



  blob_properties = {
    delete_retention_policy = {
      days = 7
    }
  }

  containers = {
    (var.cps_container_name) = {
      name          = var.cps_container_name
      public_access = "None" # Private access only - no public access allowed for security
    }
  }

  private_endpoints = {
    primary_blob = {
      subnet_resource_id            = local.pe_primary_subnet_id
      subresource_name              = "blob"
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.blob_storage.id]
      private_dns_zone_group_name   = "default"
    }
  }

  depends_on = [
    null_resource.verify_subnet_readiness,
    azurerm_private_dns_zone.blob_storage,
    azurerm_private_dns_zone_virtual_network_link.blob_storage_vnet_link
  ]
}

