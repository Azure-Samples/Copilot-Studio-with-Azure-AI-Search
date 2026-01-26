# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# Wait for network infrastructure to be ready
resource "time_sleep" "wait_for_network_ready" {
  depends_on = [
    module.copilot_studio
  ]
  create_duration = "30s"
}

module "azure_open_ai" {
  # checkov:skip=CKV2_AZURE_22: Customer-managed keys should be added in production usage but are not included here for simplicity.
  # checkov:skip=CKV_AZURE_236: The Power Platform AI Search connector only supports service principal, API key, or interactive auth. 
  # checkov:skip=CKV_TF_1: Using published module version for maintainability. See decision-log/001-avm-usage-and-version.md for details.
  source                             = "Azure/avm-res-cognitiveservices-account/azurerm"
  version                            = "0.10.2"
  kind                               = "OpenAI"
  location                           = local.primary_azure_region
  name                               = azurecaf_name.main_names.results["azurerm_cognitive_account"]
  parent_id                          = local.resource_group_id
  enable_telemetry                   = true
  sku_name                           = "S0"
  local_auth_enabled                 = true
  cognitive_deployments              = var.cognitive_deployments
  public_network_access_enabled      = false
  outbound_network_access_restricted = true
  fqdns                              = ["${azurecaf_name.main_names.results["azurerm_cognitive_account"]}.openai.azure.com"]

  network_acls = {
    default_action = "Deny"
    bypass         = "AzureServices"
    virtual_network_rules = [
      {
        subnet_id = local.primary_subnet_id
      },
      {
        subnet_id = local.failover_subnet_id
      }
    ]
  }

  managed_identities = {
    system_assigned = true
  }
  tags = var.tags

  depends_on = [time_sleep.wait_for_network_ready]
}

# Wait for Azure OpenAI service to be fully provisioned
resource "time_sleep" "wait_for_openai_provisioning" {
  depends_on      = [module.azure_open_ai]
  create_duration = "60s"

  # Ensure the OpenAI service is in a ready state before proceeding with private endpoint creation
  triggers = {
    openai_id = module.azure_open_ai.resource.id
  }
}

# Create private endpoint separately to ensure OpenAI service is fully ready
resource "azurerm_private_endpoint" "openai_pe" {
  name                = "pe-${azurecaf_name.main_names.results["azurerm_cognitive_account"]}"
  location            = local.primary_azure_region
  resource_group_name = local.resource_group_name
  subnet_id           = local.pe_primary_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "pe_endpoint_connection"
    private_connection_resource_id = module.azure_open_ai.resource.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  depends_on = [time_sleep.wait_for_openai_provisioning]
}

# Private DNS zone for Azure OpenAI private endpoint resolution
resource "azurerm_private_dns_zone" "aoai_dns" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

# Link the Azure OpenAI DNS zone to both VNets
resource "azurerm_private_dns_zone_virtual_network_link" "aoai_dns_links" {
  for_each = {
    primary  = local.primary_virtual_network_id
    failover = local.failover_virtual_network_id
  }

  name                  = "aoai-${each.key}-link"
  private_dns_zone_name = azurerm_private_dns_zone.aoai_dns.name
  resource_group_name   = local.resource_group_name
  virtual_network_id    = each.value
  tags                  = var.tags
}

# DNS A record for Azure OpenAI private endpoint
# Reference the separately created private endpoint
resource "azurerm_private_dns_a_record" "aoai_dns_record" {
  name                = module.azure_open_ai.resource.name
  zone_name           = azurerm_private_dns_zone.aoai_dns.name
  resource_group_name = local.resource_group_name
  ttl                 = 10
  records             = [azurerm_private_endpoint.openai_pe.private_service_connection[0].private_ip_address]
  tags                = var.tags
}