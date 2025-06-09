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

resource "time_sleep" "wait_pp_environment" {
  depends_on      = [powerplatform_environment.this, powerplatform_managed_environment.this]
  create_duration = "300s"
}

# Add non-dataverse user to Power Platform environment
resource "powerplatform_user" "new_non_dataverse_user" {
  count          = var.resource_share_user != "" ? 1 : 0
  environment_id = local.power_platform_environment_id
  security_roles = local.security_role_ids # Using the same roles from the all_roles data source
  aad_id         = var.resource_share_user
  disable_delete = false
  depends_on     = [time_sleep.wait_pp_environment]
}
