# GitHub Runner VM Module
module "github_runner_vm" {
  count  = var.github_runner_type == "vm" ? 1 : 0
  source = "./github_runner_vm"

  # Basic configuration
  location            = var.location
  resource_group_name = azurerm_resource_group.tfstate.name
  unique_id           = random_id.suffix.hex

  # Network configuration
  subnet_id = azurerm_subnet.github_runner.id

  # GitHub runner configuration
  vm_github_runner_config = var.github_runner_config
  github_runner_vm_size   = var.github_runner_config.vm_size
  github_runner_os_type   = var.github_runner_config.vm_os_type

  github_runner_registration_token = var.github_runner_registration_token

  # Tags
  tags = local.common_tags

  # Ensure NSG is associated to the subnet before provisioning the VM and its extension
  depends_on = [
    azurerm_subnet_network_security_group_association.github_runner,
    azurerm_subnet_nat_gateway_association.github_runner
  ]
}

#---- GitHub Actions Self-Hosted Runner Module - Primary Region ----

module "github_runner_aca_primary" {
  count  = var.github_runner_type == "aca" ? 1 : 0
  source = "./github_runner_aca"

  environment_name                 = "cicd"
  unique_id                        = random_id.suffix.hex
  location                         = var.location
  resource_group_name              = local.resource_group_name
  runner_subnet_id                 = azurerm_subnet.github_runner.id
  private_endpoint_subnet_id       = azurerm_subnet.storage.id
  virtual_network_id               = azurerm_virtual_network.tfstate.id
  github_runner_config             = var.github_runner_config
  github_runner_registration_token = var.github_runner_registration_token
  github_pat                       = var.github_pat

  # {
  #   runner_name  = var.github_runner_config.runner_name
  #   runner_token = var.github_runner_config.runner_token
  #   repo_owner   = var.github_runner_config.repo_owner
  #   repo_name    = var.github_runner_config.repo_name
  #   runner_group = var.github_runner_config.runner_group
  # }
  # openai_endpoint            = module.azure_open_ai.endpoint

  tags = local.common_tags
}

# resource "azurerm_role_assignment" "runner_storage_blob_data_contributor" {
#   count                = var.deploy_github_runner ? 1 : 0
#   scope                = module.storage_account_and_container.resource_id
#   role_definition_name = "Storage Blob Data Contributor"
#   principal_id         = module.github_runner_aca_primary[0].identity_principal_id
# }

# resource "azurerm_role_assignment" "runner_search_service_contributor" {
#   count                = var.deploy_github_runner ? 1 : 0
#   scope                = azurerm_search_service.ai_search.id
#   role_definition_name = "Search Service Contributor"
#   principal_id         = module.github_runner_aca_primary[0].identity_principal_id
# }

# resource "azurerm_role_assignment" "runner_search_index_data_contributor" {
#   count                = var.deploy_github_runner ? 1 : 0
#   scope                = azurerm_search_service.ai_search.id
#   role_definition_name = "Search Index Data Contributor"
#   principal_id         = module.github_runner_aca_primary[0].identity_principal_id
# }

# #---- GitHub Actions Self-Hosted Runner Module - Failover Region ----

# # Conditionally deployed based on deploy_github_runner and enable_failover_github_runner variables
# module "github_runner_aca_failover" {
#   count  = var.deploy_github_runner && var.enable_failover_github_runner ? 1 : 0
#   source = "./modules/github_runner_aca"

#   environment_name           = "${var.azd_environment_name}-failover"
#   unique_id                  = "${random_string.name.id}-fo"
#   location                   = local.secondary_azure_region
#   resource_group_name        = local.resource_group_name
#   infrastructure_subnet_id   = azurerm_subnet.github_runner_failover_subnet[0].id
#   private_endpoint_subnet_id = local.pe_failover_subnet_id
#   virtual_network_id         = local.failover_virtual_network_id
#   github_runner_config       = var.github_runner_config
#   openai_endpoint            = module.azure_open_ai.endpoint

#   tags = merge(var.tags, local.env_tags)
# }

# resource "azurerm_role_assignment" "runner_failover_storage_blob_data_contributor" {
#   count                = var.deploy_github_runner && var.enable_failover_github_runner ? 1 : 0
#   scope                = module.storage_account_and_container.resource_id
#   role_definition_name = "Storage Blob Data Contributor"
#   principal_id         = module.github_runner_aca_failover[0].identity_principal_id
# }

# resource "azurerm_role_assignment" "runner_failover_search_service_contributor" {
#   count                = var.deploy_github_runner && var.enable_failover_github_runner ? 1 : 0
#   scope                = azurerm_search_service.ai_search.id
#   role_definition_name = "Search Service Contributor"
#   principal_id         = module.github_runner_aca_failover[0].identity_principal_id
# }

# resource "azurerm_role_assignment" "runner_failover_search_index_data_contributor" {
#   count                = var.deploy_github_runner && var.enable_failover_github_runner ? 1 : 0
#   scope                = azurerm_search_service.ai_search.id
#   role_definition_name = "Search Index Data Contributor"
#   principal_id         = module.github_runner_aca_failover[0].identity_principal_id
# }
