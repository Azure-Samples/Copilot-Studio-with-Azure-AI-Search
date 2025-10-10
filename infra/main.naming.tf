# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# Unique naming for Azure resources using Azure CAF naming conventions

locals {
  # Organization suffixes and prefixes are optional, and we need to form an array of non-empty values only
  org_prefix = compact([var.org_naming.org_prefix])
  org_suffix = compact([var.org_naming.org_environment, var.org_naming.org_suffix])
}

# Generate unique names for primary resources
resource "azurecaf_name" "main_names" {
  name = var.org_naming.workload_name
  resource_types = [
    "azurerm_resource_group",
    "azurerm_storage_account",
    "azurerm_search_service",
    "azurerm_cognitive_account",
    "azurerm_virtual_network",
    "azurerm_network_security_group",
    "azurerm_virtual_network_gateway",
    "azurerm_public_ip"
  ]
  prefixes      = local.org_prefix
  suffixes      = local.org_suffix
  random_length = 4
  # use_slug = false
  clean_input = true
}

# Generate unique names for failover resources
resource "azurecaf_name" "failover_names" {
  name = var.org_naming.workload_name
  resource_types = [
    "azurerm_virtual_network",
    "azurerm_network_security_group",
    "azurerm_virtual_network_gateway",
    "azurerm_public_ip"
  ]
  prefixes      = local.org_prefix
  suffixes      = concat(local.org_suffix, ["failover"])
  random_length = 4
  # use_slug = false
  clean_input = true
}

# Generate unique names for primary private endpoint subnet
resource "azurecaf_name" "main_pe_subnet_names" {
  name = var.org_naming.workload_name
  resource_types = [
    "azurerm_subnet"
  ]
  prefixes      = concat(["pe"], local.org_prefix)
  suffixes      = concat(local.org_suffix, ["primary"])
  random_length = 4
  # use_slug = false
  clean_input = true
}

# Generate unique names for failover private endpoint subnet
resource "azurecaf_name" "failover_pe_subnet_names" {
  name = var.org_naming.workload_name
  resource_types = [
    "azurerm_subnet"
  ]
  prefixes      = concat(["pe"], local.org_prefix)
  suffixes      = concat(local.org_suffix, ["failover"])
  random_length = 4
  # use_slug = false
  clean_input = true
}

# Generate unique names for Azure Deployment Script related resources
resource "azurecaf_name" "deployment_script_names" {
  name = var.org_naming.workload_name
  resource_types = [
    "azurerm_storage_account",
    "azurerm_network_security_group",
    "azurerm_subnet",
    "azurerm_user_assigned_identity"
  ]
  prefixes      = local.org_prefix
  suffixes      = concat(local.org_suffix, ["script"])
  random_length = 4
  # use_slug = false
  clean_input = true
}
