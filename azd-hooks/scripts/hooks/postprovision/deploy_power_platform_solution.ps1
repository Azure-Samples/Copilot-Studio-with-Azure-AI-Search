#!/usr/bin/env pwsh
<#

#region Overview
.SYNOPSIS
    A comprehensive script to deploy a Power Platform solution containing a Copilot Studio agent and connection references.

.DESCRIPTION
    This script handles the complete deployment workflow for a Power Platform solution:
    1. Creates a solution settings file from the solution
    2. Updates the settings file with connection information
    3. Imports the solution with the settings file
    4. Publishes all customizations to activate the solution components

    # To run this script:
    ./deploy_power_platform_solution.ps1 `
      -SolutionPath "../powerplatform/Copilot_Studio_Gold_Agent" `
      -PowerPlatformEnvironmentId "<Power Platform environment ID>" `
      -AISearchConnectionId "<AI Search Connection ID from Terraform Outputs>" `
      -AuthenticationMethod "GitHubFederated"

.PARAMETER SolutionPath
    Path to the solution source directory

.PARAMETER PowerPlatformEnvironmentId
    ID of the Power Platform environment to deploy to

.PARAMETER RunSolutionChecker
    Whether to run solution checker after deployment (default: false)

.PARAMETER AISearchConnectionId
    Direct connection ID for the Azure AI Search connector (highest priority)

.PARAMETER AuthenticationMethod
    Authentication method to use for Power Platform CLI authentication.
    Valid values: "ServicePrincipal", "GitHubFederated", "AzCli", "Auto"
    Default: "Auto" (automatically detects GitHub Actions vs local environment)

.EXAMPLE
    # Using with connection ID(s)
    ./deploy_power_platform_solution.ps1
      -SolutionPath "path/to/Gold_Agent_Source_directory"
      -PowerPlatformEnvironmentId "<Power Platform Environment ID>"
      -AISearchConnectionId "<AI Search Connection ID>"
      -AuthenticationMethod "GitHubFederated"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$SolutionPath,

    [Parameter(Mandatory = $true)]
    [string]$PowerPlatformEnvironmentId,

    [Parameter(Mandatory = $true)]
    [string]$AISearchConnectionId,

    [Parameter(Mandatory = $false)]
    [bool]$RunSolutionChecker = $true,

    [Parameter(Mandatory = $false)]
    [ValidateSet("ServicePrincipal", "GitHubFederated", "AzCli", "Auto")]
    [string]$AuthenticationMethod = "Auto"
)

#region Setup
# Set error action preference to stop on any error
$ErrorActionPreference = "Stop"

# Auto-detect authentication method if not explicitly specified
if ($AuthenticationMethod -eq "Auto") {
    if ($env:GITHUB_ACTIONS -eq "true") {
        Write-Output "INFO: GitHub Actions environment detected, using GitHub Federated authentication"
        $AuthenticationMethod = "GitHubFederated"
    } elseif ($env:POWER_PLATFORM_CLIENT_SECRET) {
        Write-Output "INFO: Local environment detected, using ServicePrincipal authentication"
        $AuthenticationMethod = "ServicePrincipal"
    } else {
        Write-Output "INFO: No specific authentication method detected, defaulting to AzCli"
        $AuthenticationMethod = "AzCli"
    }

}

# Create settings directory for storing solution settings
$SettingsDirectory = "$PSScriptRoot/power_platform_deployment_settings"
if (!(Test-Path $SettingsDirectory)) {
    New-Item -ItemType Directory -Path $SettingsDirectory -Force | Out-Null
}

Write-Output "INFO: Starting Power Platform solution deployment"

# Function to ensure PAC CLI is installed
function Test-PacCliInstalled {
    Write-Output "INFO: Checking if PAC CLI is installed"
    try {
        $PacVersion = & pac help 2>&1 | Select-String "Microsoft Power Platform CLI"
        if ($PacVersion) {
            Write-Output "INFO: Using PAC CLI: $PacVersion"
            return $true
        } else {
            Write-Error "PAC CLI not detected, please install PAC CLI and run again"
            exit 1
        }
    }
    catch {
        Write-Error "Error checking PAC CLI: $_"
        exit 1
    }
}

