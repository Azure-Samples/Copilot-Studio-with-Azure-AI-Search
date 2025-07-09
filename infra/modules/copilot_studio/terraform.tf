terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "2.5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.35.0"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "0.3.2"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "3.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}