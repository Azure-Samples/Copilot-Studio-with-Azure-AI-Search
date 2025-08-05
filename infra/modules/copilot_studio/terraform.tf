terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "2.5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.38.1"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "0.3.5"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "3.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}