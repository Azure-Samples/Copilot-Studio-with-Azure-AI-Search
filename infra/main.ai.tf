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
  public_network_access_enabled = false

  network_acls = {
    default_action = "Allow"
  }

  private_endpoints = {
    pe_endpoint = {
      name                            = "pe_endpoint_${random_string.name.id}"
      private_service_connection_name = "pe_endpoint_connection"
      subnet_resource_id              = azurerm_subnet.pe_primary_subnet.id
    }
  }
  managed_identities = {
    system_assigned = true
  }
  tags = var.tags
}
