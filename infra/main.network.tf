module "primary_virtual_network" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  version             = "0.8.1"
  resource_group_name = azurerm_resource_group.this.name
  subnets = merge(
    {
      "${var.primary_subnet_name}" = {
        name              = var.primary_subnet_name
        address_prefixes  = var.primary_subnet_address_spaces
        service_endpoints = ["Microsoft.Storage"]
        delegation = [{
          name = "Microsoft.PowerPlatform/enterprisePolicies"
          service_delegation = {
            name    = "Microsoft.PowerPlatform/enterprisePolicies"
            actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
          }
          }
        ]
        nat_gateway = {
          id = azurerm_nat_gateway.primary_nat_gateway.id
        }
      }
    },
    {
      ai-search-primary-subnet = {
        name             = "ai-search-primary-subnet"
        address_prefixes = var.primary_ai_search_subnet_address_spaces
        nat_gateway = {
          id = azurerm_nat_gateway.primary_nat_gateway.id
        }
      }
    }
  )
  address_space = var.primary_vnet_address_spaces
  location      = var.primary_location
  name          = "power-platform-primary-vnet-${random_string.name.id}"
  tags          = var.tags
}

module "failover_virtual_network" {
  source              = "Azure/avm-res-network-virtualnetwork/azurerm"
  version             = "0.8.1"
  resource_group_name = azurerm_resource_group.this.name
  subnets = merge(
    {
      "${var.failover_subnet_name}" = {
        name              = var.failover_subnet_name
        address_prefixes  = var.failover_subnet_address_spaces
        service_endpoints = ["Microsoft.Storage"]
        delegation = [{
          name = "Microsoft.PowerPlatform/enterprisePolicies"
          service_delegation = {
            name    = "Microsoft.PowerPlatform/enterprisePolicies"
            actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
          }
          }
        ]
        nat_gateway = {
          id = azurerm_nat_gateway.failover_nat_gateway.id
        }
      }
    },
    {
      ai-search-failover-subnet = {
        name             = "ai-search-failover-subnet"
        address_prefixes = var.failover_ai_search_subnet_address_spaces
        nat_gateway = {
          id = azurerm_nat_gateway.failover_nat_gateway.id
        }
      }
    }
  )
  address_space = var.failover_vnet_address_spaces
  location      = var.failover_location
  name          = "power-platform-failover-vnet-${random_string.name.id}"
  tags          = var.tags
}

#---- Set up NAT gateways, which are not initialized by the AVM ----

# Primary VNet NAT gateway
resource "azurerm_nat_gateway" "primary_nat_gateway" {
  location            = var.primary_location
  name                = "primary-nat-gateway"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"
}

# Secondary VNet NAT gateway

resource "azurerm_nat_gateway" "failover_nat_gateway" {
  location            = var.failover_location
  name                = "failover-nat-gateway"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"
}

# TODO add a proper polling mechanism instead of wait
resource "time_sleep" "wait_for_network" {
  create_duration = "30s" # Wait for 30 seconds

  depends_on = [module.primary_virtual_network, module.failover_virtual_network]
}
