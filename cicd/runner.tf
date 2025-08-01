# GitHub Runner VM Module
module "github_runner_vm" {
  source = "./github_runner_vm"

  # Basic configuration
  location            = var.location
  resource_group_name = azurerm_resource_group.tfstate.name
  unique_id           = random_id.suffix.hex

  # Network configuration
  subnet_id = azurerm_subnet.github_runner.id

  # GitHub runner configuration
  vm_github_runner_config = var.vm_github_runner_config
  github_runner_vm_size   = var.github_runner_vm_size
  github_runner_os_type   = var.github_runner_os_type

  # Tags
  tags = local.common_tags
}
