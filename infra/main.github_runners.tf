# GitHub Actions Self-Hosted Runner Module - Primary Region
module "github_runner_aca_primary" {
  source = "./modules/github_runner_aca"

  environment_name          = var.azd_environment_name
  unique_id                 = random_string.name.id
  location                  = var.primary_location
  resource_group_name       = azurerm_resource_group.this.name
  infrastructure_subnet_id  = azurerm_subnet.github_runner_primary_subnet.id

  github_runner_config      = var.github_runner_config
  image_registry            = var.image_registry

  tags = merge(var.tags, local.env_tags)
}

# GitHub Actions Self-Hosted Runner Module - Failover Region
# Currently disable to reduce runtime
# module "github_runner_aca_failover" {
#   source = "./modules/github_runner_aca"

#   environment_name          = "${var.azd_environment_name}-failover"
#   unique_id                 = "${random_string.name.id}-fo"
#   location                  = var.failover_location
#   resource_group_name       = azurerm_resource_group.this.name
#   infrastructure_subnet_id  = azurerm_subnet.github_runner_failover_subnet.id

#   github_runner_config      = var.github_runner_config
#   image_registry            = var.image_registry

#   tags = merge(var.tags, local.env_tags)
# }
