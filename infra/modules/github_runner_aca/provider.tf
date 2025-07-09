terraform {
  required_version = ">= 1.1.7, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.35.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "2.4.0"
    }
  }
}
