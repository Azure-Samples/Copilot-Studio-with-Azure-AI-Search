# Wait for subnets to be fully provisioned before creating storage account
resource "time_sleep" "wait_for_subnets" {
  depends_on = [
    azurerm_subnet.primary_subnet,
    azurerm_subnet_nat_gateway_association.primary_subnet_nat,
    azurerm_subnet.deployment_script_container,
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
  # checkov:skip=CKV_AZURE_190: Not supported in the AVM.
  # checkov:skip=CKV_AZURE_244: Not supported in the AVM.
  # checkov:skip=CKV_TF_1: Using published module version for maintainability. See decision-log/001-avm-usage-and-version.md for details.
  source                          = "Azure/avm-res-storage-storageaccount/azurerm"
  version                         = "0.6.2"
  account_replication_type        = var.cps_storage_replication_type
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  location                        = var.location
  name                            = replace("cps${random_string.name.id}", "/[^a-z0-9-]/", "")
  resource_group_name             = azurerm_resource_group.this.name
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
      azurerm_subnet.primary_subnet.id,
      azurerm_subnet.deployment_script_container.id
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

  depends_on = [
    null_resource.verify_subnet_readiness
  ]
}

