module "storage_account_and_container" {
  source                          = "Azure/avm-res-storage-storageaccount/azurerm"
  #checkov:skip=CKV_TF_1: Using published module version for maintainability. See decision-log/001-avm-usage-and-version.md for details.
  #checkov:skip=CKV_AZURE_59: Public access is already disabled with public_network_access_enabled=false and allow_nested_items_to_be_public=false in AVM 0.6.2
  version                         = "0.6.2"
  account_replication_type        = var.cps_storage_replication_type
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  location                        = var.location
  name                            = replace("cps${random_string.name.id}", "/[^a-z0-9-]/", "")
  resource_group_name             = azurerm_resource_group.this.name
  min_tls_version                 = "TLS1_2"
  # Disable local authentication to comply with CKV_AZURE_244
  shared_access_key_enabled       = false
  # Disable public network access to comply with CKV_AZURE_35 and CKV_AZURE_59
  public_network_access_enabled   = false 
  # Disable blob public access to comply with CKV_AZURE_190
  allow_nested_items_to_be_public = false

  managed_identities = {
    system_assigned = true
  }

  tags             = var.tags
  enable_telemetry = var.enable_telemetry
  
  # Enable Queue logging to comply with CKV_AZURE_33
  queue_properties = {
    logging = {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 7
    }
  }

  containers = {
    (var.cps_container_name) = {
      name          = var.cps_container_name
      public_access = "None" # Restricted for security compliance
    }
  }

  # Ensure network rules always have bypass for AzureServices to comply with CKV_AZURE_36
  network_rules = var.deploy_github_runner ? {
    default_action = "Deny"
    virtual_network_subnet_ids = var.enable_failover_github_runner ? [
      azurerm_subnet.github_runner_primary_subnet[0].id,
      azurerm_subnet.github_runner_failover_subnet[0].id
      ] : [
      azurerm_subnet.github_runner_primary_subnet[0].id
    ]
    bypass = ["AzureServices"] # Enable Trusted Microsoft Services
  } : {
    default_action = "Deny"
    bypass = ["AzureServices"] # Enable Trusted Microsoft Services
  }
}

# TODO add a proper polling mechanism instead of wait
resource "time_sleep" "wait_for_storage" {
  create_duration = "90s" # Wait for 90 seconds

  depends_on = [module.storage_account_and_container]
}
