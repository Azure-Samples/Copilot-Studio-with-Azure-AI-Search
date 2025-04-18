locals {
  private_endpoint_failover_name = "private-endpoint-failover-${local.search_name}"
  private_endpoint_primary_name  = "private-endpoint-primary-${local.search_name}"
  search_name                    = replace("ais${random_string.name.id}", "/[^a-z0-9-]/", "")
}

resource "azurerm_search_service" "ai_search" {
  location                      = var.primary_location
  name                          = local.search_name
  resource_group_name           = azurerm_resource_group.this.name
  sku                           = "basic"
  partition_count               = 1
  public_network_access_enabled = false
  replica_count                 = 1
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# ---- Create private endpoints, DNS zones and records, links, and configs for AI Search ----

resource "azurerm_private_endpoint" "primary" {
  location            = azurerm_search_service.ai_search.location
  name                = local.private_endpoint_primary_name
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.primary_virtual_network.subnets["ai-search-primary-subnet"].resource.id

  private_service_connection {
    is_manual_connection           = false
    name                           = "private-connection-primary-${local.search_name}"
    private_connection_resource_id = azurerm_search_service.ai_search.id
    subresource_names              = ["searchService"]
  }

  depends_on = [azurerm_search_service.ai_search]
}

resource "azurerm_private_endpoint" "failover" {
  location            = module.failover_virtual_network.resource.location
  name                = local.private_endpoint_failover_name
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.failover_virtual_network.subnets["ai-search-failover-subnet"].resource.id

  private_service_connection {
    is_manual_connection           = false
    name                           = "private-connection-failover-${local.search_name}"
    private_connection_resource_id = azurerm_search_service.ai_search.id
    subresource_names              = ["searchService"]
  }

  depends_on = [azurerm_private_endpoint.primary, azurerm_search_service.ai_search]
}

resource "azurerm_private_dns_zone" "aisearch_dns" {
  name                = "privatelink.search.windows.net"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "primary" {
  name                  = "primary-link"
  private_dns_zone_name = azurerm_private_dns_zone.aisearch_dns.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = module.primary_virtual_network.resource.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "failover" {
  name                  = "failover-link"
  private_dns_zone_name = azurerm_private_dns_zone.aisearch_dns.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = module.failover_virtual_network.resource.id
}

# DNS Zone settings can be included in the azurerm_private_endpoint resource, but we need two A records (for primary and failover), and azurerm_private_endpoint doesn't support multiple addresses in one record.
resource "azurerm_private_dns_a_record" "primary_and_failover" {
  name                = azurerm_search_service.ai_search.name
  records             = [azurerm_private_endpoint.primary.private_service_connection[0].private_ip_address, azurerm_private_endpoint.failover.private_service_connection[0].private_ip_address]
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 10
  zone_name           = azurerm_private_dns_zone.aisearch_dns.name
}
