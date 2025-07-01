module "azure_open_ai" {
  # checkov:skip=CKV_TF_1: Using published module version for maintainability. See decision-log/001-avm-usage-and-version.md for details.
  # checkov:skip=CKV_AZURE_247: Data loss prevention for Cognitive Services account is not directly configurable through the AVM module. The module manages this configuration internally.
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
  # Disable public network access to comply with CKV_AZURE_134 security check
  public_network_access_enabled = false

  network_acls = {
    default_action = "Deny"
    virtual_network_rules = [
      {
        subnet_id = azurerm_subnet.ai_search_primary_subnet.id
      },
      {
        subnet_id = azurerm_subnet.ai_search_failover_subnet.id
      },
      {
        subnet_id = azurerm_subnet.pe_primary_subnet.id
      },
      {
        subnet_id = azurerm_subnet.pe_failover_subnet.id
      }
    ]
    bypass = "AzureServices"
  }
  managed_identities = {
    system_assigned = true
  }
  tags = var.tags
}
