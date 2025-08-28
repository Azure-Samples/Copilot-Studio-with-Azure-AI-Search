# Create Subnet for GitHub Runners
resource "azurerm_subnet" "github_runner" {
  name                 = "snet-github-runner-${random_id.suffix.hex}"
  resource_group_name  = azurerm_resource_group.tfstate.name
  virtual_network_name = azurerm_virtual_network.tfstate.name
  address_prefixes     = var.network_config.github_runner_subnet_address_spaces

  # GitHub runners don't need private endpoint policies
  private_endpoint_network_policies = "Disabled"

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

locals {
  # Additional, ACA-specific egress rules split by port/use and using Azure service tags.
  # Priorities are unique and outside the base NSG rules (which use 100-210).
  aca_rules = var.github_runner_type == "aca" ? [
    # Control plane and data-plane HTTPS
    {
      name     = "Allow-ARM-HTTPS"
      priority = 220
      dir      = "Outbound"
      access   = "Allow"
      proto    = "Tcp"
      spr      = "*"
      dprs     = ["443"]
      sap      = azurerm_subnet.github_runner.address_prefixes[0]
      dap      = "AzureResourceManager"
    },
    {
      name     = "Allow-ACR-HTTPS"
      priority = 221
      dir      = "Outbound"
      access   = "Allow"
      proto    = "Tcp"
      spr      = "*"
      dprs     = ["443"]
      sap      = azurerm_subnet.github_runner.address_prefixes[0]
      dap      = "AzureContainerRegistry"
    },
    {
      name     = "Allow-AzureMonitor-HTTPS"
      priority = 222
      dir      = "Outbound"
      access   = "Allow"
      proto    = "Tcp"
      spr      = "*"
      dprs     = ["443"]
      sap      = azurerm_subnet.github_runner.address_prefixes[0]
      dap      = "AzureMonitor"
    },
    # AMQP for control/scale signals
    {
      name     = "Allow-ServiceBus-AMQP"
      priority = 223
      dir      = "Outbound"
      access   = "Allow"
      proto    = "Tcp"
      spr      = "*"
      dprs     = ["5671-5672"]
      sap      = azurerm_subnet.github_runner.address_prefixes[0]
      dap      = "ServiceBus"
    },
    {
      name     = "Allow-EventHub-AMQP"
      priority = 224
      dir      = "Outbound"
      access   = "Allow"
      proto    = "Tcp"
      spr      = "*"
      dprs     = ["5671-5672"]
      sap      = azurerm_subnet.github_runner.address_prefixes[0]
      dap      = "EventHub"
    }
  ] : []
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
  # # Allow DNS resolution (broad Internet) — replaced by AzurePlatformDNS below
  # security_rule {
  #   name                       = "AllowDNS"
  #   priority                   = 130
  #   direction                  = "Outbound"
  #   access                     = "Allow"
  #   protocol                   = "Udp"
  #   source_port_range          = "*"
  #   destination_port_range     = "53"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "Internet"
  # }

  # Allow DNS to Azure platform DNS
  security_rule {
    name                       = "AllowDNS-AzurePlatform"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = "AzurePlatformDNS"
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

  # Allow Microsoft Container Registry over HTTPS (more specific than broad Internet egress)
  security_rule {
    name                       = "AllowMCRHTTPS"
    priority                   = 155
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = "MicrosoftContainerRegistry"
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
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.github_runner.address_prefixes[0]
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
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.github_runner.address_prefixes[0]
  }

  # Allow outbound HTTPS traffic from GitHub runner subnet to storage subnet
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

  # Allow access to Instance Metadata Service for managed identity
  security_rule {
    name                       = "AllowIMDS"
    priority                   = 195
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = "AzurePlatformIMDS"
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
    source_address_prefix      = azurerm_subnet.github_runner.address_prefixes[0]
    destination_address_prefix = "Internet"
  }

  # ACA-specific egress rules (conditionally added when github_runner_type == "aca")
  dynamic "security_rule" {
    for_each = local.aca_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.dir
      access                     = security_rule.value.access
      protocol                   = security_rule.value.proto
      source_port_range          = security_rule.value.spr
      destination_port_ranges    = security_rule.value.dprs
      source_address_prefix      = security_rule.value.sap
      destination_address_prefix = security_rule.value.dap
    }
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
