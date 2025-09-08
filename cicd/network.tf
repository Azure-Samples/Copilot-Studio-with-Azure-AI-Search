# Create Virtual Network
resource "azurerm_virtual_network" "tfstate" {
  name                = local.vnet_name
  address_space       = var.network_config.vnet_address_space
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  tags                = local.common_tags
}
