#---- 1 - Power Platform environment ----

# Dynamically set the local variables based on whether the environment is being created or not.
locals {
  power_platform_environment_id       = coalesce(var.power_platform_environment.id, powerplatform_environment.this[0].id)
  power_platform_environment_location = coalesce(var.power_platform_environment.location, powerplatform_environment.this[0].location)

  # Create a flattened list of azure_region -> location mappings
  power_platform_azure_mappings = flatten([
    for location in data.powerplatform_locations.all_powerplatform_locations.locations : [
      for azure_region in location.azure_regions : {
        azure_region = azure_region
        location     = location
      }
    ]
  ])

  # Find the first mapping that matches the provided environment location based on azure_region 
  search_power_platform_location = lookup(
    { for mapping in local.power_platform_azure_mappings : mapping.azure_region => mapping.location... },
    var.power_platform_azure_region,
    "No Power Platform location for azure region '${var.power_platform_azure_region}' found."
  )
}

data "powerplatform_locations" "all_powerplatform_locations" {
}

resource "powerplatform_billing_policy" "this" {
  count = var.power_platform_billing_policy.should_create && var.power_platform_environment.id == "" ? 1 : 0

  name     = "${var.power_platform_billing_policy.name}${var.unique_id}"
  location = var.power_platform_environment.location
  status   = "Enabled"
  billing_instrument = {
    resource_group  = var.resource_group_name
    subscription_id = var.subscription_id
  }
}

# When created, predefined azure_region is used to determine the location of the Power Platform environment.
resource "powerplatform_environment" "this" {
  count = var.power_platform_environment.id == "" ? 1 : 0

  billing_policy_id = var.power_platform_billing_policy.should_create ? powerplatform_billing_policy.this[0].id : null
  location         = var.power_platform_environment.location != "" && var.power_platform_environment.location != null ? var.power_platform_environment.location : local.search_power_platform_location[0].name
  display_name     = "${var.power_platform_environment.name} - ${var.unique_id}"
  environment_type = var.power_platform_environment.environment_type
  azure_region     = var.power_platform_azure_region
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

