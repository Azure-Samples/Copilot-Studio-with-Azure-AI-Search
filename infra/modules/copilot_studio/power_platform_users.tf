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
  security_role_id  = { for item in data.powerplatform_security_roles.all_roles.security_roles : item.name => item.role_id }
  security_role_ids = [for name in var.pp_environment_user_Security_role : local.security_role_id[name]]
}

# Add non-dataverse user to Power Platform environment
resource "powerplatform_user" "new_non_dataverse_user" {
  for_each       = length(var.resource_share_user) > 0 ? var.resource_share_user : {}
  environment_id = local.power_platform_environment_id
  security_roles = local.security_role_ids # Using the same roles from the all_roles data source
  aad_id         = each.value
  disable_delete = false
}
