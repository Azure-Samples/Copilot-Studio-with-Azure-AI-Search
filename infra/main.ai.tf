module "azure_open_ai" {
  source                = "Azure/avm-res-cognitiveservices-account/azurerm"
  version               = "0.7.0"
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
