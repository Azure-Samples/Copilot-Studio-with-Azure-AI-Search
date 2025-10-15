# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# Resource Group Configuration and Management
# This file contains resource group resources and related diagnostic settings

# Resource group logic - use existing or create new
locals {
  use_existing_resource_group = var.resource_group_name != null && var.resource_group_name != ""
  resource_group_name         = local.use_existing_resource_group ? var.resource_group_name : azurerm_resource_group.this[0].name
  resource_group_id           = local.use_existing_resource_group ? data.azurerm_resource_group.existing[0].id : azurerm_resource_group.this[0].id
}

# Data source to validate existing resource group exists
data "azurerm_resource_group" "existing" {
  count = local.use_existing_resource_group ? 1 : 0
  name  = var.resource_group_name
}

# The Resource Group that will contain the resources managed by this module (only created if not using existing)
resource "azurerm_resource_group" "this" {
  count    = local.use_existing_resource_group ? 0 : 1
  location = local.primary_azure_region
  name     = azurecaf_name.main_names.results["azurerm_resource_group"]
  tags     = merge(var.tags, local.env_tags)
}
