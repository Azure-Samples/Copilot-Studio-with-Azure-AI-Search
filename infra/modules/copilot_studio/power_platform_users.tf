data "powerplatform_tenant" "current" {}

data "powerplatform_data_records" "business_unit_root" {
  environment_id    = local.power_platform_environment_id
  entity_collection = "businessunits"
  filter            = "parentbusinessunitid eq null"
  select            = ["businessunitid", "name"]
  depends_on        = [powerplatform_environment.this, powerplatform_managed_environment.this]
}

data "powerplatform_security_roles" "all_roles" {
  business_unit_id = data.powerplatform_data_records.business_unit_root.rows[0].businessunitid
  environment_id   = local.power_platform_environment_id
  depends_on       = [data.powerplatform_data_records.business_unit_root]
}

locals {
  security_role_id  = { for item in data.powerplatform_security_roles.all_roles.security_roles : item.name => item.role_id }
  # Add error checking for missing roles
  security_role_ids = [for name in var.pp_environment_user_security_role : 
    lookup(local.security_role_id, name, null) != null ? local.security_role_id[name] : 
    error("Security role '${name}' not found in environment. Available roles: ${join(", ", keys(local.security_role_id))}")
  ]
}

# Add non-dataverse user to Power Platform environment
resource "powerplatform_user" "new_non_dataverse_user" {
  for_each       = var.resource_share_user
  environment_id = local.power_platform_environment_id
  security_roles = local.security_role_ids # Using the same roles from the all_roles data source
  aad_id         = each.value
  disable_delete = false

  # Precondition to ensure we have a valid environment ID
  lifecycle {
    precondition {
      condition     = local.power_platform_environment_id != null && local.power_platform_environment_id != ""
      error_message = "Power Platform environment ID is null or empty. Environment must be created before adding users."
    }
    precondition {
      condition     = length(local.security_role_ids) > 0
      error_message = "No security roles found or configured. Users must have at least one security role."
    }
    precondition {
      condition     = length(each.value) >= 32 && length(each.value) <= 40
      error_message = "AAD ID '${each.value}' does not appear to be a valid GUID format."
    }
  }

  # Ensure environment and security roles are ready
  depends_on = [
    data.powerplatform_security_roles.all_roles,
    powerplatform_environment.this,
    powerplatform_managed_environment.this
  ]
}

# Debug outputs to help troubleshoot
output "debug_business_unit_id" {
  value = data.powerplatform_data_records.business_unit_root.rows[0].businessunitid
}

output "debug_available_security_roles" {
  value = [for role in data.powerplatform_security_roles.all_roles.security_roles : role.name]
}

output "debug_selected_security_role_ids" {
  value = local.security_role_ids
}

output "debug_resource_share_users" {
  value = var.resource_share_user
}

output "debug_environment_id" {
  value = local.power_platform_environment_id
}

output "debug_environment_state" {
  value = length(powerplatform_environment.this) > 0 ? "created" : "existing"
}
