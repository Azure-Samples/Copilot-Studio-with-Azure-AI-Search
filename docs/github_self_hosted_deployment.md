# GitHub Self-Hosted Runners

This project deploys GitHub self-hosted runners, using Azure Container Apps for isolated and
scalable CI/CD workloads.

## Configuring Terraform AzureRM backend state storage

This template sets up the Terraform backend to use the
[AzureRM backend](https://developer.hashicorp.com/terraform/language/backend/azurerm), enabling
remote state storage within an Azure Storage account Blob container. You can either create a new
storage account with a container using the below provided script or skip this step if you already
have an existing storage account and container to use.

    ```bash
    #!/bin/bash

    # Define variables for storage setup
    RESOURCE_GROUP_NAME=<RG_NAME>
    LOCATION=<LOCATION>
    STORAGE_ACCOUNT_NAME=<ACCOUNT_NAME>
    CONTAINER_NAME=<CONTAINER_NAME>

    # Get current user information for role assignment
    OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
    PRINCIPAL_TYPE="User"
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)

    # Create resource group
    az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

    # Create storage account
    az storage account create \
      --resource-group $RESOURCE_GROUP_NAME \
      --name $STORAGE_ACCOUNT_NAME \
      --sku Standard_LRS \
      --encryption-services blob

    # Create blob container
    az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME

    # Assign Data Contributor role for the container
    az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee-object-id $OBJECT_ID \
    --assignee-principal-type $PRINCIPAL_TYPE \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME/blobServices/default/containers/$CONTAINER_NAME"

## GitHub Personal Access Token Requirements

Create a **classic** GitHub Personal Access Token with the following permissions:

- **Repository permissions**:
  - `repo` (Full control of private repositories)
  - `workflow` (Update GitHub Action workflows)

## Configuring Environment Variables

Set the following environment variables for GitHub runner deployment:

    # GitHub configuration
    azd env set DEPLOY_GITHUB_RUNNER "true"  # optional, sets to "true" to enable github runners, defaults to "false"
    azd env set ENABLE_FAILOVER_GITHUB_RUNNER "false".  # optional, sets to "true" to enable failover region deployment, defaults to "false"
    azd env set GITHUB_PAT "<your-github-personal-access-token>"
    azd env set GITHUB_REPO_OWNER "<your-github-username-or-org>"
    azd env set GITHUB_REPO_NAME "<your-repository-name>"
    azd env set GITHUB_RUNNER_IMAGE_NAME "<github-runner-image-name>"  # optional, defaults to "github-runner"
    azd env set GITHUB_RUNNER_IMAGE_TAG "<github-runner-image-tag>"  # optional, defaults to "latest"
    azd env set GITHUB_RUNNER_IMAGE_BRANCH "<branch-containing-docker-file>"  # optional, defaults to "main"
    azd env set GITHUB_RUNNER_GROUP "<github-runner-group>"  # optional, defaults to "default"

    # Optional: Container Apps workload profile
    azd env set WORKLOAD_PROFILE_TYPE "D4"  # optional, defaults to "D4"

    ```bash
    # GitHub configuration
    ### Set the remote state configurations (reusing variables from step 5):

    azd env set RS_STORAGE_ACCOUNT $STORAGE_ACCOUNT_NAME
    azd env set RS_CONTAINER_NAME $CONTAINER_NAME
    azd env set RS_RESOURCE_GROUP $RESOURCE_GROUP_NAME
    azd env set GITHUB_RUNNER_IMAGE_BRANCH "<branch-containing-docker-file>"  # optional, defaults to "main"
    azd env set GITHUB_RUNNER_GROUP "<github-runner-group>"  # optional, defaults to "default"

    # Optional: Container Apps workload profile
    azd env set WORKLOAD_PROFILE_TYPE "D4"  # optional, defaults to "D4"
    ```

### Set the remote state configurations (reusing variables from step 5):

    ``` bash
    azd env set RS_STORAGE_ACCOUNT $STORAGE_ACCOUNT_NAME
    azd env set RS_CONTAINER_NAME $CONTAINER_NAME
    azd env set RS_RESOURCE_GROUP $RESOURCE_GROUP_NAME
    ```

## Deploying Runners

After configuring all environment variables, the GitHub runners will be automatically deployed
using the `azd up` command. They will then be registered with your repository and appear under
*Settings > Actions > Runners* in your repository.

*Note: If you encounter the following error:
`MissingSubscriptionRegistration: The subscription is not registered to use namespace 'Microsoft.App'`
please run `az provider register --namespace Microsoft.App` to register the Container Apps resource
provider in your subscription.*
