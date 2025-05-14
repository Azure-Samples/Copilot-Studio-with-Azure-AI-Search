module "azure_open_ai" {
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-cognitiveservices-account.git?ref=a73f04df4725afeea3ef0e60ef0eb7f3330f560a"

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
