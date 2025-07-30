# Create Virtual Network
resource "azurerm_virtual_network" "tfstate" {
  name                = local.vnet_name
  address_space       = ["10.100.0.0/16"]
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  tags                = local.common_tags
}

# Create Subnet for Private Endpoints
resource "azurerm_subnet" "storage" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.tfstate.name
  virtual_network_name = azurerm_virtual_network.tfstate.name
  address_prefixes     = ["10.100.1.0/24"]

  # Disable service endpoints since we're using private endpoints
  service_endpoints = []

  # Enable private endpoint network policies
  private_endpoint_network_policies = "Enabled"
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
    source_address_prefix      = "10.100.1.0/24"
    destination_address_prefix = "10.100.1.0/24"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
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
    source_address_prefix      = "10.100.1.0/24"
    destination_address_prefix = "*"
  }

  # Deny all other outbound traffic
  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
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

# Create Subnet for GitHub Runners
resource "azurerm_subnet" "github_runner" {
  name                 = "snet-github-runner-${random_id.suffix.hex}"
  resource_group_name  = azurerm_resource_group.tfstate.name
  virtual_network_name = azurerm_virtual_network.tfstate.name
  address_prefixes     = ["10.100.2.0/24"]

  # GitHub runners don't need private endpoint policies
  private_endpoint_network_policies = "Disabled"
}

# Create Network Security Group for GitHub Runners
resource "azurerm_network_security_group" "github_runner" {
  name                = "nsg-github-runner-${random_id.suffix.hex}"
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  tags                = local.common_tags

  # Allow SSH inbound for management
  security_rule {
    name                       = "AllowSSHInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow communication with GitHub (HTTPS)
  security_rule {
    name                       = "AllowGitHubHTTPS"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Allow communication with GitHub (HTTP for redirects)
  security_rule {
    name                       = "AllowGitHubHTTP"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Allow DNS resolution
  security_rule {
    name                       = "AllowDNS"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Allow NTP for time synchronization
  security_rule {
    name                       = "AllowNTP"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "123"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Allow communication with Azure services (for Azure CLI, Azure DevOps, etc.)
  security_rule {
    name                       = "AllowAzureServices"
    priority                   = 150
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80"]
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  # Allow communication with Docker Hub and container registries
  security_rule {
    name                       = "AllowContainerRegistries"
    priority                   = 160
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80", "5000"]
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Allow communication within the subnet for multi-runner scenarios
  security_rule {
    name                       = "AllowIntraSubnet"
    priority                   = 170
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.100.2.0/24"
    destination_address_prefix = "10.100.2.0/24"
  }

  # Allow outbound communication within the subnet
  security_rule {
    name                       = "AllowIntraSubnetOutbound"
    priority                   = 180
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.100.2.0/24"
    destination_address_prefix = "10.100.2.0/24"
  }

  # Allow access to Azure Storage (for accessing terraform state)
  security_rule {
    name                       = "AllowStorageAccess"
    priority                   = 190
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Storage"
  }

  # Allow ephemeral outbound ports for general internet access
  security_rule {
    name                       = "AllowEphemeralOutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "8443", "9000-9999", "32768-65535"]
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Allow all outbound to internet (NAT Gateway will handle routing)
  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.100.2.0/24"
    destination_address_prefix = "Internet"
  }

  # Deny all other inbound traffic (explicit deny)
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Deny all other outbound traffic (explicit deny)
  security_rule {
    name                       = "DenyAllOtherOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with GitHub Runner Subnet
resource "azurerm_subnet_network_security_group_association" "github_runner" {
  subnet_id                 = azurerm_subnet.github_runner.id
  network_security_group_id = azurerm_network_security_group.github_runner.id
}

# Create Public IP for NAT Gateway
resource "azurerm_public_ip" "github_runner_nat_ip" {
  name                = "pip-github-runner-nat-${random_id.suffix.hex}"
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# Create NAT Gateway
resource "azurerm_nat_gateway" "github_runner" {
  name                = "nat-github-runner-${random_id.suffix.hex}"
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  sku_name            = "Standard"
  tags                = local.common_tags
}

# Associate Public IP with NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "github_runner" {
  nat_gateway_id       = azurerm_nat_gateway.github_runner.id
  public_ip_address_id = azurerm_public_ip.github_runner_nat_ip.id
}

# Associate NAT Gateway with Subnet
resource "azurerm_subnet_nat_gateway_association" "github_runner" {
  subnet_id      = azurerm_subnet.github_runner.id
  nat_gateway_id = azurerm_nat_gateway.github_runner.id
}
