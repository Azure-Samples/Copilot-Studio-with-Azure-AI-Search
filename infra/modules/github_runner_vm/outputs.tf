output "github_runner_vm_name" {
  description = "The name of the GitHub runner VM"
  value       = var.enable_vm_github_runner ? azurerm_linux_virtual_machine.github_runner[0].name : null
}
