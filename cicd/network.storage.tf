# Create Subnet for Private Endpoints
resource "azurerm_subnet" "storage" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.tfstate.name
  virtual_network_name = azurerm_virtual_network.tfstate.name
  address_prefixes     = var.network_config.storage_subnet_address_spaces

  # Disable service endpoints since we're using private endpoints
  service_endpoints = []

  # Enable private endpoint network policies
  private_endpoint_network_policies = "Disabled"
}

# Create Network Security Group
resource "azurerm_network_security_group" "storage" {
  name                = local.nsg_name
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  tags                = local.common_tags

  # Allow inbound HTTPS traffic within the subnet
  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = azurerm_subnet.storage.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.storage.address_prefixes[0]
  }

  # Allow outbound HTTPS traffic
  security_rule {
    name                       = "AllowHTTPSOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = azurerm_subnet.storage.address_prefixes[0]
    destination_address_prefix = "*"
  }

  # Allow inbound HTTPS traffic from GitHub runner subnet to storage subnet
  security_rule {
    name                       = "AllowHTTPSFromGitHubRunner"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.storage.address_prefixes[0]
  }

  # Deny all other inbound traffic
  # security_rule {
  #   name                       = "DenyAllInbound"
  #   priority                   = 4096
  #   direction                  = "Inbound"
  #   access                     = "Deny"
  #   protocol                   = "*"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }
  # # Deny all other outbound traffic
  # security_rule {
  #   name                       = "DenyAllOutbound"
  #   priority                   = 4096
  #   direction                  = "Outbound"
  #   access                     = "Deny"
  #   protocol                   = "*"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "storage" {
  subnet_id                 = azurerm_subnet.storage.id
  network_security_group_id = azurerm_network_security_group.storage.id
}

# Create Private DNS Zone for Storage Account
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.tfstate.name
  tags                = local.common_tags
}

# Link Private DNS Zone to Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "vnet-link-${random_id.suffix.hex}"
  resource_group_name   = azurerm_resource_group.tfstate.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.tfstate.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# Create Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "storage_blob" {
  name                = local.pe_name
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  subnet_id           = azurerm_subnet.storage.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "pe-connection-${random_id.suffix.hex}"
    private_connection_resource_id = azurerm_storage_account.tfstate.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}