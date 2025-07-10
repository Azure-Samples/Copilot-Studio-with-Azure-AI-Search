module "storage_account_and_container" {
  # checkov:skip=CKV_TF_1: Using published module version for maintainability. See decision-log/001-avm-usage-and-version.md for details.
  # checkov:skip=CKV_AZURE_190: Public access is temporarily enabled for initial deployment
  # checkov:skip=CKV_AZURE_244: Local users are required for application functionality
  # checkov:skip=CKV_AZURE_33: Queue service logging not required for this use case
  # checkov:skip=CKV_AZURE_206: Using standard replication for cost optimization
  # checkov:skip=CKV_AZURE_36: Trusted Microsoft Services bypass is configured via network_rules
  # checkov:skip=CKV_AZURE_35: Network access is restricted via network_rules when GitHub runner is deployed
  # checkov:skip=CKV_AZURE_59: Public access is temporarily enabled for initial deployment
  # checkov:skip=CKV2_AZURE_40: Shared key access is required for application functionality
  # checkov:skip=CKV2_AZURE_47: Anonymous blob access is temporarily enabled for initial deployment
  # checkov:skip=CKV2_AZURE_38: Soft delete will be configured in production environment
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

  containers = {
    (var.cps_container_name) = {
      name          = var.cps_container_name
      public_access = "Blob" # TODO restrict access once 2-pass deployment and config is added
    }
  }

  network_rules = var.deploy_github_runner ? {
    default_action = "Deny"
    virtual_network_subnet_ids = var.enable_failover_github_runner ? [
      azurerm_subnet.github_runner_primary_subnet[0].id,
      azurerm_subnet.github_runner_failover_subnet[0].id
      ] : [
      azurerm_subnet.github_runner_primary_subnet[0].id
    ]
    bypass = ["AzureServices"]
  } : null
}

# TODO add a proper polling mechanism instead of wait
resource "time_sleep" "wait_for_storage" {
  create_duration = "90s" # Wait for 90 seconds

  depends_on = [module.storage_account_and_container]
}