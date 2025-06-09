#---- 1 - Power Platform environment ----

# Dynamically set the local variables based on whether the environment is being created or not.
locals {
  power_platform_environment_id       = coalesce(var.power_platform_environment.id, powerplatform_environment.this[0].id)
  power_platform_environment_location = coalesce(var.power_platform_environment.location, powerplatform_environment.this[0].location)
}

resource "powerplatform_environment" "this" {
  count            = var.power_platform_environment.id == "" ? 1 : 0
  location         = var.power_platform_environment.location
  display_name     = "${var.power_platform_environment.name} - ${var.unique_id}"
  environment_type = var.power_platform_environment.environment_type
  dataverse = {
    language_code     = var.power_platform_environment.language_code
    currency_code     = var.power_platform_environment.currency_code
    security_group_id = var.power_platform_environment.security_group_id
  }
}

# The environment needs to be managed to support the use of Enterprise Policies for the Azure connection
resource "powerplatform_managed_environment" "this" {
  count                      = var.power_platform_managed_environment.id == "" ? 1 : 0
  environment_id             = local.power_platform_environment_id
  is_usage_insights_disabled = var.power_platform_managed_environment.is_usage_insights_disabled
  is_group_sharing_disabled  = var.power_platform_managed_environment.is_group_sharing_disabled
  limit_sharing_mode         = var.power_platform_managed_environment.limit_sharing_mode
  max_limit_user_sharing     = var.power_platform_managed_environment.max_limit_user_sharing
  solution_checker_mode      = var.power_platform_managed_environment.solution_checker_mode
  suppress_validation_emails = var.power_platform_managed_environment.suppress_validation_emails
  maker_onboarding_markdown  = var.power_platform_managed_environment.maker_onboarding_markdown
  maker_onboarding_url       = var.power_platform_managed_environment.maker_onboarding_url
}

