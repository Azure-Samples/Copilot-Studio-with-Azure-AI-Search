# Create Subnet for GitHub Runners
resource "azurerm_subnet" "github_runner" {
  name                 = "snet-github-runner-${random_id.suffix.hex}"
  resource_group_name  = azurerm_resource_group.tfstate.name
  virtual_network_name = azurerm_virtual_network.tfstate.name
  address_prefixes     = var.network_config.github_runner_subnet_address_spaces

  # GitHub runners don't need private endpoint policies
  private_endpoint_network_policies = "Disabled"

  default_outbound_access_enabled = "false"

  dynamic "delegation" {
    for_each = var.github_runner_type == "aca" ? [1] : []
    content {
      name = "Microsoft.App/environments"

      service_delegation {
        name    = "Microsoft.App/environments"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

# Create Network Security Group for GitHub Runners
resource "azurerm_network_security_group" "github_runner" {
  name                = "nsg-github-runner-${random_id.suffix.hex}"
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  tags                = var.tags

  # VM-specific rules (conditionally added when github_runner_type == "vm")
  # dynamic "security_rule" {
  #   for_each = var.github_runner_type == "vm" ? [1] : []
  #   content {
  #     name                       = "AllowSSHInbound"
  #     priority                   = 100
  #     direction                  = "Inbound"
  #     access                     = "Allow"
  #     protocol                   = "Tcp"
  #     source_port_range          = "*"
  #     destination_port_range     = "22"
  #     source_address_prefix      = "VirtualNetwork"
  #     destination_address_prefix = "*"
  #   }
  # }

  # Explicitly deny DNS to Internet to prevent leakage; allow above takes precedence for platform DNS
  security_rule {
    name                       = "DenyDNSToInternet"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = "Internet"
  }

  # Allow communication with Azure services (includes Storage, ARM, etc.)
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

  # Allow outbound HTTPS traffic from GitHub runner subnet to storage subnet (for private endpoints)
  security_rule {
    name                       = "AllowHTTPSToStorageSubnet"
    priority                   = 185
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.storage.address_prefixes[0]
  }

  # Allow all outbound to internet (NAT Gateway will handle routing)
  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = "Internet"
  }

  # ACA-specific egress rules (conditionally added when github_runner_type == "aca")
  dynamic "security_rule" {
    for_each = var.github_runner_type == "aca" ? [
      {
        name                       = "Allow-ARM-HTTPS"
        priority                   = 220
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
        destination_address_prefix = "AzureResourceManager"
      },
      {
        name                       = "Allow-ACR-HTTPS"
        priority                   = 221
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
        destination_address_prefix = "AzureContainerRegistry"
      },
      {
        name                       = "Allow-AzureMonitor-HTTPS"
        priority                   = 222
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
        destination_address_prefix = "AzureMonitor"
      },
      {
        name                       = "Allow-ServiceBus-AMQP"
        priority                   = 223
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["5671", "5672"]
        source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
        destination_address_prefix = "ServiceBus"
      },
      {
        name                       = "Allow-EventHub-AMQP"
        priority                   = 224
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["5671", "5672"]
        source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
        destination_address_prefix = "EventHub"
      }
    ] : []
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_ranges    = security_rule.value.destination_port_ranges
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
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
  tags                = var.tags
}

# Create NAT Gateway
resource "azurerm_nat_gateway" "github_runner" {
  name                = "nat-github-runner-${random_id.suffix.hex}"
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  sku_name            = "Standard"
  tags                = var.tags
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
