# Configure the Microsoft Azure Provider features
provider "azurerm" {
  features {}

  # Specify the subscription ID
  subscription_id = var.subscription_id

  # Use Azure AD authentication for storage operations
  storage_use_azuread = true
}

# Configure the GitHub Provider
provider "github" {
  owner = var.github_owner
}
