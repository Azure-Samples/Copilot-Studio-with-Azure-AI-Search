# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

data "powerplatform_tenant" "current" {}

data "powerplatform_data_records" "business_unit_root" {
  environment_id    = powerplatform_environment.this[0].id
  entity_collection = "businessunits"
  filter            = "parentbusinessunitid eq null"
  select            = ["businessunitid", "name"]
  depends_on        = [powerplatform_environment.this]
}

data "powerplatform_security_roles" "all_roles" {
  business_unit_id = data.powerplatform_data_records.business_unit_root.rows[0].businessunitid
  environment_id   = powerplatform_environment.this[0].id
}

locals {
  # Create a map of security role names to IDs
  security_role_id = { for item in data.powerplatform_security_roles.all_roles.security_roles : item.name => item.role_id }

  # Filter to only include roles that actually exist in the environment
  available_roles = [for name in var.pp_environment_user_security_role : name if contains(keys(local.security_role_id), name)]

  # Get the role IDs for the available roles
  security_role_ids = [for name in local.available_roles : local.security_role_id[name]]

  # Calculate missing roles for debugging
  missing_roles = [for name in var.pp_environment_user_security_role : name if !contains(keys(local.security_role_id), name)]
}

# Validation check for missing security roles
check "security_roles_exist" {
  assert {
    condition     = length(local.missing_roles) == 0
    error_message = "The following security roles were requested but do not exist in the Power Platform environment: ${join(", ", local.missing_roles)}. Available roles are: ${join(", ", keys(local.security_role_id))}"
  }
}

# Add non-dataverse user to Power Platform environment
resource "powerplatform_user" "new_non_dataverse_user" {
  for_each       = length(var.resource_share_user) > 0 ? var.resource_share_user : []
  environment_id = local.power_platform_environment_id
  security_roles = local.security_role_ids
  aad_id         = each.value
  // disable_delete = false
}
