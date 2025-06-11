# GitHub Actions Self-Hosted Runner Module - Primary Region
module "github_runner_aca_primary" {
  source = "./modules/github_runner_aca"

  environment_name            = var.azd_environment_name
  unique_id                   = random_string.name.id
  location                    = var.primary_location
  resource_group_name         = azurerm_resource_group.this.name
  infrastructure_subnet_id    = azurerm_subnet.github_runner_primary_subnet.id
  private_endpoint_subnet_id  = azurerm_subnet.pe_primary_subnet.id
  virtual_network_id          = azurerm_virtual_network.primary_virtual_network.id
  github_runner_config        = var.github_runner_config

  tags = merge(var.tags, local.env_tags)
}

# GitHub Actions Self-Hosted Runner Module - Failover Region
# Conditionally deployed based on enable_failover_github_runner variable
module "github_runner_aca_failover" {
  count  = var.enable_failover_github_runner ? 1 : 0
  source = "./modules/github_runner_aca"

  environment_name            = "${var.azd_environment_name}-failover"
  unique_id                   = "${random_string.name.id}-fo"
  location                    = var.failover_location
  resource_group_name         = azurerm_resource_group.this.name
  infrastructure_subnet_id    = azurerm_subnet.github_runner_failover_subnet.id
  private_endpoint_subnet_id  = azurerm_subnet.pe_failover_subnet.id
  virtual_network_id          = azurerm_virtual_network.failover_virtual_network.id
  github_runner_config        = var.github_runner_config

  tags = merge(var.tags, local.env_tags)
}
