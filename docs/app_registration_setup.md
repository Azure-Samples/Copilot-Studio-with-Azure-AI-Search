# App Registration and Service Principal Setup

To enable secure automation and integration with Azure and Power Platform, you need to set up an App Registration and its associated Service Principal in Azure Active Directory. This process allows your applications or scripts to authenticate and perform actions on your behalf. Follow the steps below to complete the setup and configuration.

## Configuration Steps

1. Create an **App Registration** in Microsoft Entra with the required permissions as outlined in the
[Power Platform Terraform Provider’s documentation](https://microsoft.github.io/terraform-provider-power-platform/guides/app_registration/).
1. Elevate your Service Principal to an Administrator using following snippet (this action must be done by an existing **Power Platform Administrator**):

      ```shell
      pac auth create
      ```


      ```bash
         az login
         read -p "Enter the Service Principal Client ID: " SP_CLIENT_ID
         TOKEN=$(az account get-access-token --resource https://api.bap.microsoft.com --query accessToken -o tsv)
         curl -X PUT "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/adminApplications/$SP_CLIENT_ID?api-version=2020-10-01" \
         -H "Host: api.bap.microsoft.com" \
         -H "Accept: application/json" \
         -H "Authorization: Bearer $TOKEN" \
         -d '{}' \
         && echo -e "\nRegistration finished!"
      ```

1. Grant **admin consent** for all delegated permissions assigned to the app. This can be done in the Azure portal under **App registrations** > **API permissions** > **Grant admin consent**.

1. Assign the following roles to the Service Principal in the Azure subscription where resources
will be created:
   - *Contributor*: Grants permission to create and manage Azure resources.
   - *Role Based Access Control Administrator*: Grants permission to assign RBAC roles, which is
   required when using managed identities.

### Workflows

A mature workflow for a solution not only automates the deployment of the IAC resources, and the
application but also incorporates engineering fundamentals, resources validation, dependency
management, test execution, security scanning, and more.

This template leverages [Azure Developer CLI Hooks](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/azd-extensibility)
to seamlessly integrate [TFLint](https://github.com/terraform-linters/tflint), [Checkov](https://www.checkov.io/),
and [Gitleaks](https://github.com/gitleaks/gitleaks) into both Dev loop and deployment workflow.
These tools run automatically before executing the azd up command, ensuring security, compliance,
and best practices are validated prior to deploying the solution.

The main workflow, defined in [azure-dev.yml](.github/workflows/azure-dev.yml), utilizes Federated
credentials to ensure secure authentication.

**ONLY FOR SELF-HOSTED GITHUB RUNNERS**: There is a workflow defined in [test-runner.yaml](/.github/workflows/test-runner.yaml)
that runs through uploading test data to defined resource group, and testing the search service after
that data upload.

### Set Up Federated Identity Credential in Azure

Before setting up a federated identity credential in Azure, it’s useful to understand how workload
identity federation works. For a detailed explanation, refer to the official
[Microsoft documentation on federated credentials](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation).

To set up a federated identity credential in Azure, follow these steps:

1. Navigate to **Azure Portal** → **App registrations** → select your app registration.
1. Under **Certificates & Secrets**, click **Federated credentials** → **Add credential**.
1. Configure the federated credential:
   - **Issuer**: `https://token.actions.githubusercontent.com`
   - **Subject Identifier**:
     - For repository-level trust: `repo:<your-org>/<your-repo>:ref:refs/heads/<branch-name>`
   - **Audience**: `api://AzureADTokenExchange`
   - Click **Add**.

### Add Required Secrets to GitHub

1. Go to **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
1. Add the following secrets (consider using separate app registrations for ARM and Power Platform providers for better security isolation):

   - `AZURE_CLIENT_ID`: Your app registration’s client ID.
   - `AZURE_TENANT_ID`: Your Azure AD tenant ID.
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID.
   - `POWER_PLATFORM_CLIENT_ID`: Your Power Platform app registration's client ID (can be same as Azure client ID or separate for better isolation).
   - `POWER_PLATFORM_TENANT_ID`: Power Platform tenant ID (typically same as Azure tenant ID).
   - `RS_ACCOUNT_NAME`: Name of the Azure Storage account used for storing the Terraform remote
   state.
   - `RS_CONTAINER_NAME`: Name of the blob container within the storage account that holds the
   Terraform state file.
   - `RS_RESOURCE_GROUP`: Name of the resource group containing the storage account for Terraform
   remote state.
   - `RESOURCE_SHARE_USER`: Set of Microsoft Entra ID object IDs for interactive admin users granted access (see [documentation](./docs/resource_share_user.md))
   to deployed resources.
   - `GITHUB_PAT`: GitHub personal access token.

*Note: Client secret is not needed if using federated identity.*