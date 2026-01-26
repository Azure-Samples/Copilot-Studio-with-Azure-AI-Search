# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

terraform {
  required_version = ">= 1.6.0, < 2.0.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "2.8.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.57.0"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "0.3.5"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.0"
    }
  }
}