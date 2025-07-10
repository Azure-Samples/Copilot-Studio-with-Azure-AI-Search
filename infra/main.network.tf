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
  service_endpoints    = ["Microsoft.CognitiveServices"]

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
  service_endpoints    = ["Microsoft.CognitiveServices"]

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
  service_endpoints    = ["Microsoft.CognitiveServices"]

  # Required for private endpoints
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "pe_failover_subnet" {
  name                 = "pe-failover-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.failover_virtual_network.name
  address_prefixes     = var.failover_pe_subnet_address_spaces
  service_endpoints    = ["Microsoft.CognitiveServices"]

  # Required for private endpoints
  private_endpoint_network_policies = "Enabled"
}

#---- Set up GitHub Runners ----

resource "azurerm_subnet" "github_runner_primary_subnet" {
  count                = var.deploy_github_runner ? 1 : 0
  name                 = "github-runner-primary-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network.name
  address_prefixes     = var.primary_gh_runner_subnet_address_spaces
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "Microsoft.App/environments"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "github_runner_primary_subnet_nat" {
  count          = var.deploy_github_runner ? 1 : 0
  subnet_id      = azurerm_subnet.github_runner_primary_subnet[0].id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["primary"].id
}

resource "azurerm_subnet" "github_runner_failover_subnet" {
  count                = var.deploy_github_runner ? 1 : 0
  name                 = "github-runner-failover-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.failover_virtual_network.name
  address_prefixes     = var.failover_gh_runner_subnet_address_spaces
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "Microsoft.App/environments"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "github_runner_failover_subnet_nat" {
  count          = var.deploy_github_runner ? 1 : 0
  subnet_id      = azurerm_subnet.github_runner_failover_subnet[0].id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["failover"].id
}

#---- Set up NAT gateways, which are not initialized by the AVM ----

resource "azurerm_public_ip" "nat" {
  for_each = {
    primary1  = var.primary_location,
    failover1 = var.failover_location,
  }
  name                = "${each.key}-pip"
  location            = each.value
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

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

resource "azurerm_nat_gateway_public_ip_association" "primary_ip" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gateways["primary"].id
  public_ip_address_id = azurerm_public_ip.nat["primary1"].id
}

resource "azurerm_nat_gateway_public_ip_association" "failover_ip" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gateways["failover"].id
  public_ip_address_id = azurerm_public_ip.nat["failover1"].id
}
