output "container_app_environment_id" {
  description = "The ID of the Container Apps Environment"
  value       = (var.deploy_github_runner && !var.enable_vm_github_runner) ? module.github_runner_aca_primary[0].container_app_environment_id : null
}

output "github_runner_app_url" {
  description = "The URL of the GitHub runner Container App"
  value       = (var.deploy_github_runner && !var.enable_vm_github_runner) ? module.github_runner_aca_primary[0].github_runner_app_url : null
}

output "container_registry_id" {
  description = "The ID of the Azure Container Registry"
  value       = (var.deploy_github_runner && !var.enable_vm_github_runner) ? module.github_runner_aca_primary[0].container_registry_id : null
}

output "container_registry_login_server" {
  description = "The login server URL for the Azure Container Registry"
  value       = (var.deploy_github_runner && !var.enable_vm_github_runner) ? module.github_runner_aca_primary[0].container_registry_login_server : null
}