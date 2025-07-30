# Configure the Microsoft Azure Provider features
provider "azurerm" {
  features {}

  # Use Azure AD authentication for storage operations
  storage_use_azuread = true
}
