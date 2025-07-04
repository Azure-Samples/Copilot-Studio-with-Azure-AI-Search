# App Registration and Service Principal Setup

To enable secure automation and integration with Azure and Power Platform, you need to set up an App Registration and its associated Service Principal in Azure Active Directory. This process allows your applications or scripts to authenticate and perform actions on your behalf. Follow the steps below to complete the setup and configuration.

## Configuration Steps

1. Create an **App Registration** in Azure AD with the required permissions as outlined in the
[Power Platform Terraform Provider’s documentation](https://microsoft.github.io/terraform-provider-power-platform/guides/app_registration/).
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

1. Grant **admin consent** for all delegated permissions assigned to the app.
1. Assign the following roles to the Service Principal in the Azure subscription where resources
will be created:
   - *Contributor*: Grants permission to create and manage Azure resources.
   - *Role Based Access Control Administrator*: Grants permission to assign RBAC roles, which is
   required when using managed identities.
