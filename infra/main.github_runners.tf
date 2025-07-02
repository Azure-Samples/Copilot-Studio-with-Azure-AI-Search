#---- GitHub Actions Self-Hosted Runner Module - Primary Region ----
# Only deploy when enable_vm_github_runner is false
module "github_runner_aca_primary" {
  count  = (var.deploy_github_runner && !var.enable_vm_github_runner) ? 1 : 0
  source = "./modules/github_runner_aca"

  environment_name            = var.azd_environment_name
  unique_id                   = random_string.name.id
  location                    = var.primary_location
  resource_group_name         = azurerm_resource_group.this.name
  infrastructure_subnet_id    = azurerm_subnet.github_runner_primary_subnet[0].id
  private_endpoint_subnet_id  = azurerm_subnet.pe_primary_subnet.id
  virtual_network_id          = azurerm_virtual_network.primary_virtual_network.id
  github_runner_config        = var.github_runner_config
  openai_endpoint             = module.azure_open_ai.endpoint

  tags = merge(var.tags, local.env_tags)
}

#---- GitHub Actions Self-Hosted Runner Module (Virtual Machine) ----
# Only deploy when enable_vm_github_runner is true
module "github_runner_vm" {
  count  = (var.deploy_github_runner && var.enable_vm_github_runner) ? 1 : 0
  source = "./modules/github_runner_vm"

  vm_github_runner_config = var.vm_github_runner_config
  github_runner_vm_size   = var.github_runner_vm_size
  github_runner_os_type   = var.github_runner_os_type
  location                = var.location
  resource_group_name     = azurerm_resource_group.this.name
  unique_id               = random_string.name.id
  subnet_id               = azurerm_subnet.github_runner_primary_subnet[0].id
  tags                    = merge(var.tags, local.env_tags)
}

resource "azurerm_role_assignment" "runner_storage_blob_data_contributor" {
  count                = (var.deploy_github_runner && !var.enable_vm_github_runner) ? 1 : 0
  scope                = module.storage_account_and_container.resource_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.github_runner_aca_primary[0].identity_principal_id
}

resource "azurerm_role_assignment" "runner_search_service_contributor" {
  count                = (var.deploy_github_runner && !var.enable_vm_github_runner) ? 1 : 0
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = module.github_runner_aca_primary[0].identity_principal_id
}

resource "azurerm_role_assignment" "runner_search_index_data_contributor" {
  count                = (var.deploy_github_runner && !var.enable_vm_github_runner) ? 1 : 0
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = module.github_runner_aca_primary[0].identity_principal_id
}

#---- GitHub Actions Self-Hosted Runner Module - Failover Region ----

# Conditionally deployed based on deploy_github_runner, enable_failover_github_runner, and enable_vm_github_runner variables
# Only deploy when enable_vm_github_runner is false
module "github_runner_aca_failover" {
  count  = (var.deploy_github_runner && var.enable_failover_github_runner && !var.enable_vm_github_runner) ? 1 : 0
  source = "./modules/github_runner_aca"

  environment_name            = "${var.azd_environment_name}-failover"
  unique_id                   = "${random_string.name.id}-fo"
  location                    = var.failover_location
  resource_group_name         = azurerm_resource_group.this.name
  infrastructure_subnet_id    = azurerm_subnet.github_runner_failover_subnet[0].id
  private_endpoint_subnet_id  = azurerm_subnet.pe_failover_subnet.id
  virtual_network_id          = azurerm_virtual_network.failover_virtual_network.id
  github_runner_config        = var.github_runner_config
  openai_endpoint             = module.azure_open_ai.endpoint

  tags = merge(var.tags, local.env_tags)
}

resource "azurerm_role_assignment" "runner_failover_storage_blob_data_contributor" {
  count                = (var.deploy_github_runner && var.enable_failover_github_runner && !var.enable_vm_github_runner) ? 1 : 0
  scope                = module.storage_account_and_container.resource_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.github_runner_aca_failover[0].identity_principal_id
}

resource "azurerm_role_assignment" "runner_failover_search_service_contributor" {
  count                = (var.deploy_github_runner && var.enable_failover_github_runner && !var.enable_vm_github_runner) ? 1 : 0
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Service Contributor"
  principal_id         = module.github_runner_aca_failover[0].identity_principal_id
}

resource "azurerm_role_assignment" "runner_failover_search_index_data_contributor" {
  count                = (var.deploy_github_runner && var.enable_failover_github_runner && !var.enable_vm_github_runner) ? 1 : 0
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = module.github_runner_aca_failover[0].identity_principal_id
}
