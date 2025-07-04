# App Registration and Service Principal Setup

To enable secure automation and integration with Azure and Power Platform, you need to set up an App Registration and its associated Service Principal in Azure Active Directory. This process allows your applications or scripts to authenticate and perform actions on your behalf. Follow the steps below to complete the setup and configuration.

## Configuration Steps

1. Create an **App Registration** in Azure AD with the required permissions. You can either:

   **Option A: Import the provided manifest (recommended):**
   - Download the [app registration manifest file](./app_registration_manifest.json)
   - In the Azure portal, go to **Azure Active Directory** > **App registrations** > **New registration**
   - Create a new app registration with a meaningful name
   - After creation, go to **Manifest** and replace the content with the provided manifest
   - Update the `appId` and `id` fields with your app's actual values
   - Save the manifest

   **Option B: Manual configuration:**
   - Create a new app registration and manually add the following API permissions:

   | API | Permission Name | Permission ID | Type | Description |
   |-----|----------------|---------------|------|-------------|
   | Microsoft Graph | `User.Read` | `e1fe6dd8-ba31-4d61-89e7-88639da4683d` | Delegated | Sign in and read user profile |
   | Microsoft Graph | `openid` | `37f7f235-527c-4136-accd-4a02d197296e` | Delegated | Sign users in |
   | Microsoft Graph | `profile` | `14dad69e-099b-42c9-810b-d002981feec1` | Delegated | View users' basic profile |
   | Power Platform API | `User` | `2e3d9d60-942c-4d60-8069-518ee1a669be` | Delegated | Access Power Platform as user |

1. This App Registration will automatically have an associated **Service Principal**.

1. Register the app with the Power Platform using either (this action must be done by an existing Power Platform Administrator):
   - The [Terraform provider](https://registry.terraform.io/providers/microsoft/power-platform/latest/docs/resources/admin_management_application), or
   - [PowerShell](https://learn.microsoft.com/power-platform/admin/powershell-create-service-principal), or
   - Bash:

      ```bash
      SP_CLIENT_ID="<your service principal's client ID>"
      TOKEN=$(az account get-access-token --resource https://api.bap.microsoft.com --query accessToken -o tsv)
      curl -X PUT "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/adminApplications/$SP_CLIENT_ID?api-version=2020-10-01" \
      -H "Host: api.bap.microsoft.com" \
      -H "Accept: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d '{}'
      ```

1. Grant **admin consent** for all delegated permissions assigned to the app. This can be done in the Azure portal under **App registrations** > **API permissions** > **Grant admin consent**.

1. Assign the following roles to the Service Principal in the Azure subscription where resources
will be created:
   - *Contributor*: Grants permission to create and manage Azure resources.
   - *Role Based Access Control Administrator*: Grants permission to assign RBAC roles, which is
   required when using managed identities.

## Important Security Notes

- **Principle of Least Privilege**: The permissions listed above represent the minimum required permissions for this template. Review and adjust based on your organization's security requirements.
- **Permission Validation**: After setup, verify that all permissions are working correctly by testing the deployment in a non-production environment.
- **Regular Reviews**: Periodically review and audit the permissions to ensure they remain appropriate for your use case.