#region Authentication
# Function to handle PAC CLI authentication with secure credential handling
function Set-PacAuthentication {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("ServicePrincipal", "GitHubFederated", "AzCli")]
        [string]$AuthenticationMethod
    )

    Write-Output "INFO: Starting authentication using method: $AuthenticationMethod"

    try {
        switch ($AuthenticationMethod) {
            "GitHubFederated" {
                if (![string]::IsNullOrEmpty($env:POWER_PLATFORM_CLIENT_ID) -and
                    ![string]::IsNullOrEmpty($env:POWER_PLATFORM_TENANT_ID)) {
                    Write-Output "INFO: Setting a PAC auth profile based on GitHub federated authentication"
                    $authOutput = & pac auth create --name github-federated-auth `
                                    --applicationId $env:POWER_PLATFORM_CLIENT_ID `
                                    --tenant $env:POWER_PLATFORM_TENANT_ID `
                                    --githubFederated
                    & pac auth select --name github-federated-auth
                } else {
                    Write-Error "GitHub Federated authentication requires POWER_PLATFORM_CLIENT_ID and POWER_PLATFORM_TENANT_ID environment variables"
                    exit 1
                }
            }
            "ServicePrincipal" {
                if (![string]::IsNullOrEmpty($env:POWER_PLATFORM_CLIENT_ID) -and
                    ![string]::IsNullOrEmpty($env:POWER_PLATFORM_CLIENT_SECRET) -and
                    ![string]::IsNullOrEmpty($env:POWER_PLATFORM_TENANT_ID)) {

                    Write-Output "INFO: Found service principal environment variables, using service principal authentication"

                    # Execute the auth create command and capture output
                    # TODO decide whether it's worth reconfiguring the devcontainer to support keyring auth so we can remove the cleartext-caching parameter below
                    $authOutput = & pac auth create --name service-principal-auth `
                                --applicationId $env:POWER_PLATFORM_CLIENT_ID `
                                --clientSecret $env:POWER_PLATFORM_CLIENT_SECRET `
                                --tenant $env:POWER_PLATFORM_TENANT_ID `
                                --accept-cleartext-caching 2>&1 | Out-String

                    # Log that authentication was attempted (don't log the actual output which may contain secrets)
                    Write-Output "INFO: PAC auth create completed"

                    & pac auth select --name service-principal-auth
                } else {
                    Write-Error "Service Principal authentication requires POWER_PLATFORM_CLIENT_ID, POWER_PLATFORM_CLIENT_SECRET, and POWER_PLATFORM_TENANT_ID environment variables"
                    exit 1
                }
            }
            "AzCli" {
                # Try to find active pac CLI auth profile
                $ActiveLine = pac auth list | Where-Object { $_ -match '^\[\d+\]\s+\*\s+' }
                $Tokens = $ActiveLine -split '\s+'
                $ActiveName = $Tokens[3]

                # If we found an active profile, it's already set - just use it. If not, create a new one.
                if ([string]::IsNullOrEmpty($ActiveName)) {
                    Write-Output "INFO: Creating new az-cli-auth profile"
                    $authOutput = & pac auth create --name az-cli-auth `
                    & pac auth select --name az-cli-auth
                } else {
                    Write-Output "INFO: Using existing active auth profile: $ActiveName"
                }
            }
        }
    }
    catch {
        Write-Error "PAC authentication failed. PAC auth output: $AuthOutput"
        exit 1
    }
}

# Function to ensure the environment is accessible
function Test-EnvironmentAccess {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PowerPlatformEnvironmentId
    )

    Write-Output "INFO: Checking access to environment $PowerPlatformEnvironmentId"
    try {
        & pac org who --environment $PowerPlatformEnvironmentId
        Write-Output "INFO: Environment is accessible"
        return $true
    }
    catch {
        Write-Error "WARNING: Authentication failed or token expired"
        exit 1
    }
}
#endregion

