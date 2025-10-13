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
  tags = var.tags

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

  # openai_endpoint            = module.azure_open_ai.endpoint

  tags = var.tags

  # Ensure NSG is associated to the subnet before provisioning ACA
  depends_on = [
    azurerm_subnet_network_security_group_association.github_runner,
    azurerm_subnet_nat_gateway_association.github_runner
  ]
}