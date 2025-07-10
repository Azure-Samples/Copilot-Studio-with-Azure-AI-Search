
resource "powerplatform_environment" "this" {
  count            = var.power_platform_environment.id == "" ? 1 : 0
  location         = var.power_platform_environment.location
  environment_type = var.power_platform_environment.environment_type
  display_name     = "${var.billing_subscription_id}"
}
