# Terraform State Infrastructure

This directory contains Terraform configuration to create Azure infrastructure for storing Terraform remote state.

## Overview

This configuration creates:

- Azure Storage Account with private access only
- Storage Container for Terraform state files
- Virtual Network with private endpoint for secure access
- RBAC assignments for proper access control
- Diagnostic settings for monitoring
- GitHub repository variables for CI/CD integration

## Prerequisites

- Azure CLI installed and authenticated
- Terraform >= 1.0 installed
- Appropriate permissions in the target Azure subscription
- GitHub personal access token with `repo` and `admin:repo_hook` scopes (for GitHub integration)

## Usage

1. Copy the example variables file:

   ```bash
   cp terraform.tfvars.json.example terraform.tfvars.json
   ```

2. Edit `terraform.tfvars.json` with your values:

   ```json
   {
     "subscription_id": "your-subscription-id",
     "location": "East US",
     "github_token": "your-github-token",
     "github_owner": "Azure-Samples",
     "github_repository": "Copilot-Studio-with-Azure-AI-Search"
   }
   ```

3. Initialize and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Backend Configuration

After deployment, use the output values to configure your Terraform backend in other projects:

```hcl
terraform {
  backend "azurerm" {
    storage_account_name = "sttfstate<random>"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    resource_group_name  = "rg-tfstate-<random>"
    subscription_id      = "your-subscription-id"
    use_azuread_auth     = true
  }
}
```

## Security Features

- Private storage account (no public access)
- RBAC-based access (no shared keys)
- Private endpoint for network isolation
- Diagnostic logging enabled
- Blob versioning and retention policies

## GitHub Integration

This configuration automatically sets up GitHub repository variables for CI/CD pipelines:

- `RS_STORAGE_ACCOUNT`: Name of the remote state storage account
- `RS_RESOURCE_GROUP`: Name of the resource group containing the storage account
- `RS_CONTAINER_NAME`: Name of the storage container for Terraform state

These variables can be used in GitHub Actions workflows to configure Terraform backend settings.

## Environment Variables Alternative

Instead of using `terraform.tfvars.json`, you can set environment variables:

```bash
export TF_VAR_subscription_id="your-subscription-id"
export TF_VAR_location="East US"
export TF_VAR_github_token="your-github-token"
export TF_VAR_github_owner="Azure-Samples"
export TF_VAR_github_repository="Copilot-Studio-with-Azure-AI-Search"
```
