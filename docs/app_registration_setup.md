# App Registration and Service Principal Setup

To enable secure automation and integration with Azure and Power Platform, you need to set up an App Registration and its associated Service Principal in Azure Active Directory. This process allows your applications or scripts to authenticate and perform actions on your behalf. Follow the steps below to complete the setup and configuration.

## Configuration Steps

1. Create an **App Registration** in Microsoft Entra with the required permissions as outlined in the
[Power Platform Terraform Provider’s documentation](https://microsoft.github.io/terraform-provider-power-platform/guides/app_registration/).
1. Elevate your Service Principal to an Administrator using following snippet (this action must be done by an existing **Power Platform Administrator**):

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

## Important Security Notes

- **Principle of Least Privilege**: The permissions listed above represent the minimum required permissions for this template. Review and adjust based on your organization's security requirements.
- **Permission Validation**: After setup, verify that all permissions are working correctly by testing the deployment in a non-production environment.
- **Regular Reviews**: Periodically review and audit the permissions to ensure they remain appropriate for your use case.