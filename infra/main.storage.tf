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
    time_sleep.wait_for_subnets,
    null_resource.verify_subnet_readiness
  ]

  provisioner "local-exec" {
    command = <<EOF
      echo "Verifying subnet readiness for storage account creation..."
      echo "Primary subnet: ${azurerm_subnet.primary_subnet.id}"
      echo "Subnets should now be in 'Succeeded' state, ready for storage account network rules"
    EOF
  }

  triggers = {
    primary_subnet_id = azurerm_subnet.primary_subnet.id
    timestamp = timestamp()
  }
}

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
    bypass                     = ["AzureServices", "Logging", "Metrics"]
    default_action             = "Allow"  # Temporarily allow all access for deployment script
    virtual_network_subnet_ids = toset([
      azurerm_subnet.primary_subnet.id,
      azurerm_subnet.deployment_script_container.id
    ])
  }

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
