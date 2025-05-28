# Power Platform Solution Deployment Script

This script provides a comprehensive workflow for deploying Copilot Studio solutions to a Power Platform environment, with special focus on configuring connection references for Azure AI Search.

## Overview

The script automates the following steps:

1. **Authentication** - Sets up PAC CLI authentication with support for GitHub federated identity
2. **Solution Connection Setup** - Generates a settings file based on the solution package, then updates the settings file with provided connection IDs 
3. **Solution Import** - Imports the solution with properly configured connection references
4. **Publish Customizations** - Activates all components after importing
5. **Run Solution Checker** - Validates the solution against best practices (optional)

## Usage

**This script is automatically executed when the end-to-end solution is deployed using azd.** The details below are intended for use in troubleshooting and investigating functionality.


```powershell
./deploy_power_platform_solution.ps1 `
  -SolutionPath "path/to/GoldAgent.zip" `
  -PowerPlatformEnvironmentId "<Power Platform Environment ID>" `
  -AISearchConnectionId "<AI Search Connection ID>" `
  -UseGithubFederated $true
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| SolutionPath | Yes | | Path to the solution zip file to deploy |
| PowerPlatformEnvironmentId | Yes | | ID of the Power Platform environment |
| RunSolutionChecker | No | $true | Whether to run solution checker after deployment |
| AISearchConnectionId | No | "" | Direct connection ID for the Azure AI Search connector |
| UseGithubFederated | No | $false | Use GitHub federated auth for CI/CD workflows |

## Authentication Methods

The script supports multiple authentication approaches in order of priority:

1. **GitHub Federated Authentication**
   - Used when `UseGithubFederated` is true and required environment variables are present
   - Requires environment variables `POWER_PLATFORM_CLIENT_ID` and `POWER_PLATFORM_TENANT_ID`
   - Ideal for CI/CD pipelines with GitHub Actions workload identity federation

2. **Service Principal Authentication**
   - Automatically used when these environment variables are set:
     - `POWER_PLATFORM_CLIENT_ID`
     - `POWER_PLATFORM_CLIENT_SECRET`
     - `POWER_PLATFORM_TENANT_ID`

3. **Azure CLI/Interactive Authentication**
   - Uses existing authenticated PAC CLI profile if available
   - Creates a new az-cli-auth profile if no active profile exists

## Integration with Terraform

For seamless integration with Terraform-provisioned resources:

```powershell
$terraformOutputs = terraform output -json | ConvertFrom-Json

./deploy_power_platform_solution.ps1 `
  -SolutionPath "src/powerplatform/copilot_studio_gold_agent" `
  -PowerPlatformEnvironmentId $terraformOutputs.power_platform_environment_id.value `
  -AISearchConnectionId $terraformOutputs.ai_search_connection_id.value
```

## Prerequisites

- PowerShell Core (pwsh) 8.0 or higher
- Power Platform CLI (PAC CLI) installed
- Appropriate permissions:
  - Power Platform Environment Administrator role or equivalent
  - Access to create/update connections in the target environment

## Solution Generation Process

The script automatically:

1. Packages the solution from source directory using `pac solution pack`
2. Creates a temporary ZIP file in the output directory
3. Updates connection references in a settings file
4. Imports and publishes the solution
5. Cleans up temporary files

## Troubleshooting

### Common Issues

- **Authentication Errors**
  - Verify your credentials have sufficient permissions
  - For service principal auth, ensure secret is correct and not expired
  - For GitHub federated auth, verify workflow permissions are correctly configured

- **Connection Reference Errors**
  - Ensure the connection already exists in the target environment
  - Verify the connection ID is in the correct format

- **Solution Import Failures**
  - Check that the source directory contains valid solution files
  - Verify there are no conflicting solutions in the target environment

---

For more information on Power Platform solutions deployment, refer to the [Microsoft Power Platform CLI documentation](https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction).
