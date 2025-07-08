# Configure desired versions of terraform, azurerm provider
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
terraform {
  required_version = ">= 1.1.7, < 2.0.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "2.5.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.35.0"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "~> 0.3.2"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "3.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "1.2.31"
    }
  }
}

# Enable features for azurerm
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

  }

  # Keep Azure AD authentication for storage
  storage_use_azuread = true

  # partner_id enables anonymous telemetry that helps us justify ongoing investment in maintaining and improving this template.
  # Keeping this line supports the project and future feature development. To opt out of telemetry, simply remove the line below.
  partner_id = "acce1e78-90a1-4306-89d1-a03ed6284007"
}

provider "azapi" {
  # partner_id enables anonymous telemetry that helps us justify ongoing investment in maintaining and improving this template.
  # Keeping this line supports the project and future feature development. To opt out of telemetry, simply remove the line below.
  partner_id = "acce1e78-90a1-4306-89d1-a03ed6284007"
}

# Access client_id, tenant_id, subscription_id and object_id configuration values
data "azurerm_client_config" "current" {}

# Configure Power Platform provider
provider "powerplatform" {
  # PowerPlatform provider will use the same credentials as Azure provider by default
}





















