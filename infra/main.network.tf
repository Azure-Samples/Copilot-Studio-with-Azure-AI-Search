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
  subnet_id      = azurerm_subnet.primary_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["primary"].id
}

# Create failover subnets as first-class resources
resource "azurerm_subnet" "failover_subnet" {
  name                 = var.failover_subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.failover_virtual_network.name
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
  subnet_id      = azurerm_subnet.failover_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["failover"].id
}

# Create dedicated private endpoint subnets without delegations
resource "azurerm_subnet" "pe_primary_subnet" {
  name                 = "pe-primary-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network.name
  address_prefixes     = var.primary_pe_subnet_address_spaces
  service_endpoints    = ["Microsoft.CognitiveServices", "Microsoft.Storage"]

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

# Create public IP addresses for NAT gateways
resource "azurerm_public_ip" "nat_gateway_ips" {
  for_each = {
    primary  = var.primary_location
    failover = var.failover_location
  }

  name                = "${each.key}-nat-gateway-ip"
  location            = each.value
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
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
  tags                = var.tags

  # Associate the public IP address with the NAT gateway
  depends_on = [azurerm_public_ip.nat_gateway_ips]
}

# Associate public IP addresses with NAT gateways
resource "azurerm_nat_gateway_public_ip_association" "nat_gateway_ip_associations" {
  for_each = {
    primary  = var.primary_location
    failover = var.failover_location
  }

  nat_gateway_id       = azurerm_nat_gateway.nat_gateways[each.key].id
  public_ip_address_id = azurerm_public_ip.nat_gateway_ips[each.key].id
}

resource "azurerm_subnet" "deployment_script_container" {
  name                 = "deploymentscript-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.primary_virtual_network.name
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
  subnet_id      = azurerm_subnet.deployment_script_container.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways["primary"].id
}

# ============================================================================
# NETWORK SECURITY GROUPS
# ============================================================================

# # NSG for Power Platform primary subnet
# resource "azurerm_network_security_group" "power_platform_primary_nsg" {
#   name                = "power-platform-primary-nsg-${random_string.name.id}"
#   location            = var.primary_location
#   resource_group_name = azurerm_resource_group.this.name
#   tags                = var.tags

#   # Allow outbound HTTPS for Power Platform services from primary subnet
#   security_rule {
#     name                       = "Allow-PowerPlatform-Outbound"
#     priority                   = 100
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_ranges    = ["443", "80"]
#     source_address_prefixes    = var.primary_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow Azure Storage access from primary subnet
#   security_rule {
#     name                       = "Allow-Storage-Outbound"
#     priority                   = 110
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = var.primary_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow Azure Cognitive Services access from primary subnet
#   security_rule {
#     name                       = "Allow-CognitiveServices-Outbound"
#     priority                   = 120
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = var.primary_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow inbound requests from the deployment script subnet
#   security_rule {
#     name                       = "Allow-DeploymentScript-Inbound"
#     priority                   = 130
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "*"
#     source_address_prefixes    = var.deployment_script_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # # Deny all other inbound traffic by default
#   # security_rule {
#   #   name                       = "Deny-All-Inbound"
#   #   priority                   = 4000
#   #   direction                  = "Inbound"
#   #   access                     = "Deny"
#   #   protocol                   = "*"
#   #   source_port_range          = "*"
#   #   destination_port_range     = "*"
#   #   source_address_prefix      = "*"
#   #   destination_address_prefix = "*"
#   # }
# }

# # NSG for Power Platform failover subnet
# resource "azurerm_network_security_group" "power_platform_failover_nsg" {
#   name                = "power-platform-failover-nsg-${random_string.name.id}"
#   location            = var.failover_location
#   resource_group_name = azurerm_resource_group.this.name
#   tags                = var.tags

#   # Allow outbound HTTPS for Power Platform services from failover subnet
#   security_rule {
#     name                       = "Allow-PowerPlatform-Outbound"
#     priority                   = 100
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_ranges    = ["443", "80"]
#     source_address_prefixes    = var.failover_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow Azure Storage access from failover subnet
#   security_rule {
#     name                       = "Allow-Storage-Outbound"
#     priority                   = 110
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = var.failover_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow Azure Cognitive Services access from failover subnet
#   security_rule {
#     name                       = "Allow-CognitiveServices-Outbound"
#     priority                   = 120
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = var.failover_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow inbound requests from the deployment script subnet
#   security_rule {
#     name                       = "Allow-DeploymentScript-Inbound"
#     priority                   = 130
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "*"
#     source_address_prefixes    = var.deployment_script_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # # Deny all other inbound traffic by default
#   # security_rule {
#   #   name                       = "Deny-All-Inbound"
#   #   priority                   = 4000
#   #   direction                  = "Inbound"
#   #   access                     = "Deny"
#   #   protocol                   = "*"
#   #   source_port_range          = "*"
#   #   destination_port_range     = "*"
#   #   source_address_prefix      = "*"
#   #   destination_address_prefix = "*"
#   # }
# }

# # NSG for Private Endpoint subnets - Primary
# resource "azurerm_network_security_group" "private_endpoint_primary_nsg" {
#   name                = "private-endpoint-primary-nsg-${random_string.name.id}"
#   location            = var.primary_location
#   resource_group_name = azurerm_resource_group.this.name
#   tags                = var.tags

#   # Allow inbound traffic from VNet to private endpoints
#   security_rule {
#     name                         = "Allow-VNet-Inbound"
#     priority                     = 100
#     direction                    = "Inbound"
#     access                       = "Allow"
#     protocol                     = "Tcp"
#     source_port_range            = "*"
#     destination_port_range       = "443"
#     source_address_prefixes      = var.primary_vnet_address_spaces
#     destination_address_prefixes = var.primary_pe_subnet_address_spaces
#   }

#   # Allow outbound to private endpoints
#   security_rule {
#     name                       = "Allow-PrivateEndpoint-Outbound"
#     priority                   = 100
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = var.primary_pe_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # # Deny all other traffic
#   # security_rule {
#   #   name                       = "Deny-All-Inbound"
#   #   priority                   = 4000
#   #   direction                  = "Inbound"
#   #   access                     = "Deny"
#   #   protocol                   = "*"
#   #   source_port_range          = "*"
#   #   destination_port_range     = "*"
#   #   source_address_prefix      = "*"
#   #   destination_address_prefix = "*"
#   # }
# }

# # NSG for Private Endpoint subnets - Failover
# resource "azurerm_network_security_group" "private_endpoint_failover_nsg" {
#   name                = "private-endpoint-failover-nsg-${random_string.name.id}"
#   location            = var.failover_location
#   resource_group_name = azurerm_resource_group.this.name
#   tags                = var.tags

#   # Allow inbound traffic from VNet to private endpoints
#   security_rule {
#     name                         = "Allow-VNet-Inbound"
#     priority                     = 100
#     direction                    = "Inbound"
#     access                       = "Allow"
#     protocol                     = "Tcp"
#     source_port_range            = "*"
#     destination_port_range       = "443"
#     source_address_prefixes      = var.failover_vnet_address_spaces
#     destination_address_prefixes = var.failover_pe_subnet_address_spaces
#   }

#   # Allow outbound to private endpoints
#   security_rule {
#     name                       = "Allow-PrivateEndpoint-Outbound"
#     priority                   = 100
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = var.failover_pe_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # # Deny all other traffic
#   # security_rule {
#   #   name                       = "Deny-All-Inbound"
#   #   priority                   = 4000
#   #   direction                  = "Inbound"
#   #   access                     = "Deny"
#   #   protocol                   = "*"
#   #   source_port_range          = "*"
#   #   destination_port_range     = "*"
#   #   source_address_prefix      = "*"
#   #   destination_address_prefix = "*"
#   # }
# }

# # NSG for GitHub Runner subnets (Container Apps)
# resource "azurerm_network_security_group" "github_runner_nsg" {
#   count               = var.deploy_github_runner ? 1 : 0
#   name                = "github-runner-nsg-${random_string.name.id}"
#   location            = var.primary_location
#   resource_group_name = azurerm_resource_group.this.name
#   tags                = var.tags

#   # Allow outbound HTTPS for GitHub and container registry access
#   security_rule {
#     name                       = "Allow-GitHub-Outbound"
#     priority                   = 100
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_ranges    = ["443", "80"]
#     source_address_prefixes    = concat(var.primary_gh_runner_subnet_address_spaces, var.failover_gh_runner_subnet_address_spaces)
#     destination_address_prefix = "*"
#   }

#   # Allow outbound to Azure Container Registry
#   security_rule {
#     name                       = "Allow-ACR-Outbound"
#     priority                   = 110
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = concat(var.primary_gh_runner_subnet_address_spaces, var.failover_gh_runner_subnet_address_spaces)
#     destination_address_prefix = "*"
#   }

#   # Allow Storage access for Container Apps
#   security_rule {
#     name                       = "Allow-Storage-Outbound"
#     priority                   = 120
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = concat(var.primary_gh_runner_subnet_address_spaces, var.failover_gh_runner_subnet_address_spaces)
#     destination_address_prefix = "*"
#   }

#   # Container Apps management traffic
#   security_rule {
#     name                       = "Allow-ContainerApps-Management"
#     priority                   = 130
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_ranges    = ["443", "5671", "5672"]
#     source_address_prefixes    = concat(var.primary_gh_runner_subnet_address_spaces, var.failover_gh_runner_subnet_address_spaces)
#     destination_address_prefix = "*"
#   }
# }

# # NSG for Deployment Script Container subnet
# resource "azurerm_network_security_group" "deployment_script_nsg" {
#   name                = "deployment-script-nsg-${random_string.name.id}"
#   location            = var.primary_location
#   resource_group_name = azurerm_resource_group.this.name
#   tags                = var.tags

#   # Allow outbound HTTPS for Azure services and package downloads
#   security_rule {
#     name                       = "Allow-Azure-Services-Outbound"
#     priority                   = 100
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_ranges    = ["443", "80"]
#     source_address_prefixes    = var.deployment_script_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow Storage access for script downloads and data uploads
#   security_rule {
#     name                       = "Allow-Storage-Outbound"
#     priority                   = 110
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = var.deployment_script_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow inbound Storage traffic from deployment script subnet
#   security_rule {
#     name                       = "Allow-Storage-Inbound"
#     priority                   = 115
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = var.deployment_script_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow Cognitive Services access for AI Search and OpenAI
#   security_rule {
#     name                       = "Allow-CognitiveServices-Outbound"
#     priority                   = 120
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefixes    = var.deployment_script_subnet_address_spaces
#     destination_address_prefix = "*"
#   }

#   # Allow Git clone operations (GitHub)
#   security_rule {
#     name                       = "Allow-Git-Outbound"
#     priority                   = 130
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_ranges    = ["443", "22"]
#     source_address_prefixes    = var.deployment_script_subnet_address_spaces
#     destination_address_prefix = "*"
#   }
# }

# ============================================================================
# NETWORK SECURITY GROUP ASSOCIATIONS
# ============================================================================

# # Associate Power Platform primary NSG with primary subnet
# resource "azurerm_subnet_network_security_group_association" "primary_subnet_nsg" {
#   subnet_id                 = azurerm_subnet.primary_subnet.id
#   network_security_group_id = azurerm_network_security_group.power_platform_primary_nsg.id
# }

# # Associate Power Platform failover NSG with failover subnet
# resource "azurerm_subnet_network_security_group_association" "failover_subnet_nsg" {
#   subnet_id                 = azurerm_subnet.failover_subnet.id
#   network_security_group_id = azurerm_network_security_group.power_platform_failover_nsg.id
# }

# # Associate Private Endpoint NSG with primary PE subnet
# resource "azurerm_subnet_network_security_group_association" "pe_primary_subnet_nsg" {
#   subnet_id                 = azurerm_subnet.pe_primary_subnet.id
#   network_security_group_id = azurerm_network_security_group.private_endpoint_primary_nsg.id
# }

# # Associate Private Endpoint NSG with failover PE subnet
# resource "azurerm_subnet_network_security_group_association" "pe_failover_subnet_nsg" {
#   subnet_id                 = azurerm_subnet.pe_failover_subnet.id
#   network_security_group_id = azurerm_network_security_group.private_endpoint_failover_nsg.id
# }

# # Associate GitHub Runner NSG with primary GitHub runner subnet (conditional)
# resource "azurerm_subnet_network_security_group_association" "github_runner_primary_subnet_nsg" {
#   count                     = var.deploy_github_runner ? 1 : 0
#   subnet_id                 = azurerm_subnet.github_runner_primary_subnet[0].id
#   network_security_group_id = azurerm_network_security_group.github_runner_nsg[0].id
# }

# # Associate GitHub Runner NSG with failover GitHub runner subnet (conditional)
# resource "azurerm_subnet_network_security_group_association" "github_runner_failover_subnet_nsg" {
#   count                     = var.deploy_github_runner ? 1 : 0
#   subnet_id                 = azurerm_subnet.github_runner_failover_subnet[0].id
#   network_security_group_id = azurerm_network_security_group.github_runner_nsg[0].id
# }

# # Associate Deployment Script NSG with deployment script subnet
# resource "azurerm_subnet_network_security_group_association" "deployment_script_subnet_nsg" {
#   subnet_id                 = azurerm_subnet.deployment_script_container.id
#   network_security_group_id = azurerm_network_security_group.deployment_script_nsg.id
# }

