output "power_platform_environment_id" {
  description = "The ID of the Power Platform environment."
  value       = local.power_platform_environment_id
}

# required for AVM interface
output "resource_id" {
  description = "value"
  value       = null
}

# TODO there's not an ideal key option here. I could combine name and index to make unique keys, but I'm wondering if it's reasonable to just limit setup to one of each connector name?
output "power_platform_connections" {
  description = "The Power Platform connections created by Terraform"
  value = {
    for idx, conn in powerplatform_connection.connections : conn.name => {
      id           = conn.id
      name         = conn.name
      display_name = conn.display_name
      connector_id = "/providers/Microsoft.PowerApps/apis/${conn.name}"
    }
  }
}
