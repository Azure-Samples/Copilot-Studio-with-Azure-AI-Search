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
    default_action = "Deny"
    bypass = "AzureServices"
    virtual_network_rules = [
      {
        subnet_id = azurerm_subnet.primary_subnet.id
      },
      {
        subnet_id = azurerm_subnet.failover_subnet.id
      }
    ]
  }

  private_endpoints = {
    pe_endpoint = {
      name                            = "pe_endpoint_${random_string.name.id}"
      private_service_connection_name = "pe_endpoint_connection"
      subnet_resource_id              = azurerm_subnet.pe_primary_subnet.id
    }
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

# Private DNS zone for Azure OpenAI private endpoint resolution
resource "azurerm_private_dns_zone" "aoai_dns" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

# Link the Azure OpenAI DNS zone to both VNets
resource "azurerm_private_dns_zone_virtual_network_link" "aoai_dns_links" {
  for_each = {
    primary  = azurerm_virtual_network.primary_virtual_network.id
    failover = azurerm_virtual_network.failover_virtual_network.id
  }

  name                  = "aoai-${each.key}-link"
  private_dns_zone_name = azurerm_private_dns_zone.aoai_dns.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = each.value
  tags                  = var.tags
}

# DNS A record for Azure OpenAI private endpoint
# The module creates the private endpoint, so we reference it from the module outputs
resource "azurerm_private_dns_a_record" "aoai_dns_record" {
  name                = module.azure_open_ai.resource.name
  zone_name           = azurerm_private_dns_zone.aoai_dns.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 10
  records             = [module.azure_open_ai.private_endpoints["pe_endpoint"].private_service_connection[0].private_ip_address]
  tags                = var.tags
}
