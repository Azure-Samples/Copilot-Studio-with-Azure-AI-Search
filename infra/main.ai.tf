module "azure_open_ai" {
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-cognitiveservices-account.git?ref=4387767bea92ac50e5b40b0b30d90608e64a40df"

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
