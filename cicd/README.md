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
    "subscription_id": "YOUR_SUBSCRIPTION_ID",
    "location": "West US",
    "github_runner_config": {
      "repo_owner": "YOUR_REPO_OWNER",
      "repo_name": "YOUR_REPO_NAME",
    },
    "github_runner_registration_token": "YOUR_GITHUB_RUNNER_TOKEN_HERE"

  }
   ```

3. Initialize and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Backend Configuration

After deployment, use the output to set the remote state values for your template.

```hcl
backend_config = {
  "container_name" = "CONTAINER_NAME"
  "resource_group_name" = "RESOURCE_GROUP_NAME"
  "storage_account_name" = "STORAGE_ACCOUNT_NAME"
  "subscription_id" = "SUBSCRIPTION_ID"
}
```

   ```shell
    # Set the remote state variables
    azd env set RS_STORAGE_ACCOUNT 'STORAGE_ACCOUNT_NAME'
    azd env set RS_CONTAINER_NAME 'CONTAINER_NAME'
    azd env set RS_RESOURCE_GROUP 'RESOURCE_GROUP_NAME'

    # Direct  jobs to the new runner by setting a repo variable used by your workflows for `runs-on` selection
    azd env set ACTIONS_RUNNER_NAME ['self-hosted']
    
    # Update the template to use remote backend
    azd hooks run prepackage
    ```

  - `ACTIONS_RUNNER_NAME`: set to `['self-hosted']` (JSON array syntax) to target any self-hosted runner

Note: The runner VM registers with labels like `self-hosted,vm,<resource-group>,<location>,<unique-id>`. You can narrow job placement further by including those additional labels in your `runs-on` matrix if desired.

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

These variables will be used in GitHub Actions workflows to configure Terraform backend settings.

