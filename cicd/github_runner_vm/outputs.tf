output "github_runner_vm_name" {
  description = "The name of the GitHub runner VM"
  value       = var.github_runner_os_type == "linux" ? azurerm_linux_virtual_machine.github_runner[0].name : null
}
