resource "azurerm_search_service" "ai_search" {
  # checkov:skip=CKV_AZURE_208: Deploying with minimal infrastructure for evaluation. Update partition_count and replica_count for production scenarios.
  # checkov:skip=CKV_AZURE_209: Ensure that Azure Cognitive Search maintains SLA for search index queries
  name                          = azurecaf_name.main_names.results["azurerm_search_service"]
  location                      = local.primary_azure_region
  resource_group_name           = local.resource_group_name
  sku                           = var.ai_search_config.sku
  partition_count               = var.ai_search_config.partition_count
  public_network_access_enabled = var.ai_search_config.public_network_access_enabled
  replica_count                 = var.ai_search_config.replica_count
  tags                          = var.tags

  # Enable both key-based and Entra ID authentication
  # Key-based auth for backward compatibility and Power Platform
  local_authentication_enabled = true
  authentication_failure_mode  = "http403"

  identity {
    type = "SystemAssigned"
  }
}

# ---- Create private endpoints, DNS zones and records, links, and configs for AI Search ----

# Primary region private endpoint
resource "azurerm_private_endpoint" "primary_endpoint" {
  location            = azurerm_search_service.ai_search.location
  name                = "pe-primary-${azurecaf_name.main_names.results["azurerm_search_service"]}"
  resource_group_name = local.resource_group_name
  subnet_id           = local.pe_primary_subnet_id
  tags                = var.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = "pc-primary-${azurecaf_name.main_names.results["azurerm_search_service"]}"
    private_connection_resource_id = azurerm_search_service.ai_search.id
    subresource_names              = ["searchService"]
  }

  depends_on = [azurerm_search_service.ai_search]
}

# Failover region private endpoint
resource "azurerm_private_endpoint" "failover_endpoint" {
  location            = local.failover_virtual_network_location
  name                = "pe-failover-${azurecaf_name.main_names.results["azurerm_search_service"]}"
  resource_group_name = local.resource_group_name
  subnet_id           = local.pe_failover_subnet_id
  tags                = var.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = "pc-failover-${azurecaf_name.main_names.results["azurerm_search_service"]}"
    private_connection_resource_id = azurerm_search_service.ai_search.id
    subresource_names              = ["searchService"]
  }

  # Azure will bounce the second Search Service request if two endpoint updates are requested simultaneously, so order them explicitly.
  depends_on = [azurerm_private_endpoint.primary_endpoint]
}


resource "azurerm_private_dns_zone" "aisearch_dns" {
  name                = "privatelink.search.windows.net"
  resource_group_name = local.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_links" {
  for_each = {
    primary  = local.primary_virtual_network_id
    failover = local.failover_virtual_network_id
  }

  name                  = "${each.key}-link"
  private_dns_zone_name = azurerm_private_dns_zone.aisearch_dns.name
  resource_group_name   = local.resource_group_name
  virtual_network_id    = each.value
}

# DNS Zone settings can be included in the azurerm_private_endpoint resource, but we need two A records (for primary and failover), and azurerm_private_endpoint doesn't support multiple addresses in one record.
resource "azurerm_private_dns_a_record" "primary_and_failover" {
  name = azurerm_search_service.ai_search.name
  records = [
    azurerm_private_endpoint.primary_endpoint.private_service_connection[0].private_ip_address,
    azurerm_private_endpoint.failover_endpoint.private_service_connection[0].private_ip_address
  ]
  resource_group_name = local.resource_group_name
  ttl                 = 10
  zone_name           = azurerm_private_dns_zone.aisearch_dns.name
}