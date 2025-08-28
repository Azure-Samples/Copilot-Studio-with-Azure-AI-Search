locals {
  create_network_infrastructure = var.networking.primary_virtual_network.id != null && length(var.networking.primary_virtual_network.id) > 0 ? true : false
  primary_virtual_network_id    = coalesce(var.networking.primary_virtual_network.id, local.create_network_infrastructure ? null : azurerm_virtual_network.primary_virtual_network[0].id)
  primary_virtual_network_resource_group = coalesce(
    length(local.primary_vnet_matches) > 0 ? local.primary_vnet_matches[0].resource_group_name : null,
    local.create_network_infrastructure ? null : local.resource_group_name
  )

  # Get matching primary VNets from data source
  primary_vnet_matches = [for r in data.azurerm_resources.vnets.resources : r if r.id == local.primary_virtual_network_id]

  primary_virtual_network_name = coalesce(
    length(local.primary_vnet_matches) > 0 ? local.primary_vnet_matches[0].name : null,
    local.create_network_infrastructure ? null : azurerm_virtual_network.primary_virtual_network[0].name
  )

  failover_virtual_network_id = coalesce(var.networking.failover_virtual_network.id, local.create_network_infrastructure ? null : azurerm_virtual_network.failover_virtual_network[0].id)

  # Get matching failover VNets from data source
  failover_vnet_matches = [for r in data.azurerm_resources.vnets.resources : r if r.id == local.failover_virtual_network_id]

  failover_virtual_network_name = coalesce(
    length(local.failover_vnet_matches) > 0 ? local.failover_vnet_matches[0].name : null,
    local.create_network_infrastructure ? null : azurerm_virtual_network.failover_virtual_network[0].name
  )
  failover_virtual_network_location = coalesce(
    length(local.failover_vnet_matches) > 0 ? local.failover_vnet_matches[0].location : null,
    local.create_network_infrastructure ? null : azurerm_virtual_network.failover_virtual_network[0].location
  )

  primary_subnet_id = coalesce(var.networking.primary_virtual_network.primary_subnet_id, local.create_network_infrastructure ? null : azurerm_subnet.primary_subnet[0].id)

  # Get matching primary subnets from data source (subnets are not in the VNets data source, so we'll use a simpler approach)
  primary_subnet_name = coalesce(
    var.networking.primary_virtual_network.primary_subnet_id != null ? split("/", var.networking.primary_virtual_network.primary_subnet_id)[length(split("/", var.networking.primary_virtual_network.primary_subnet_id)) - 1] : null,
    local.create_network_infrastructure ? null : azurerm_subnet.primary_subnet[0].name
  )

  failover_subnet_id = coalesce(var.networking.failover_virtual_network.failover_subnet_id, local.create_network_infrastructure ? null : azurerm_subnet.failover_subnet[0].id)

  failover_subnet_name = coalesce(
    var.networking.failover_virtual_network.failover_subnet_id != null ? split("/", var.networking.failover_virtual_network.failover_subnet_id)[length(split("/", var.networking.failover_virtual_network.failover_subnet_id)) - 1] : null,
    local.create_network_infrastructure ? null : azurerm_subnet.failover_subnet[0].name
  )

  pe_primary_subnet_id                  = coalesce(var.networking.primary_virtual_network.pe_primary_subnet_id, local.create_network_infrastructure ? null : azurerm_subnet.pe_primary_subnet[0].id)
  pe_failover_subnet_id                 = coalesce(var.networking.failover_virtual_network.pe_failover_subnet_id, local.create_network_infrastructure ? null : azurerm_subnet.pe_failover_subnet[0].id)
  deployment_script_container_subnet_id = coalesce(var.networking.primary_virtual_network.deployment_script_container_subnet_id, local.create_network_infrastructure ? null : azurerm_subnet.deployment_script_container_subnet[0].id)
}

data "azurerm_resources" "vnets" {
  type = "Microsoft.Network/virtualNetworks"
}


# Create virtual networks directly instead of using AVMs - necessary due to timing issues when a first-class resource dependency is unavailable.
resource "azurerm_virtual_network" "primary_virtual_network" {
  count = local.create_network_infrastructure ? 0 : 1

  name                = azurecaf_name.main_names.results["azurerm_virtual_network"]
  resource_group_name = local.resource_group_name
  location            = local.primary_azure_region
  address_space       = var.primary_vnet_address_spaces
  tags                = var.tags
}

resource "azurerm_virtual_network" "failover_virtual_network" {
  count = local.create_network_infrastructure ? 0 : 1

  name                = azurecaf_name.failover_names.results["azurerm_virtual_network"]
  resource_group_name = local.resource_group_name
  location            = local.secondary_azure_region
  address_space       = var.failover_vnet_address_spaces
  tags                = var.tags
}

