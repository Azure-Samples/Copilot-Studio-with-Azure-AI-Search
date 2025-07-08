# App Registration and Service Principal Setup

To enable secure automation and integration with Azure and Power Platform, you need to set up an App Registration and its associated Service Principal in Azure Active Directory. This process allows your applications or scripts to authenticate and perform actions on your behalf. Follow the steps below to complete the setup and configuration.

## Configuration Steps

1. Login to your Power Platform:

      ```shell
      pac auth create
      ```

1. Create new **App Registration**:

      ```shell
      pac admin create-service-principal --name "Azd Template Sample Copilot Agent Service"
      ```

      **Note**: Remeber to save in a secure place `Application Id` and `Client Secret` generated as an output of this command. You will need it later.

1. Assign the following roles to the Service Principal in the Azure subscription where resources
will be created:
   - *Contributor*: Grants permission to create and manage Azure resources.
   - *Role Based Access Control Administrator*: Grants permission to assign RBAC roles, which is
   required when using managed identities.

1. Grant **admin consent** for all delegated permissions assigned to the app. This can be done in the [Azure portal](portal.azure.com) under **App registrations** > **API permissions** > **Grant admin consent**.

      List of permissions:

      - **Dynamics CRM**
         - user_impersonation

      - **Microsoft Graph**
         - Group.ReadWrite.All  
         - User.ReadWrite.All

      - **Power Platform API**
         - AIFlows.Ai.Execute  
         - AIFlows.Ai.Read  
         - AIFlows.Ai.Write  
         - AIFlows.Connections.Read  
         - AIFlows.Runs.Execute  
         - AIFlows.Runs.Read  
         - AIFlows.Runs.Write  
         - AIFlows.Workflows.Execute  
         - AIFlows.Workflows.Read  
         - AIFlows.Workflows.Write  
         - Analytics.AdvisorActions.Execute  
         - Analytics.AdvisorRecommendations.Read  
         - AppManagement.Application  
         - AppManagement.Application.Read  
         - CopilotStudio.Copilots.Invoke  
         - CopilotStudio.Copilots.Read  
         - EnvironmentManagement.Environments.Read  
         - EnvironmentManagement.Groups.ReadWrite  
         - EnvironmentManagement.Settings.Update  
         - Licensing.Allocations.Read  
         - Licensing.Allocations.ReadWrite  
         - Licensing.BillingPolicies.Read  
         - Licensing.BillingPolicies.ReadWrite  
         - Licensing.ISVContracts.Read  
         - Licensing.ISVContracts.ReadWrite  
         - PowerApps.Apps.Play
      - **PowerApps Service**
         - User

      Or You can copy `requiredResourceAccess` into your App Registration's Manifest:

      ```json
      "requiredResourceAccess": [
         {
            "resourceAppId": "475226c6-020e-4fb2-8a90-7a972cbfc1d4",
            "resourceAccess": [
               {
                  "id": "0eb56b90-a7b5-43b5-9402-8137a8083e90",
                  "type": "Scope"
               }
            ]
         },
         {
            "resourceAppId": "8578e004-a5c6-46e7-913e-12f58912df43",
            "resourceAccess": [
               {
                  "id": "8182d205-de75-4f96-b3d6-72c9b6bf6752",
                  "type": "Scope"
               },
               {
                  "id": "37ad1fa4-6ed6-4141-b859-91cb8dcacf45",
                  "type": "Scope"
               },
               {
                  "id": "75d93d21-82ac-49fc-8047-84750b06b4a6",
                  "type": "Scope"
               },
               {
                  "id": "8b7d5b6b-6df6-419c-bb10-b5e07d6c0020",
                  "type": "Scope"
               },
               {
                  "id": "633410f3-5d2b-4fd8-aa4d-d630aa95dc00",
                  "type": "Scope"
               },
               {
                  "id": "f2bba231-bad0-424b-9444-367c887cbeaf",
                  "type": "Scope"
               },
               {
                  "id": "42af0030-6190-410c-ab4b-6d590aae710d",
                  "type": "Scope"
               },
               {
                  "id": "67a887de-b565-4e46-8f2f-6edfcaf34006",
                  "type": "Scope"
               },
               {
                  "id": "1f7549d7-b59b-4536-b840-aab2a4adb634",
                  "type": "Scope"
               },
               {
                  "id": "1cea5717-a4d4-40c1-bf71-7f340cfad4f0",
                  "type": "Scope"
               },
               {
                  "id": "de9721ae-e403-4078-b5b3-91e5ce89a5aa",
                  "type": "Scope"
               },
               {
                  "id": "d8ed48a4-d90b-481c-b222-e9e342f38d58",
                  "type": "Scope"
               },
               {
                  "id": "204440d3-c1d0-4826-b570-99eb6f5e2aeb",
                  "type": "Scope"
               },
               {
                  "id": "177690ed-85f1-41d9-8dbf-2716e60ff46a",
                  "type": "Scope"
               },
               {
                  "id": "7a11470a-3968-43d4-af14-8fc4e6afcec1",
                  "type": "Scope"
               },
               {
                  "id": "3f4998a4-cbb8-4e1e-9ea0-fd7fc110bb74",
                  "type": "Scope"
               },
               {
                  "id": "adef0bc0-3a5b-457a-834c-cabd82f0a6d2",
                  "type": "Scope"
               },
               {
                  "id": "571bff05-abe6-4ddb-85e8-b764db682d97",
                  "type": "Scope"
               },
               {
                  "id": "a8f422ae-8922-45d4-a8f1-275a6bd43077",
                  "type": "Scope"
               },
               {
                  "id": "25223ba4-e810-4f08-9803-cde4b2057a13",
                  "type": "Scope"
               },
               {
                  "id": "73cf5c38-5257-4f28-8bbb-f78acf3290a4",
                  "type": "Scope"
               },
               {
                  "id": "048eb363-c1da-41d5-9edf-423b605ff23e",
                  "type": "Scope"
               },
               {
                  "id": "9dafb9c1-c236-48b1-b142-20dcaab58675",
                  "type": "Scope"
               },
               {
                  "id": "61bfce59-bddc-493f-b20c-32af5e904b83",
                  "type": "Scope"
               },
               {
                  "id": "5991ee89-0511-4700-b3be-d42ef2e7d61d",
                  "type": "Scope"
               },
               {
                  "id": "819ce212-3117-48ff-ab5d-b9f36c47e834",
                  "type": "Scope"
               },
               {
                  "id": "38c13204-7d79-4d83-bdbb-b770e28400df",
                  "type": "Role"
               }
            ]
         },
         {
            "resourceAppId": "00000003-0000-0000-c000-000000000000",
            "resourceAccess": [
               {
                  "id": "204e0828-b5ca-4ad8-b9f3-f32a958e7cc4",
                  "type": "Scope"
               },
               {
                  "id": "62a82d76-70ea-41e2-9197-370581804d09",
                  "type": "Role"
               }
            ]
         },
         {
            "resourceAppId": "00000007-0000-0000-c000-000000000000",
            "resourceAccess": [
               {
                  "id": "78ce3f0f-a1ce-49c2-8cde-64b5c0896db4",
                  "type": "Scope"
               }
            ]
         }
      ]
      ```
