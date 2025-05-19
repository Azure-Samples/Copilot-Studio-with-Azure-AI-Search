# Power Platform Solution Deployment Script

This script handles the complete deployment workflow for Power Platform solutions, with a focus on initializing connection references and supporting direct integration with Terraform outputs and GitHub federated authentication.

## Overview

The script performs the following steps:

1. **Create Settings File** - Generates a settings file based on the solution using `pac solution create-settings`.
2. **Update Settings File** - Updates the settings file with connection IDs provided as parameters (from Terraform outputs or manual input).
3. **Import Solution** - Imports the solution with the settings file to initialize connection references.
4. **Publish Customizations** - Publishes all customizations to activate imported components.
5. **Run Solution Checker** *(optional)* - Validates the imported solution for any issues.

## Usage

```powershell
./deploy_power_platform_solution.ps1 \
  -SolutionPath "./GoldAgent_1_0_0_1.zip" \
  -EnvironmentId "your-environment-id" \
  -AISearchConnectionId "<AI Search Connection ID>" \
  -UseGithubFederated $true
```

## Parameters

| Parameter              | Required | Default   | Description                                                                 |
|-----------------------|----------|-----------|-----------------------------------------------------------------------------|
| SolutionPath          | Yes      |           | Path to the solution zip file to deploy                                     |
| EnvironmentId         | Yes      |           | ID of the Power Platform environment                                        |
| AISearchConnectionId  | No       |           | Direct connection ID for the Azure AI Search connector                      |
| LogDirectory          | No       | ../logs    | Directory where logs will be stored                                         |
| RunSolutionChecker    | No       | $true     | Whether to run solution checker after deployment                            |
| UseGithubFederated    | No       | $false    | Use GitHub federated authentication (for GitHub Actions/Workload Identity)  |

## Direct Connection ID Usage

- **Recommended:** Pass connection ID directly from Terraform outputs using the `-AISearchConnectionId` parameter.
- This avoids the need to parse connection IDs from state files or perform connection discovery.
- Example with Terraform outputs:

```powershell
$terraformOutputs = terraform output -json | ConvertFrom-Json

pwsh ./deploy_power_platform_solution.ps1 \
  -SolutionPath $terraformOutputs.solution_paths.value.original \
  -EnvironmentId $terraformOutputs.power_platform_environment_id.value \
  -AISearchConnectionId $terraformOutputs.aisearch_connection_id.value \
  -UseGithubFederated $true
```

## GitHub Federated Authentication

- Use the `-UseGithubFederated $true` parameter when running in GitHub Actions with workload identity federation.
- The script will use the `POWER_PLATFORM_CLIENT_ID` and `POWER_PLATFORM_TENANT_ID` environment variables for authentication.

## Prerequisites

- PowerShell Core (pwsh) 7.0 or higher
- npm (for installing PAC CLI if not present)
- Valid Azure and Power Platform credentials
- [Optional] Terraform for infrastructure provisioning

## Logging

- The script creates detailed logs in the specified LogDirectory:
  ```
  ../logs/power_platform_deploy_YYYYMMDD_HHMMSS.log
  ```

## Troubleshooting

- **Authentication Failures:**
  - Ensure correct authentication parameters are set.
  - For GitHub Actions, set `-UseGithubFederated $true` and required environment variables.
- **Connection Reference Errors:**
  - Ensure the provided connection IDs are valid and exist in the target environment.
- **Log Files:**
  - Review logs for detailed error messages and troubleshooting steps.

## Best Practices

1. Always check the logs after deployment for any warnings or errors.
2. Use direct connection IDs from Terraform outputs for reliability.
3. Use solution checker to validate deployments in non-production environments.
4. When using with Terraform, save outputs to files for easier debugging.

---

For more details, see `DIRECT_CONNECTORS.md` and `TERRAFORM_INTEGRATION.md` in this directory.
