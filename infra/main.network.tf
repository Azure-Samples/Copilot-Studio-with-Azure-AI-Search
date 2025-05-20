module "primary_virtual_network" {
  source = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork.git?ref=f72c7f0d88132c41659a00cc124d9236b124ed79"

  resource_group_name = azurerm_resource_group.this.name
  subnets = merge(
    {
      (var.primary_subnet_name) = {
        name              = var.primary_subnet_name
        address_prefixes  = var.primary_subnet_address_spaces
        service_endpoints = ["Microsoft.Storage"]
        delegation = [{
          name = "Microsoft.PowerPlatform/enterprisePolicies"
          service_delegation = {
            name    = "Microsoft.PowerPlatform/enterprisePolicies"
            actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
          }
        }]
        nat_gateway = {
          id = azurerm_nat_gateway.nat_gateways["primary"].id
        }
      }
    },
    {
      ai-search-primary-subnet = {
        name             = "ai-search-primary-subnet"
        address_prefixes = var.primary_ai_search_subnet_address_spaces
        nat_gateway = {
          id = azurerm_nat_gateway.nat_gateways["primary"].id
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
  source              = "git::https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork.git?ref=f72c7f0d88132c41659a00cc124d9236b124ed79"
  resource_group_name = azurerm_resource_group.this.name
  subnets = merge(
    {
      (var.failover_subnet_name) = {
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
          id = azurerm_nat_gateway.nat_gateways["failover"].id
        }
      }
    },
    {
      ai-search-failover-subnet = {
        name             = "ai-search-failover-subnet"
        address_prefixes = var.failover_ai_search_subnet_address_spaces
        nat_gateway = {
          id = azurerm_nat_gateway.nat_gateways["failover"].id
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

# TODO add a proper polling mechanism instead of wait
resource "time_sleep" "wait_for_network" {
  create_duration = "30s" # Wait for 30 seconds

  depends_on = [module.primary_virtual_network, module.failover_virtual_network]
}
