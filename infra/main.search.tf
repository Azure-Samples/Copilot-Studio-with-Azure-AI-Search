locals {
  search_name = replace("ais${random_string.name.id}", "/[^a-z0-9-]/", "")
  use_service_principal = var.azure_ai_search_service_principal != null && length(var.azure_ai_search_service_principal.client_id) > 0 && length(var.azure_ai_search_service_principal.client_secret) > 0
}


# Role assignment for service principal to have 'Search Index Data Reader' and 'Reader' role
# Deployment of AI Search service requires `User Access Administrator` role to assign this role.
# https://learn.microsoft.com/en-us/azure/search/search-security-rbac?tabs=roles-portal-admin%2Croles-portal%2Croles-portal-query%2Ctest-portal%2Ccustom-role-portal#prerequisites
resource "azurerm_role_assignment" "search_service_reader" {
  count                = local.use_service_principal ? 1 : 0
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Reader"
  principal_id         = var.azure_ai_search_service_principal.enterprise_application_object_id
}

resource "azurerm_role_assignment" "search_service_index_data_reader" {
  count                = local.use_service_principal ? 1 : 0
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = var.azure_ai_search_service_principal.enterprise_application_object_id
}

resource "azurerm_search_service" "ai_search" {
  # checkov:skip=CKV_AZURE_209: Deploying with minimal infrastructure for evaluation. Update partition_count and replica_count for production scenarios.
  # checkov:skip=CKV_AZURE_208: Deploying with minimal infrastructure for evaluation. Update partition_count and replica_count for production scenarios.
  name                          = local.search_name
  location                      = var.primary_location
  resource_group_name           = azurerm_resource_group.this.name
  sku                           = var.ai_search_config.sku
  partition_count               = var.ai_search_config.partition_count
  public_network_access_enabled = var.ai_search_config.public_network_access_enabled
  replica_count                 = var.ai_search_config.replica_count
  tags                          = var.tags

  local_authentication_enabled = local.use_service_principal ? false : true
  authentication_failure_mode  = local.use_service_principal ? null : "http403"

  identity {
    type = "SystemAssigned"
  }
}

# ---- Create private endpoints, DNS zones and records, links, and configs for AI Search ----

# Primary region private endpoint
resource "azurerm_private_endpoint" "primary_endpoint" {
  location            = azurerm_search_service.ai_search.location
  name                = "private-endpoint-primary-${local.search_name}"
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.pe_primary_subnet.id
  tags                = var.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = "private-connection-primary-${local.search_name}"
    private_connection_resource_id = azurerm_search_service.ai_search.id
    subresource_names              = ["searchService"]
  }

  depends_on = [azurerm_search_service.ai_search]
}

# Failover region private endpoint
resource "azurerm_private_endpoint" "failover_endpoint" {
  location            = azurerm_virtual_network.failover_virtual_network.location
  name                = "private-endpoint-failover-${local.search_name}"
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.pe_failover_subnet.id
  tags                = var.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = "private-connection-failover-${local.search_name}"
    private_connection_resource_id = azurerm_search_service.ai_search.id
    subresource_names              = ["searchService"]
  }

  # Azure will bounce the second Search Service request if two endpoint updates are requested simultaneously, so order them explicitly.
  depends_on = [azurerm_private_endpoint.primary_endpoint]
}


resource "azurerm_private_dns_zone" "aisearch_dns" {
  name                = "privatelink.search.windows.net"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_links" {
  for_each = {
    primary  = azurerm_virtual_network.primary_virtual_network.id
    failover = azurerm_virtual_network.failover_virtual_network.id
  }

  name                  = "${each.key}-link"
  private_dns_zone_name = azurerm_private_dns_zone.aisearch_dns.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = each.value
}

# DNS Zone settings can be included in the azurerm_private_endpoint resource, but we need two A records (for primary and failover), and azurerm_private_endpoint doesn't support multiple addresses in one record.
resource "azurerm_private_dns_a_record" "primary_and_failover" {
  name = azurerm_search_service.ai_search.name
  records = [
    azurerm_private_endpoint.primary_endpoint.private_service_connection[0].private_ip_address,
    azurerm_private_endpoint.failover_endpoint.private_service_connection[0].private_ip_address
  ]
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 10
  zone_name           = azurerm_private_dns_zone.aisearch_dns.name
}