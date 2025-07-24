# Copilot Integration Test Setup

This document describes how to set up and run the end-to-end integration test for the Copilot Studio agent.

## Prerequisites

### GitHub Secrets Required

The following GitHub secret must be added to your repository for the integration test to work:

| Secret Name | Description | Value Source |
|-------------|-------------|--------------|
| `AZURE_CLIENT_SECRET` | Service principal client secret for API authentication | From your Azure Service Principal |

**Note:** The main deployment workflow uses federated identity, but the Copilot Studio API requires traditional service principal authentication with a client secret.

### GitHub Variables (Already Configured)

These variables should already be configured from the main deployment workflow:

| Variable Name | Description |
|---------------|-------------|
| `AZURE_CLIENT_ID` | Azure service principal client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `RS_STORAGE_ACCOUNT` | Remote state storage account |
| `RS_CONTAINER_NAME` | Remote state container name |
| `RS_RESOURCE_GROUP` | Remote state resource group |
| `RESOURCE_SHARE_USER` | Resource sharing user configuration |

## How to Add the Client Secret

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AZURE_CLIENT_SECRET`
5. Value: The client secret from your Azure Service Principal
6. Click **Add secret**

## Running the Test

### Manual Trigger

1. Go to the **Actions** tab in your GitHub repository
2. Select **End-to-End Copilot Test** workflow
3. Click **Run workflow**
4. Choose the AZD environment name and Azure location
5. Click **Run workflow**

### Automatic Trigger

The test runs automatically:
- Daily at 6 AM UTC (scheduled)
- Can be triggered manually via workflow dispatch

## Test Process

The integration test performs the following steps:

1. **Authentication**: Logs into Azure using federated identity
2. **Environment Setup**: Retrieves configuration from the specified AZD environment
3. **Package Restoration**: Installs .NET dependencies
4. **Test Execution**: Runs the Copilot Studio integration test
5. **Results Upload**: Saves test results as artifacts
6. **Notification**: Provides success/failure summary

## Test Validation

The test validates:
- ✅ Copilot Studio agent is accessible via API
- ✅ Authentication with service principal works
- ✅ Agent responds to product queries
- ✅ Azure AI Search integration is functional
- ✅ Response contains expected information (e.g., "$90" for Adventure Dining Table)

## Troubleshooting

### Common Issues

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| `AZURE_CLIENT_SECRET` not found | Secret not added to GitHub | Add the secret as described above |
| `POWER_PLATFORM_ENVIRONMENT_ID` not found | AZD environment not deployed | Run the main deployment workflow first |
| Authentication failed | Invalid client secret | Verify the client secret value |
| Agent not found | Copilot Studio solution not deployed | Check the deployment logs |
| API timeout | Network/service issues | Retry the test |

### Debug Information

The workflow provides detailed logging:
- Environment variables (sanitized)
- AZD output values
- Test execution details
- Error messages and stack traces

### Test Results

Test results are uploaded as artifacts and include:
- `copilot-test-results.trx` - Detailed test results in Visual Studio format
- Console output with verbose logging
- 30-day retention for historical analysis

## Security Notes

- The client secret is stored securely in GitHub Secrets
- Environment variables are only exposed during test execution
- No sensitive information is logged in plain text
- The test uses the same security practices as the main deployment