# Create primary subnets as first-class resources
resource "azurerm_subnet" "primary_subnet" {
  count = local.create_network_infrastructure ? 0 : 1

  name                 = var.primary_subnet_name
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network[0].name
  address_prefixes     = var.primary_subnet_address_spaces
  service_endpoints    = ["Microsoft.Storage", "Microsoft.CognitiveServices"]

  delegation {
    name = "Microsoft.PowerPlatform/enterprisePolicies"
    service_delegation {
      name    = "Microsoft.PowerPlatform/enterprisePolicies"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "primary_subnet_nat" {
  count = local.create_network_infrastructure ? 0 : 1

  subnet_id      = azurerm_subnet.primary_subnet[0].id
  nat_gateway_id = azurerm_nat_gateway.primary_nat_gateway[0].id
}

# Create failover subnets as first-class resources
resource "azurerm_subnet" "failover_subnet" {
  
  count = local.create_network_infrastructure ? 0 : 1

  name                 = var.failover_subnet_name
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.failover_virtual_network[0].name
  address_prefixes     = var.failover_subnet_address_spaces
  service_endpoints    = ["Microsoft.Storage", "Microsoft.CognitiveServices"]

  delegation {
    name = "Microsoft.PowerPlatform/enterprisePolicies"
    service_delegation {
      name    = "Microsoft.PowerPlatform/enterprisePolicies"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "failover_subnet_nat" {
  count = local.create_network_infrastructure ? 0 : 1

  subnet_id      = azurerm_subnet.failover_subnet[0].id
  nat_gateway_id = azurerm_nat_gateway.failover_nat_gateway[0].id
}

# Create dedicated private endpoint subnets without delegations
resource "azurerm_subnet" "pe_primary_subnet" {
  count = local.create_network_infrastructure ? 0 : 1

  
  name                 = azurecaf_name.main_pe_subnet_names.results["azurerm_subnet"]
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network[0].name
  address_prefixes     = var.primary_pe_subnet_address_spaces
  service_endpoints    = ["Microsoft.CognitiveServices", "Microsoft.Storage"]

  # Required for private endpoints
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "pe_failover_subnet" {
  
  count = local.create_network_infrastructure ? 0 : 1

  name                 = azurecaf_name.failover_pe_subnet_names.results["azurerm_subnet"]
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.failover_virtual_network[0].name
  address_prefixes     = var.failover_pe_subnet_address_spaces
  service_endpoints    = ["Microsoft.CognitiveServices"]

  # Required for private endpoints
  private_endpoint_network_policies = "Enabled"
}



# Create public IP addresses for NAT gateways
resource "azurerm_public_ip" "primary_nat_gateway_ip" {
  count               = local.create_network_infrastructure ? 0 : 1
  name                = azurecaf_name.main_names.results["azurerm_public_ip"]
  location            = local.primary_azure_region
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "failover_nat_gateway_ip" {
  count               = local.create_network_infrastructure ? 0 : 1
  name                = azurecaf_name.failover_names.results["azurerm_public_ip"]
  location            = local.secondary_azure_region
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "primary_nat_gateway" {
  count               = local.create_network_infrastructure ? 0 : 1
  location            = local.primary_azure_region
  name                = azurecaf_name.main_names.results["azurerm_virtual_network_gateway"]
  resource_group_name = local.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags

  # Associate the public IP address with the NAT gateway
  depends_on = [azurerm_public_ip.primary_nat_gateway_ip]
}

resource "azurerm_nat_gateway" "failover_nat_gateway" {
  count               = local.create_network_infrastructure ? 0 : 1
  location            = local.secondary_azure_region
  name                = azurecaf_name.failover_names.results["azurerm_virtual_network_gateway"]
  resource_group_name = local.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags

  # Associate the public IP address with the NAT gateway
  depends_on = [azurerm_public_ip.failover_nat_gateway_ip]
}

# Associate public IP addresses with NAT gateways
resource "azurerm_nat_gateway_public_ip_association" "primary_nat_gateway_ip_association" {
  count                = local.create_network_infrastructure ? 0 : 1
  nat_gateway_id       = azurerm_nat_gateway.primary_nat_gateway[0].id
  public_ip_address_id = azurerm_public_ip.primary_nat_gateway_ip[0].id
}

resource "azurerm_nat_gateway_public_ip_association" "failover_nat_gateway_ip_association" {
  count                = local.create_network_infrastructure ? 0 : 1
  nat_gateway_id       = azurerm_nat_gateway.failover_nat_gateway[0].id
  public_ip_address_id = azurerm_public_ip.failover_nat_gateway_ip[0].id
}

resource "azurerm_subnet" "deployment_script_container_subnet" {
  count = local.create_network_infrastructure ? 0 : 1

  name                 = azurecaf_name.deployment_script_names.results["azurerm_subnet"]
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network[0].name
  address_prefixes     = var.deployment_script_subnet_address_spaces
  service_endpoints    = ["Microsoft.Storage", "Microsoft.CognitiveServices"]
  delegation {
    name = "aci-delegation"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "deployment_script_nat" {
  count = local.create_network_infrastructure ? 0 : 1

  subnet_id      = azurerm_subnet.deployment_script_container_subnet[0].id
  nat_gateway_id = azurerm_nat_gateway.primary_nat_gateway[0].id
}

# ============================================================================
# NETWORK SECURITY GROUPS
# ============================================================================

# NSG for Power Platform primary subnet
resource "azurerm_network_security_group" "power_platform_primary_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  name                = azurecaf_name.main_names.results["azurerm_network_security_group"]
  location            = local.primary_azure_region
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Allow outbound HTTPS for Power Platform services
  security_rule {
    name                       = "Allow-PowerPlatform-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80"]
    source_address_prefixes    = var.primary_subnet_address_spaces
    destination_address_prefix = "*"
  }

  # Allow Azure Storage access
  security_rule {
    name                       = "Allow-Storage-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.primary_subnet_address_spaces
    destination_address_prefix = "Storage"
  }

  # Allow Azure Cognitive Services access
  security_rule {
    name                       = "Allow-CognitiveServices-Outbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.primary_subnet_address_spaces
    destination_address_prefix = "*"
  }

  # Allow inbound requests from deployment script subnet
  security_rule {
    name                         = "Allow-DeploymentScript-Inbound"
    priority                     = 130
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "*"
    source_address_prefixes      = var.deployment_script_subnet_address_spaces
    destination_address_prefixes = var.primary_subnet_address_spaces
  }
}

# NSG for Power Platform failover subnet
resource "azurerm_network_security_group" "power_platform_failover_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  name                = azurecaf_name.failover_names.results["azurerm_network_security_group"]
  location            = local.secondary_azure_region
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Allow outbound HTTPS for Power Platform services
  security_rule {
    name                       = "Allow-PowerPlatform-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80"]
    source_address_prefixes    = var.failover_subnet_address_spaces
    destination_address_prefix = "*"
  }

  # Allow Azure Storage access
  security_rule {
    name                       = "Allow-Storage-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.failover_subnet_address_spaces
    destination_address_prefix = "Storage"
  }

  # Allow Azure Cognitive Services access
  security_rule {
    name                       = "Allow-CognitiveServices-Outbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.failover_subnet_address_spaces
    destination_address_prefix = "*"
  }

  # Allow inbound requests from deployment script subnet (cross-region)
  security_rule {
    name                         = "Allow-DeploymentScript-Inbound"
    priority                     = 130
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "*"
    source_address_prefixes      = var.deployment_script_subnet_address_spaces
    destination_address_prefixes = var.failover_subnet_address_spaces
  }
}

# NSG for Private Endpoint subnets - Primary
resource "azurerm_network_security_group" "private_endpoint_primary_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  name                = azurecaf_name.main_pe_subnet_names.results["azurerm_subnet"]
  location            = local.primary_azure_region
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Allow inbound traffic from VNet to private endpoints
  security_rule {
    name                         = "Allow-VNet-Inbound"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = var.primary_vnet_address_spaces
    destination_address_prefixes = var.primary_pe_subnet_address_spaces
  }

  # Allow outbound from private endpoints to Azure services
  security_rule {
    name                       = "Allow-PrivateEndpoint-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.primary_pe_subnet_address_spaces
    destination_address_prefix = "*"
  }
}

# NSG for Private Endpoint subnets - Failover
resource "azurerm_network_security_group" "private_endpoint_failover_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  name                = azurecaf_name.failover_pe_subnet_names.results["azurerm_subnet"]
  location            = local.secondary_azure_region
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Allow inbound traffic from VNet to private endpoints
  security_rule {
    name                         = "Allow-VNet-Inbound"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = var.failover_vnet_address_spaces
    destination_address_prefixes = var.failover_pe_subnet_address_spaces
  }

  # Allow outbound from private endpoints to Azure services
  security_rule {
    name                       = "Allow-PrivateEndpoint-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.failover_pe_subnet_address_spaces
    destination_address_prefix = "*"
  }
}



# NSG for Deployment Script Container subnet - Enhanced with comprehensive rules
resource "azurerm_network_security_group" "deployment_script_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  name                = azurecaf_name.deployment_script_names.results["azurerm_network_security_group"]
  location            = local.primary_azure_region
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Allow outbound HTTPS for Azure services and package downloads
  security_rule {
    name                       = "Allow-Azure-Services-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80"]
    source_address_prefixes    = var.deployment_script_subnet_address_spaces
    destination_address_prefix = "*"
  }

  # Allow Storage access for script downloads and data uploads
  security_rule {
    name                       = "Allow-Storage-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.deployment_script_subnet_address_spaces
    destination_address_prefix = "Storage"
  }

  # Allow Azure AI Search access (via private endpoint)
  security_rule {
    name                         = "Allow-AISearch-Outbound"
    priority                     = 115
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = var.deployment_script_subnet_address_spaces
    destination_address_prefixes = var.primary_pe_subnet_address_spaces
  }

  # Allow Cognitive Services access for OpenAI and other AI services
  security_rule {
    name                       = "Allow-CognitiveServices-Outbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.deployment_script_subnet_address_spaces
    destination_address_prefix = "*"
  }

  # Allow Git clone operations (GitHub)
  security_rule {
    name                       = "Allow-Git-Outbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "22"]
    source_address_prefixes    = var.deployment_script_subnet_address_spaces
    destination_address_prefix = "*"
  }

  # Allow DNS resolution
  security_rule {
    name                       = "Allow-DNS-Outbound"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefixes    = var.deployment_script_subnet_address_spaces
    destination_address_prefix = "*"
  }

  # Allow Azure Resource Manager API access
  security_rule {
    name                       = "Allow-AzureRM-Outbound"
    priority                   = 150
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.deployment_script_subnet_address_spaces
    destination_address_prefix = "AzureResourceManager"
  }

  # Allow Azure Key Vault access
  security_rule {
    name                       = "Allow-KeyVault-Outbound"
    priority                   = 160
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.deployment_script_subnet_address_spaces
    destination_address_prefix = "AzureKeyVault"
  }

  # Allow Azure Active Directory access for managed identity authentication
  security_rule {
    name                       = "Allow-AAD-Outbound"
    priority                   = 170
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.deployment_script_subnet_address_spaces
    destination_address_prefix = "AzureActiveDirectory"
  }

  # Allow NTP for time synchronization
  security_rule {
    name                       = "Allow-NTP-Outbound"
    priority                   = 180
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "123"
    source_address_prefixes    = var.deployment_script_subnet_address_spaces
    destination_address_prefix = "*"
  }

  # Allow communication to private endpoints within VNet
  security_rule {
    name                         = "Allow-PrivateEndpoints-Outbound"
    priority                     = 190
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefixes      = var.deployment_script_subnet_address_spaces
    destination_address_prefixes = var.primary_vnet_address_spaces
  }
}

# ============================================================================
# NETWORK SECURITY GROUP ASSOCIATIONS
# ============================================================================

# Associate Power Platform primary NSG with primary subnet
resource "azurerm_subnet_network_security_group_association" "primary_subnet_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  subnet_id                 = azurerm_subnet.primary_subnet[0].id
  network_security_group_id = azurerm_network_security_group.power_platform_primary_nsg[0].id
}

# Associate Power Platform failover NSG with failover subnet
resource "azurerm_subnet_network_security_group_association" "failover_subnet_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  subnet_id                 = azurerm_subnet.failover_subnet[0].id
  network_security_group_id = azurerm_network_security_group.power_platform_failover_nsg[0].id
}

# Associate Private Endpoint NSG with primary PE subnet
resource "azurerm_subnet_network_security_group_association" "pe_primary_subnet_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  subnet_id                 = azurerm_subnet.pe_primary_subnet[0].id
  network_security_group_id = azurerm_network_security_group.private_endpoint_primary_nsg[0].id
}

# Associate Private Endpoint NSG with failover PE subnet
resource "azurerm_subnet_network_security_group_association" "pe_failover_subnet_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  subnet_id                 = azurerm_subnet.pe_failover_subnet[0].id
  network_security_group_id = azurerm_network_security_group.private_endpoint_failover_nsg[0].id
}



# Associate Deployment Script NSG with deployment script subnet
resource "azurerm_subnet_network_security_group_association" "deployment_script_subnet_nsg" {
  count = local.create_network_infrastructure ? 0 : 1

  subnet_id                 = azurerm_subnet.deployment_script_container_subnet[0].id
  network_security_group_id = azurerm_network_security_group.deployment_script_nsg[0].id
}

