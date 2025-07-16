locals {
  create_managed_environment = var.power_platform_managed_environment.id == "" ? true : false
}

resource "powerplatform_billing_policy" "this" {
  count = local.create_managed_environment && var.power_platform_billing_policy.should_create ? 1 : 0

  name = "${var.power_platform_billing_policy.name}${var.unique_id}"
  location = var.power_platform_environment.location
  status   = "Enabled"
  billing_instrument = {
    resource_group  = var.resource_group_name
    subscription_id = var.subscription_id
  }
}

resource "powerplatform_billing_policy_environment" "this" {
  count = local.create_managed_environment && var.power_platform_billing_policy.should_create ? 1 : 0

  billing_policy_id = powerplatform_billing_policy.this[0].id
  environments      = [local.power_platform_environment_id]
}
