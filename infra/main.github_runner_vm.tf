# GitHub Actions Self-Hosted Runner Module (Virtual Machine)
# Only deploy when enable_vm_github_runner is true
module "github_runner_vm" {
  count  = var.enable_vm_github_runner ? 1 : 0
  source = "./modules/github_runner_vm"

  enable_vm_github_runner = var.enable_vm_github_runner
  vm_github_runner_config = var.vm_github_runner_config

  github_runner_vm_size = var.github_runner_vm_size
  github_runner_os_type = var.github_runner_os_type
  
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  unique_id           = random_string.name.id
  subnet_id           = azurerm_subnet.github_runner_primary_subnet.id
  tags                = merge(var.tags, local.env_tags)
}