# azurerm_nat_gateway: Incomplete Best Practices

##
/workspaces/Copilot-Studio-with-Azure-AI-Search/infra/main.network.tf

## Problem

In the `azurerm_nat_gateway` resource, only base configuration is given (location, name, resource_group_name, sku_name). It omits definition of:
- `public_ip_address_ids` or `public_ip_prefix_ids` (no outbound connectivity is actually configured)
- `idle_timeout_in_minutes` (uses default value)
- No tags or diagnostics encouraged for best practice
- No association with route tables or subnet delegations outside of NAT subnet association blocks

This can lead to a NAT gateway getting created without actual public IP attachment, which means no outbound traffic will work. This is a common source of confusion in Azure VNet deployments.

## Impact

- NAT gateway may exist without functional outbound connectivity, breaking communication from subnets expecting to route through NAT
- Observability and cost tracking is reduced
- Missed opportunity for improving security posture via diagnostics configuration
- Deployment may give false sense of enabled secure outbound access

**Severity: Medium**

## Location

- /infra/main.network.tf (resource `azurerm_nat_gateway.nat_gateways`)

## Code Issue

```text
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
```

## Fix

- Attach one or more public IP addresses or prefixes and set via `public_ip_address_ids` or `public_ip_prefix_ids` explicitly (requires creation of those resources)
- Set `idle_timeout_in_minutes` for explicit session control
- Add tags and optionally diagnostics settings:

```text
resource "azurerm_public_ip" "nat" {
  for_each = {
    primary  = var.primary_location
    failover = var.failover_location
  }
  name                = "${each.key}-nat-ip"
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
  location                = each.value
  name                    = "${each.key}-nat-gateway"
  resource_group_name     = azurerm_resource_group.this.name
  sku_name                = "Standard"
  public_ip_address_ids   = [azurerm_public_ip.nat[each.key].id]
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}
```

- Add documentation or checks for outbound traffic
- Add diagnostics if needed