#region Connection Setup
# Function to create settings file from solution with secure handling of connection information
function New-SolutionSettingsFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SolutionPath,

        [Parameter(Mandatory = $true)]
        [string]$SettingsFileName,

        [Parameter(Mandatory = $false)]
        [string]$AiSearchConnectionId = ""
    )

    Write-Output "INFO: Creating settings file for solution $SolutionPath"

    # Create the settings file from the solution
    try {
        # Use the settings directory instead of the current directory
        $SettingsFilePath = Join-Path $settingsDirectory $SettingsFileName

        & pac solution create-settings --solution-zip $SolutionPath --settings-file $SettingsFilePath

        if (Test-Path $SettingsFilePath) {
            Write-Output "INFO: Settings file created successfully at $SettingsFilePath"

            # Read the settings file
            $settingsContent = Get-Content -Path $SettingsFilePath -Raw
            $settings = ConvertFrom-Json -InputObject $settingsContent -Depth 10

            # Check if there are connection references to update
            if ($settings.ConnectionReferences -and $settings.ConnectionReferences.Count -gt 0) {
                Write-Output "INFO: Found $($settings.ConnectionReferences.Count) connection references in settings file"

                # Loop through connection references and update values
                foreach ($connectionRef in $settings.ConnectionReferences) {
                    # Check which connector we're dealing with
                    if ($connectionRef.ConnectorId -match "shared_azureaisearch") {
                        Write-Output "INFO: Found AI Search connection reference (ConnectorId: $($connectionRef.ConnectorId))"

                        if (![string]::IsNullOrEmpty($AiSearchConnectionId)) {
                            Write-Output "INFO: Setting AI Search connection ID"
                            $connectionRef.ConnectionId = $AiSearchConnectionId
                        } else {
                            Write-Output "WARNING: No AI Search connection ID provided - connection reference will remain unchanged"
                        }
                    } else {
                        Write-Output "INFO: Skipping connection reference for connector: $($connectionRef.ConnectorId)"
                    }
                }

                # Save the updated settings file
                $UpdatedJson = ConvertTo-Json -InputObject $settings -Depth 10
                Set-Content -Path $SettingsFilePath -Value $UpdatedJson -Force

                Write-Output "INFO: Updated settings file saved"
                return $true
            }
        }
        else {
            Write-Error "Settings file was not created at path: $SettingsFilePath"
            exit 1
        }
        return $false
    } catch {
        Write-Error "Error creating settings file: $_"
        exit 1
    }
}

#region Solution Generation
# Function to generate solution from source directory
function New-PackageSolution {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory,

        [Parameter(Mandatory = $false)]
        [string]$OutputFileName
    )

    Write-Output "INFO: Generating solution from source directory"

    # Ensure output directory exists
    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        Write-Output "INFO: Created output directory: $OutputDirectory"
    }

    # Build full output path
    $outputSolutionPath = Join-Path -Path $OutputDirectory -ChildPath $OutputFileName

    Write-Output "INFO: Generating solution from source at $SourceDirectory"
    Write-Output "INFO: Output solution will be at $OutputSolutionPath"

    # Check if source directory exists
    if (-not (Test-Path $SourceDirectory)) {
        Write-Error "Source directory does not exist at: $SourceDirectory"
        exit 1
    }

    try {
        # Generate the solution using pac cli
        $PacOutput = & pac solution pack --zipfile $OutputSolutionPath --folder $SourceDirectory --packagetype Unmanaged --clobber 2>&1 | Out-String

        if (-not (Test-Path $OutputSolutionPath)) {
            Write-Error "Solution generation failed. Output file was not created: $OutputSolutionPath"
            Write-Error "PAC output: $PacOutput"
            exit 1
        }

        Write-Output "INFO: Solution successfully generated at: $OutputSolutionPath"

        return $true
    }
    catch {
        Write-Error "Solution generation failed: $_"
        Write-Error "PAC output: $PacOutput"
        exit 1
    }
}
#endregion

