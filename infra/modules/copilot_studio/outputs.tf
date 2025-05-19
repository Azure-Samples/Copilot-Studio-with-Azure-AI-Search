output "power_platform_environment_id" {
  description = "The ID of the Power Platform environment."
  value       = local.power_platform_environment_id
}

# required for AVM interface
output "resource_id" {
  description = "value"
  value       = null
}

output "power_platform_connections" {
  description = "The Power Platform connections created by Terraform"
  value = {
    for idx, conn in powerplatform_connection.connections : "${conn.name}_${idx}" => {
      id           = conn.id
      name         = conn.name
      display_name = conn.display_name
      connector_id = "/providers/Microsoft.PowerApps/apis/${conn.name}"
    }
  }
}
