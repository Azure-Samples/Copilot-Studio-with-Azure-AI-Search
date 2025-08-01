#---- Set up GitHub Runners ----

resource "azurerm_subnet" "github_runner_primary_subnet" {
  # checkov:skip=CKV2_AZURE_31:"Ensure VNET subnet is configured with a Network Security Group (NSG)
  count = var.deploy_github_runner && local.create_network_infrastructure == false ? 1 : 0

  name                 = "github-runner-primary-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network[0].name
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
  count = var.deploy_github_runner && local.create_network_infrastructure == false ? 1 : 0

  subnet_id      = azurerm_subnet.github_runner_primary_subnet[0].id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["primary"].id
}

# resource "azurerm_subnet" "github_runner_failover_subnet" {
#   # checkov:skip=CKV2_AZURE_31:"Ensure VNET subnet is configured with a Network Security Group (NSG)
#   count = var.deploy_github_runner && local.create_network_infrastructure == false ? 1 : 0

#   name                 = "github-runner-failover-subnet"
#   resource_group_name  = local.resource_group_name
#   virtual_network_name = azurerm_virtual_network.failover_virtual_network[0].name
#   address_prefixes     = var.failover_gh_runner_subnet_address_spaces
#   service_endpoints    = ["Microsoft.Storage"]

#   delegation {
#     name = "Microsoft.App/environments"

#     service_delegation {
#       name    = "Microsoft.App/environments"
#       actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
#     }
#   }
# }

resource "azurerm_subnet_nat_gateway_association" "github_runner_failover_subnet_nat" {
  count = var.deploy_github_runner && local.create_network_infrastructure == false ? 1 : 0

  subnet_id      = azurerm_subnet.github_runner_failover_subnet[0].id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["failover"].id
}

# NSG for GitHub Runner subnets (Container Apps)
resource "azurerm_network_security_group" "github_runner_nsg" {
  count               = var.deploy_github_runner && local.create_network_infrastructure == false ? 1 : 0
  name                = "github-runner-nsg-${random_string.name.id}"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Allow outbound HTTPS for GitHub and container registry access
  security_rule {
    name                    = "Allow-GitHub-Outbound"
    priority                = 100
    direction               = "Outbound"
    access                  = "Allow"
    protocol                = "Tcp"
    source_port_range       = "*"
    destination_port_ranges = ["443", "80"]
    source_address_prefixes = concat(
      var.primary_gh_runner_subnet_address_spaces,
      var.deploy_github_runner && var.enable_failover_github_runner ? var.failover_gh_runner_subnet_address_spaces : []
    )
    destination_address_prefix = "*"
  }

  # Allow outbound to Azure Container Registry
  security_rule {
    name                   = "Allow-ACR-Outbound"
    priority               = 110
    direction              = "Outbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "443"
    source_address_prefixes = concat(
      var.primary_gh_runner_subnet_address_spaces,
      var.deploy_github_runner && var.enable_failover_github_runner ? var.failover_gh_runner_subnet_address_spaces : []
    )
    destination_address_prefix = "*"
  }

  # Allow Storage access for Container Apps
  security_rule {
    name                   = "Allow-Storage-Outbound"
    priority               = 120
    direction              = "Outbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "443"
    source_address_prefixes = concat(
      var.primary_gh_runner_subnet_address_spaces,
      var.deploy_github_runner && var.enable_failover_github_runner ? var.failover_gh_runner_subnet_address_spaces : []
    )
    destination_address_prefix = "Storage"
  }

  # Container Apps management traffic
  security_rule {
    name                    = "Allow-ContainerApps-Management"
    priority                = 130
    direction               = "Outbound"
    access                  = "Allow"
    protocol                = "Tcp"
    source_port_range       = "*"
    destination_port_ranges = ["443", "5671", "5672"]
    source_address_prefixes = concat(
      var.primary_gh_runner_subnet_address_spaces,
      var.deploy_github_runner && var.enable_failover_github_runner ? var.failover_gh_runner_subnet_address_spaces : []
    )
    destination_address_prefix = "*"
  }
}

# Associate GitHub Runner NSG with primary GitHub runner subnet (conditional)
resource "azurerm_subnet_network_security_group_association" "github_runner_primary_subnet_nsg" {
  count                     = var.deploy_github_runner && local.create_network_infrastructure == false ? 1 : 0
  subnet_id                 = azurerm_subnet.github_runner_primary_subnet[0].id
  network_security_group_id = azurerm_network_security_group.github_runner_nsg[0].id
}

# Associate GitHub Runner NSG with failover GitHub runner subnet (conditional)
resource "azurerm_subnet_network_security_group_association" "github_runner_failover_subnet_nsg" {
  count                     = var.deploy_github_runner && var.enable_failover_github_runner && local.create_network_infrastructure == false ? 1 : 0
  subnet_id                 = azurerm_subnet.github_runner_failover_subnet[0].id
  network_security_group_id = azurerm_network_security_group.github_runner_nsg[0].id
}