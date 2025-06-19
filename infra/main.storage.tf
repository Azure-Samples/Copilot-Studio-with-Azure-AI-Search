module "storage_account_and_container" {
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
  shared_access_key_enabled       = true # TODO turn this off once 2-pass deployment and config is added
  public_network_access_enabled   = true # TODO turn this off once 2-pass deployment and config is added
  allow_nested_items_to_be_public = true # TODO turn this off once 2-pass deployment and config is added

  managed_identities = {
    system_assigned = true
  }

  tags             = var.tags
  enable_telemetry = var.enable_telemetry

  network_rules = {
    bypass                     = ["AzureServices"]
    default_action             = "Deny"
    virtual_network_subnet_ids = toset([azurerm_subnet.main.id])
  }

  containers = {
    (var.cps_container_name) = {
      name          = var.cps_container_name
      public_access = "Blob" # TODO restrict access once 2-pass deployment and config is added
    }
  }
}

# TODO add a proper polling mechanism instead of wait
resource "time_sleep" "wait_for_storage" {
  create_duration = "90s" # Wait for 90 seconds

  depends_on = [module.storage_account_and_container]
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id  = module.storage_account_and_container.resource_id
  container_access_type = "private"
}