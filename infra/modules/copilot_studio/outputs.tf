output "power_platform_environment_id" {
  description = "The ID of the Power Platform environment."
  value       = local.power_platform_environment_id
}


# required for AVM interface
output "resource_id" {
  description = "value"
  value       = null
}
