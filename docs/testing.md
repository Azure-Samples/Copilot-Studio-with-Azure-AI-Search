# Testing

This solution includes tests that validate both Copilot Studio and Azure AI Search components after deployment.

## Copilot Studio Agent Test

Located in `tests/Copilot/`, this test validates:

- **Conversation Flow**: End-to-end conversation test with the deployed agent
- **Integration**: Validation that Copilot Studio can successfully query Azure AI Search

Currently, [the Copilot Studio Client in the Agent SDK does not support the use of Service Principals for authentication](https://github.com/microsoft/Agents/blob/main/samples/basic/copilotstudio-client/dotnet/README.md#create-an-application-registration-in-entra-id---service-principal-login), and testing requires a cloud-native app registration as well as a test account with MFA turned off. The test user account must have access to the Power Platform environment containing the agent as well as access to the agent itself.

### Running Tests After Local Deployment Execution

After a successful local deployment execution, the local .env file contains most of the information needed to run the end-to-end Copilot Studio test. Alternatively, any test input can be set directly through environment variables.

Run the commands below to execute the test after a deployment.

```bash
# Navigate to the test directory
cd tests/Copilot

export POWER_PLATFORM_USERNAME="test@username.here"
export POWER_PLATFORM_PASSWORD="passhere"
export TEST_CLIENT_ID="native-app-guid-here"

# Run tests using azd environment outputs (recommended)
dotnet test --logger "console;verbosity=detailed"
```

### Running Tests with Manual Environment Variable Configuration

If you prefer to set environment variables manually or need to override specific values, you can configure all required variables explicitly:

```bash
# Navigate to the test directory
cd tests/Copilot

# Power Platform authentication
export POWER_PLATFORM_USERNAME="your-test-user@domain.com"
export POWER_PLATFORM_PASSWORD="your-test-password"
export POWER_PLATFORM_TENANT_ID="your-tenant-id"
export POWER_PLATFORM_ENVIRONMENT_ID="your-environment-id"

# Native client application ID
export TEST_CLIENT_ID="your-native-app-client-id"

# Copilot Studio configuration
export COPILOT_STUDIO_ENDPOINT="https://api.copilotstudio.microsoft.com"
export COPILOT_STUDIO_AGENT_ID="crfXX_agentName"

# Run the test
dotnet test --logger "console;verbosity=detailed"
```

**Important Notes:**
- The test account must have **MFA disabled** for automated authentication
- The user must have access to the Power Platform environment and the Copilot Studio agent
- Environment variables take precedence over values from azd .env files

## AI Search Test (Optional)

Located in `tests/AISearch/`, this test validates:

- **Resource Existence**: Verify all search resources (index, datasource, skillset, indexer) exist
- **Configuration Validation**: Check resource configurations match expected settings
- **Content Verification**: Validate index contains expected documents and supports search
- **Pipeline Integration**: End-to-end validation of the complete search pipeline

Because the Copilot agent end-to-end test includes indirect validation of the AI Search functionality, this test does not need to be run unless direct validation and troubleshooting of the AI Search resources is required.

### Prerequisites for AI Search Tests

Before running AI Search tests, you must complete the following configuration:

1. **Make AI Search Endpoint Public**: Unless the test is run on the same virtual network as the AI Search resource, the AI Search service must be updated to be accessible to the test script. Configure network access in the Azure portal:
   - Navigate to your AI Search service
   - Go to **Networking** → **Firewalls and virtual networks**
   - Select **All networks** or add the test runner's IP to **Selected IP addresses**

2. **Assign RBAC Roles**: The user or service principal running the tests must have the following roles:
  - Navigate to your AI Search service in the Azure portal
  - Go to **Access control (IAM)** → **Add role assignment**
  - Select **Search Index Data Contributor** role and assign to the user or service principal that will execute the tests
  - Add another role assignment for **Search Service Contributor** role to the same user or service principal

### Running AI Search Tests Locally

```bash
# Ensure you're authenticated and have an azd environment deployed
az login

# Run the test script
cd tests/AISearch
./run-tests.sh
```

The tests automatically discover configuration from your azd environment outputs.