#region Solution Import
# Function to import the solution
function Import-PowerPlatformSolution {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SolutionPath,

        [Parameter(Mandatory = $true)]
        [string]$PowerPlatformEnvironmentId,

        [Parameter(Mandatory = $true)]
        [string]$SettingsFilePath
    )

    Write-Output "INFO: Importing solution from $SolutionPath"

    try {
        # Execute the import command and capture the output
        $ImportResult = & pac solution import --path $SolutionPath --environment $PowerPlatformEnvironmentId --settings-file $SettingsFilePath --force-overwrite 2>&1 | Out-String

        Write-Output "INFO: Solution import command completed"

        $ListOutput = & pac solution list --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
        $SolutionName = [System.IO.Path]::GetFileNameWithoutExtension($SolutionPath)

        Write-Output "INFO: Solution list command completed: $ListOutput"

        if ($ListOutput -match $solutionName) {
            Write-Output "INFO: Solution import verified successfully - found in environment"
        } else {
            Write-Error "Solution import validation failed - solution not found in environment"
            exit 1
        }
    }
    catch {
        Write-Error "Solution import failed: $ImportResult"
        exit 1
    }

    # Wait for solution to be fully imported
    Write-Output "INFO: Waiting for solution import to stabilize..."
    Start-Sleep -Seconds 30

    # Publish all customizations
    Write-Output "INFO: Publishing all customizations..."
    try {
        $PublishOutput = & pac solution publish --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
          # Check if the output contains failure indicators
        if (-not ($PublishOutput -match "Published All Customizations")) {
            Write-Error "Solution publish appears to have failed with output: $PublishOutput"
            exit 1
        }

        Write-Output "INFO: Solution publication completed successfully"
        return $true
    }
    catch {
        Write-Error "Publishing customizations failed even after reauthentication: $_"
        exit 1
    }
}

#region Solution Checker
# Function to run solution checker
function Invoke-SolutionChecker {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,

        [Parameter(Mandatory = $true)]
        [string]$SolutionPath,

        [Parameter(Mandatory = $true)]
        [string]$PowerPlatformEnvironmentId
    )

    Write-Output "INFO: Running solution checker for $SolutionName..."

    try {
        # Run solution checker
        $CheckerOutput = & pac solution check --path $SolutionPath --environment $PowerPlatformEnvironmentId 2>&1 | Out-String

        # Check if the output contains failure indicators
        if ($CheckerOutput -match "fail|error|exception" -and -not $CheckerOutput -match "success") {
            Write-Output "WARNING: Solution checker appears to have failed with output: $CheckerOutput"
            return $false
        }

        # Try to parse the JSON output for more detailed information
        try {
            $CheckerResults = $CheckerOutput | ConvertFrom-Json
            $IssueCount = $CheckerResults.Issues.Count

            if ($IssueCount -gt 0) {
                Write-Output "WARNING: Solution checker found $IssueCount issues"
                foreach ($issue in $CheckerResults.Issues) {
                    Write-Output "WARNING: Issue: $($Issue.Description) - Severity: $($Issue.Severity)"
                }
            } else {
                Write-Output "INFO: Solution checker completed with no issues detected"
            }
        } catch {
            # If we can't parse as JSON, just log the raw output
            Write-Output "WARNING: Solution checker output (could not parse as JSON): $CheckerOutput"
        }

        return $true
    }
    catch {
        $ErrorMessage = $_.ToString()
        Write-Error "Solution checker failed: $ErrorMessage"
        exit 1
    }

    return $true
}
#endregion

#region Main Execution

