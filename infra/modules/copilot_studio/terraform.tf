# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

terraform {
  required_version = ">= 1.6.0, < 2.0.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "2.10.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.78.0"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "0.4.0"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "4.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
  }
}