module "azure_open_ai" {
  # checkov:skip=CKV_TF_1: Using published module version for maintainability. See decision-log/001-avm-usage-and-version.md for details.
  source                = "Azure/avm-res-cognitiveservices-account/azurerm"
  version               = "0.7.1"
  kind                  = "OpenAI"
  location              = var.location
  name                  = "aoai${random_string.name.id}"
  resource_group_name   = azurerm_resource_group.this.name
  enable_telemetry      = true
  sku_name              = "S0"
  local_auth_enabled    = true
  cognitive_deployments = var.cognitive_deployments
  network_acls = {
    default_action = "Deny"
  }
  managed_identities = {
    system_assigned = true
  }
  tags = var.tags
}