Write-Output "INFO: Solution path: $SolutionPath"
Write-Output "INFO: Environment ID: $PowerPlatformEnvironmentId"
Write-Output "INFO: Run solution checker: $RunSolutionChecker"
Write-Output "INFO: AI Search connection ID: $(if ([string]::IsNullOrEmpty($AISearchConnectionId)) { "Not provided" } else { "Provided" })"
Write-Output "INFO: Authentication method: $AuthenticationMethod"


# Step 1: Verify PAC CLI is installed
if (-not (Test-PacCliInstalled)) {
    Write-Error "PAC CLI installation was not detected. Cannot continue."
    exit 1
}

# Verify the solution directory exists
if (-not (Test-Path $SolutionPath)) {
    Write-Error "Solution directory does not exist at path: $SolutionPath"
    exit 1
}

# Step 2: Set up authentication
Set-PacAuthentication -AuthenticationMethod $AuthenticationMethod

# Step 3: Verify environment access
if (-not (Test-EnvironmentAccess -PowerPlatformEnvironmentId $PowerPlatformEnvironmentId)) {
    Write-Error "Cannot access the environment. Cannot continue."
    exit 1
}

# Step 4: Generate the solution from the specified source directory
# Define source and output paths
$SolutionSourceDirectory = $SolutionPath
$SolutionOutputDirectory = "src/powerplatform" # This could eventually be parameterized, but the file is currently transient
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$SolutionOutputFileName = "GoldAgent.zip" # This could eventually be parameterized, but the file is currently transient
$OutputSolutionPath = Join-Path $SolutionOutputDirectory $SolutionOutputFileName
if (-not (New-PackageSolution -SourceDirectory $SolutionSourceDirectory -OutputDirectory $SolutionOutputDirectory -OutputFileName $SolutionOutputFileName)) {
    Write-Error "Solution generation failed. Cannot continue."
    exit 1
}

# Step 5: Create settings file from solution and incorporate connection ID(s)
if ([string]::IsNullOrWhiteSpace($AISearchConnectionId)) {
    Write-Output "WARNING: No specific connection IDs provided."
}
$SettingsFileName = "solution_settings_$Timestamp.json"
Write-Output "INFO: Create settings file $SettingsFileName"
if (-not (New-SolutionSettingsFile -SolutionPath $OutputSolutionPath -SettingsFileName $SettingsFileName -AiSearchConnectionId $AISearchConnectionId)) {
    Write-Error "Solution settings file initialization failed. Cannot continue."
    exit 1
}
$SettingsFilePath = Join-Path $SettingsDirectory $SettingsFileName
Write-Output "INFO: Settings file path: $SettingsFilePath"

# Step 6: Run solution checker if enabled
if ($RunSolutionChecker) {
    Write-Output "INFO: RunSolutionChecker is enabled. Running solution checker..."
    if (-not (Invoke-SolutionChecker -SolutionName $SolutionOutputFileName -SolutionPath $OutputSolutionPath -PowerPlatformEnvironmentId $PowerPlatformEnvironmentId)) {
        Write-Output "WARNING: Solution checker encountered issues. Review the logs for details."
    }
} else {
    Write-Output "INFO: RunSolutionChecker is disabled. Skipping solution checker."
}

# Step 7: Import the solution with settings file
if (-not (Import-PowerPlatformSolution -SolutionPath $OutputSolutionPath -PowerPlatformEnvironmentId $PowerPlatformEnvironmentId -SettingsFilePath $SettingsFilePath)) {
    Write-Error "Solution import failed. Cannot continue."
    exit 1
}

Write-Output "INFO: Power Platform solution deployment process completed"

# Clean up the settings file
if (Test-Path $SettingsFilePath) {
    Remove-Item -Path $SettingsFilePath -Force
    Write-Output "INFO: Cleaned up temporary settings file"
}

# Clean up the output solution file
if (Test-Path $OutputSolutionPath) {
    Remove-Item -Path $OutputSolutionPath -Force
    Write-Output "INFO: Cleaned up temporary solution file"
}

exit 0
#endregion
