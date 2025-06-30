# Create virtual networks directly instead of using AVMs - necessary due to timing issues when a first-class resource dependency is unavailable.
resource "azurerm_virtual_network" "primary_virtual_network" {
  name                = "power-platform-primary-vnet-${random_string.name.id}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.primary_location
  address_space       = var.primary_vnet_address_spaces
  tags                = var.tags
}

resource "azurerm_virtual_network" "failover_virtual_network" {
  name                = "power-platform-failover-vnet-${random_string.name.id}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.failover_location
  address_space       = var.failover_vnet_address_spaces
  tags                = var.tags
}

# Create primary subnets as first-class resources
resource "azurerm_subnet" "primary_subnet" {
  name                 = var.primary_subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network.name
  address_prefixes     = var.primary_subnet_address_spaces
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "Microsoft.PowerPlatform/enterprisePolicies"
    service_delegation {
      name    = "Microsoft.PowerPlatform/enterprisePolicies"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "primary_subnet_nat" {
  subnet_id      = azurerm_subnet.primary_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["primary"].id
}

resource "azurerm_subnet" "ai_search_primary_subnet" {
  name                 = "ai-search-primary-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network.name
  address_prefixes     = var.primary_ai_search_subnet_address_spaces

  delegation {
    name = "Microsoft.PowerPlatform/enterprisePolicies"

    service_delegation {
      name    = "Microsoft.PowerPlatform/enterprisePolicies"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "ai_search_primary_subnet_nat" {
  subnet_id      = azurerm_subnet.ai_search_primary_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["primary"].id
}

# Create failover subnets as first-class resources
resource "azurerm_subnet" "failover_subnet" {
  name                 = var.failover_subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.failover_virtual_network.name
  address_prefixes     = var.failover_subnet_address_spaces
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "Microsoft.PowerPlatform/enterprisePolicies"
    service_delegation {
      name    = "Microsoft.PowerPlatform/enterprisePolicies"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "failover_subnet_nat" {
  subnet_id      = azurerm_subnet.failover_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["failover"].id
}

resource "azurerm_subnet" "ai_search_failover_subnet" {
  name                 = "ai-search-failover-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.failover_virtual_network.name
  address_prefixes     = var.failover_ai_search_subnet_address_spaces

  delegation {
    name = "Microsoft.PowerPlatform/enterprisePolicies"

    service_delegation {
      name    = "Microsoft.PowerPlatform/enterprisePolicies"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "ai_search_failover_subnet_nat" {
  subnet_id      = azurerm_subnet.ai_search_failover_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["failover"].id
}

# Create dedicated private endpoint subnets without delegations
resource "azurerm_subnet" "pe_primary_subnet" {
  name                 = "pe-primary-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network.name
  address_prefixes     = var.primary_pe_subnet_address_spaces

  # Required for private endpoints
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "pe_failover_subnet" {
  name                 = "pe-failover-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.failover_virtual_network.name
  address_prefixes     = var.failover_pe_subnet_address_spaces

  # Required for private endpoints
  private_endpoint_network_policies = "Enabled"
}

#---- Set up NAT gateways, which are not initialized by the AVM ----

resource "azurerm_nat_gateway" "nat_gateways" {
  for_each = {
    primary  = var.primary_location
    failover = var.failover_location
  }

  location            = each.value
  name                = "${each.key}-nat-gateway"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"


}

resource "azurerm_subnet" "deployment_script" {
  name                 = "deploymentscript-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network.name
  address_prefixes     = ["10.1.9.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
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
  subnet_id      = azurerm_subnet.deployment_script.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["primary"].id
}