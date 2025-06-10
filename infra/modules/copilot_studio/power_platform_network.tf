# Automate the steps documented at https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure 

#---- 1 - Add Enterprise Policy ----

# Get details on the primary and failover VNets for use in generating the policy 
data "azurerm_virtual_network" "primary_vnet" {
  name                = var.primary_vnet_name
  resource_group_name = var.resource_group_name
}
data "azurerm_virtual_network" "failover_vnet" {
  name                = var.failover_vnet_name
  resource_group_name = var.resource_group_name
}
data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

# Create enterprise policy to allow Power Platform to connect to the relevant subnets
resource "azapi_resource" "network_injection_policy" {
  type = "Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview"
  body = {
    properties = {
      networkInjection = {
        virtualNetworks = [
          {
            id = data.azurerm_virtual_network.primary_vnet.id
            subnet = {
              name = var.primary_subnet_name
            }
          },
          {
            id = data.azurerm_virtual_network.failover_vnet.id
            subnet = {
              name = var.failover_subnet_name
            }
          }
        ]
      }
    }
    kind = "NetworkInjection"
  }
  location                  = local.power_platform_environment_location
  tags                      = var.tags
  name                      = "PowerPlatformPrimaryPolicy-${var.unique_id}"
  parent_id                 = data.azurerm_resource_group.this.id
  schema_validation_enabled = false
}

#---- 2 - Set EP access using RBAC ----

# Grant Power Platform admin access to the new enterprise policy
resource "azurerm_role_assignment" "principal_enterprise_policy_access" {
  for_each             = length(var.resource_share_user) > 0 ? var.resource_share_user : {}
  principal_id         = each.value
  scope                = azapi_resource.network_injection_policy.id
  role_definition_name = "Reader"
}

#---- 3 - Connect Power Platform to the network ----

# Connect the Power Platform environment to the newly deployed Enterprise Policy
resource "powerplatform_enterprise_policy" "environment_policy" {
  environment_id = local.power_platform_environment_id
  system_id      = azapi_resource.network_injection_policy.output.properties.systemId
  policy_type    = "NetworkInjection"

  depends_on = [powerplatform_managed_environment.this]
}
