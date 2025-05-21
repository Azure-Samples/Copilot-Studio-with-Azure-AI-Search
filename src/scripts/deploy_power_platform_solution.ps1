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
      -PowerPlatformEnvironmentId "your-environment-id" `
      -AISearchConnectionId "<AI Search Connection ID from Terraform Outputs>"

.PARAMETER SolutionPath
    Path to the solution source directory

.PARAMETER PowerPlatformEnvironmentId
    ID of the Power Platform environment to deploy to

.PARAMETER RunSolutionChecker
    Whether to run solution checker after deployment (default: true)

.PARAMETER AISearchConnectionId
    Direct connection ID for the Azure AI Search connector (highest priority)

.PARAMETER UseGithubFederated
    Whether to explicitly use GitHub Federated authentication (default: false)
    Set to true when running in GitHub Actions with workload identity federation
      
.EXAMPLE
    # Using with connection ID(s)
    ./deploy_power_platform_solution.ps1
      -SolutionPath "path/to/GoldAgent.zip"
      -PowerPlatformEnvironmentId "<Power Platform Environment ID>"
      -AISearchConnectionId "<AI Search Connection ID>"
      -UseGithubFederated $true
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$SolutionPath,
    
    [Parameter(Mandatory = $true)]
    [string]$PowerPlatformEnvironmentId,
    
    [Parameter(Mandatory = $false)]
    [bool]$RunSolutionChecker = $true,
    
    [Parameter(Mandatory = $false)]
    [string]$AISearchConnectionId = "",
    
    [Parameter(Mandatory = $false)]
    [bool]$UseGithubFederated = $false
)

#region Setup
# Set error action preference to stop on any error
$ErrorActionPreference = "Stop"

# Create settings directory for storing solution settings
$settingsDirectory = "$PSScriptRoot/power_platform_deployment_settings"
if (!(Test-Path $settingsDirectory)) {
    New-Item -ItemType Directory -Path $settingsDirectory -Force | Out-Null
}

# Function to securely handle sensitive parameters
function ConvertTo-SecureParameter {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputString
    )
    
    if ([string]::IsNullOrEmpty($InputString)) {
        return $null
    }
    
    return ConvertTo-SecureString -String $InputString -AsPlainText -Force
}

Write-Host "INFO: Starting Power Platform solution deployment script"

# Function to ensure PAC CLI is installed
function Test-PacCliInstalled {
    Write-Host "INFO: Checking if PAC CLI is installed"
    try {
        $pacVersion = & pac help 2>&1 | Select-String "Microsoft Power Platform CLI"
        if ($pacVersion) {
            Write-Host "INFO: Using PAC CLI: $pacVersion"
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

    return $true
}

#region Authentication
# Function to handle PAC CLI authentication with secure credential handling
function Set-PacAuthentication {    
    param (        
        [bool]$UseGithubFederated
    )
    
    Write-Host "INFO: Starting authentication"

    # Try Github federated auth first if explicitly requested and environment variables are available
    if ($UseGithubFederated -and
        (![string]::IsNullOrEmpty($env:POWER_PLATFORM_CLIENT_ID) -and 
         ![string]::IsNullOrEmpty($env:POWER_PLATFORM_TENANT_ID))) {
            Write-Host "INFO: Setting a PAC auth profile based on GitHub federated authentication"
            & pac auth create --name github-federated-auth `
                            --applicationId $env:POWER_PLATFORM_CLIENT_ID `
                            --tenant $env:POWER_PLATFORM_TENANT_ID `
                            --githubFederated
            & pac auth select --name github-federated-auth
    }
    # Try Service Principal auth second
    elseif (![string]::IsNullOrEmpty($env:POWER_PLATFORM_CLIENT_ID) -and 
        ![string]::IsNullOrEmpty($env:POWER_PLATFORM_CLIENT_SECRET) -and 
        ![string]::IsNullOrEmpty($env:POWER_PLATFORM_TENANT_ID)) {
        
        Write-Host "INFO: Found service principal environment variables, using service principal authentication"

        try {
            # Execute the auth create command and capture output
            $authOutput = & pac auth create --name service-principal-auth `
                        --applicationId $env:POWER_PLATFORM_CLIENT_ID `
                        --clientSecret $env:POWER_PLATFORM_CLIENT_SECRET `
                        --tenant $env:POWER_PLATFORM_TENANT_ID `
                        --accept-cleartext-caching 2>&1 | Out-String

            # Log that authentication was attempted (don't log the actual output which may contain secrets)
            Write-Host "INFO: PAC auth create completed"
            
            & pac auth select --name service-principal-auth
        }
        catch {
            Write-Error "PAC auth create failed: $_"
            exit 1
        }
    } else {
        # Try to find active pac CLI auth profile
        $activeLine = pac auth list | Where-Object { $_ -match '^\[\d+\]\s+\*\s+' }
        $tokens = $activeLine -split '\s+'
        $activeName = $tokens[3]
        
        # If we found an active profile, it's already set - just use it. If not, create a new one.
        if ([string]::IsNullOrEmpty($activeName)) {
            Write-Host "INFO: Creating new az-cli-auth profile"
            & pac auth create --name az-cli-auth
            & pac auth select --name az-cli-auth
        } else {
            Write-Host "INFO: Using existing active auth profile: $activeName"
        }
    }
}

# Function to ensure the environment is accessible
function Test-EnvironmentAccess {    
    param (
        [Parameter(Mandatory = $true)]
        [string]$PowerPlatformEnvironmentId
    )
    
    Write-Host "INFO: Checking access to environment $PowerPlatformEnvironmentId"
    try {
        & pac org who --environment $PowerPlatformEnvironmentId
        Write-Host "INFO: Environment is accessible"
        return $true
    } 
    catch {
        Write-Host "WARNING: Authentication failed or token expired. Attempting to reauthenticate..."
        
        # Try to reauthenticate
        Set-PacAuthentication -UseGithubFederated $UseGithubFederated
        
        # Try again
        try {
            & pac org who --environment $PowerPlatformEnvironmentId
            Write-Host "INFO: Environment is now accessible after reauthentication"
            return $true
        } catch {
            Write-Error "Failed to access environment even after reauthentication: $_"
            exit 1
        }
    }

    return $true
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
    
    Write-Host "INFO: Creating settings file for solution $SolutionPath"
    
    # Create the settings file from the solution
    try {
        # Use the settings directory instead of the current directory
        $SettingsFilePath = Join-Path $settingsDirectory $SettingsFileName
        
        & pac solution create-settings --solution-zip $SolutionPath --settings-file $SettingsFilePath
        
        if (Test-Path $SettingsFilePath) {
            Write-Host "INFO: Settings file created successfully at $SettingsFilePath"
            
            # Read the settings file
            $settingsContent = Get-Content -Path $SettingsFilePath -Raw
            $settings = ConvertFrom-Json -InputObject $settingsContent -Depth 10
            
            # Check if there are connection references to update
            if ($settings.ConnectionReferences -and $settings.ConnectionReferences.Count -gt 0) {
                Write-Host "INFO: Found $($settings.ConnectionReferences.Count) connection references in settings file"
                
                # Loop through connection references and update values
                foreach ($connectionRef in $settings.ConnectionReferences) {
                    # Check which connector we're dealing with
                    if ($connectionRef.ConnectorId -match "shared_azureaisearch") {
                        Write-Host "INFO: Found AI Search connection reference (ConnectorId: $($connectionRef.ConnectorId))"

                        if (![string]::IsNullOrEmpty($AiSearchConnectionId)) {
                            Write-Host "INFO: Setting AI Search connection ID"
                            $connectionRef.ConnectionId = $AiSearchConnectionId
                        } else {
                            Write-Host "WARNING: No AI Search connection ID provided - connection reference will remain unchanged"
                        }
                    } else {
                        Write-Host "INFO: Skipping connection reference for connector: $($connectionRef.ConnectorId)"
                    }
                }
                
                # Save the updated settings file
                $updatedJson = ConvertTo-Json -InputObject $settings -Depth 10
                Set-Content -Path $SettingsFilePath -Value $updatedJson -Force
                
                Write-Host "INFO: Updated settings file saved"
                                
                return $true
            } 
        }
        else {
            Write-Error "Settings file was not created at path: $SettingsFilePath"
            exit 1
        }
        return $false
    } catch {
        Write-Error "Error creating settings file: $_" -Level "ERROR"
        exit 1
    }

    return $true
}

#region Solution Generation
# Function to generate solution from source directory
function Package-Solution {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputFileName
    )
    
    Write-Host "INFO: Generating solution from source directory"
    
    # Create a timestamp for unique file naming
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # If no output filename provided, create one with timestamp
    if ([string]::IsNullOrEmpty($OutputFileName)) {
        $OutputFileName = "CopilotStudioGoldAgent_$timestamp.zip"
    }
    
    # Ensure output directory exists
    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        Write-Host "INFO: Created output directory: $OutputDirectory"
    }
    
    # Build full output path
    $outputSolutionPath = Join-Path -Path $OutputDirectory -ChildPath $OutputFileName
    
    Write-Host "INFO: Generating solution from source at $SourceDirectory"
    Write-Host "INFO: Output solution will be at $outputSolutionPath"
    
    # Check if source directory exists
    if (-not (Test-Path $SourceDirectory)) {
        Write-Error "Source directory does not exist at: $SourceDirectory"
        exit 1
    }
    
    try {
        # Generate the solution using pac cli
        $pacOutput = & pac solution pack --zipfile $outputSolutionPath --folder $SourceDirectory --packagetype Unmanaged 2>&1 | Out-String

        if (-not (Test-Path $outputSolutionPath)) {
            Write-Error "Solution generation failed. Output file was not created: $outputSolutionPath"
            Write-Error "PAC output: $pacOutput"
            exit 1
        }
        
        Write-Host "INFO: Solution successfully generated at: $outputSolutionPath"
        
        return $true
    } 
    catch {
        Write-Error "Solution generation failed: $_"
        Write-Error "PAC output: $pacOutput"
        exit 1
    }

    return $true
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
    
    Write-Host "INFO: Importing solution from $SolutionPath"
    
    try {
        # Execute the import command and capture the output
        $importResult = & pac solution import --path $SolutionPath --environment $PowerPlatformEnvironmentId --settings-file $SettingsFilePath --force-overwrite 2>&1 | Out-String

        Write-Host "INFO: Solution import command completed"

        $listOutput = & pac solution list --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
        $solutionName = [System.IO.Path]::GetFileNameWithoutExtension($SolutionPath)
        
        Write-Host "INFO: Solution list command completed: $listOutput"

        # TODO this is failing when not hard-coded even though the zip also contains this name. Come up with a better check
        if ($listOutput -match "GoldAgent") {
            Write-Host "INFO: Solution import verified successfully - found in environment"
        } else {
            Write-Error "Solution import validation failed - solution not found in environment"
            exit 1
        }
    } 
    catch {
        Write-Error "Solution import failed: $importResult"
        exit 1
    }
    
    # Wait for solution to be fully imported
    Write-Host "INFO: Waiting for solution import to stabilize..."
    Start-Sleep -Seconds 30
    
    # Publish all customizations
    Write-Host "INFO: Publishing all customizations..."
    try {
        $publishOutput = & pac solution publish --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
          # Check if the output contains failure indicators
        if (-not ($publishOutput -match "Published All Customizations")) {
            Write-Host "Solution publish appears to have failed with output: $publishOutput" -Level "ERROR"
            exit 1
        }
        
        Write-Host "INFO: Solution publication completed successfully"
        return $true
    } 
    catch {
        Write-Error "Publishing customizations failed even after reauthentication: $_" -Level "ERROR"
        exit 1
    }

    return $true
}

#region Solution Checker
# Function to run solution checker
function Invoke-SolutionChecker {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $true)]
        [string]$PowerPlatformEnvironmentId
    )
    
    Write-Host "INFO: Running solution checker for $SolutionName..."
    
    try {       
        # Run solution checker
        $checkerOutput = & pac solution check --path $SolutionPath --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
        
        # Check if the output contains failure indicators
        if ($checkerOutput -match "fail|error|exception" -and -not $checkerOutput -match "success") {
            Write-Host "WARNING: Solution checker appears to have failed with output: $checkerOutput"
            return $false
        }
        
        # Try to parse the JSON output for more detailed information
        try {
            $checkerResults = $checkerOutput | ConvertFrom-Json
            $issueCount = $checkerResults.Issues.Count
            
            if ($issueCount -gt 0) {
                Write-Host "WARNING: Solution checker found $issueCount issues" -Level "WARNING"
                foreach ($issue in $checkerResults.Issues) {
                    Write-Host "WARNING: Issue: $($issue.Description) - Severity: $($issue.Severity)" -Level "WARNING"
                }
            } else {
                Write-Host "INFO: Solution checker completed with no issues detected"
            }
        } catch {
            # If we can't parse as JSON, just log the raw output
            Write-Host "WARNING: Solution checker output (could not parse as JSON): $checkerOutput"
        }
        
        return $true
    } 
    catch {
        $errorMessage = $_.ToString()
        Write-Error "Solution checker failed: $errorMessage" -Level "ERROR"
        exit 1
    }

    return $true
}
#endregion

#region Main Execution

Write-Host "Starting Power Platform solution deployment process"
Write-Host "Solution path: $SolutionPath"
Write-Host "Environment ID: $PowerPlatformEnvironmentId"
Write-Host "Log directory: $LogDirectory"
Write-Host "Run solution checker: $RunSolutionChecker"
Write-Host "AI Search connection ID: $(if ([string]::IsNullOrEmpty($AISearchConnectionId)) { "Not provided" } else { "Provided" })"
Write-Host "Use GitHub federated: $UseGithubFederated"


# Step 1: Verify PAC CLI is installed
if (-not (Test-PacCliInstalled)) {
    Write-Error "PAC CLI installation was not detected. Cannot continue."
    exit 1
}

# Verify the solution file exists
if (-not (Test-Path $SolutionPath)) {
    Write-Error "Solution file does not exist at path: $SolutionPath"
    exit 1
}

# Step 2: Set up authentication
Set-PacAuthentication -UseGithubFederated $UseGithubFederated

# Step 3: Verify environment access
if (-not (Test-EnvironmentAccess -PowerPlatformEnvironmentId $PowerPlatformEnvironmentId)) {
    Write-Error "Cannot access the environment. Cannot continue."
    exit 1
}

# Step 4: Generate the solution from the specified source directory
# Define source and output paths
$solutionSourceDirectory = "src/powerplatform/copilot_studio_gold_agent"
$solutionOutputDirectory = "src/powerplatform"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$solutionOutputFileName = "GoldAgent_$timestamp.zip"
$solutionPath = Join-Path $solutionOutputDirectory $solutionOutputFileName
if (-not (Package-Solution -SourceDirectory $solutionSourceDirectory -OutputDirectory $solutionOutputDirectory -OutputFileName $solutionOutputFileName)) {
    Write-Error "Solution generation failed. Cannot continue."
    exit 1
}

# Step 5: Create settings file from solution and incorporate connection ID(s)
if ([string]::IsNullOrWhiteSpace($AISearchConnectionId)) {
    Write-Host "WARNING: No specific connection IDs provided."
}
$settingsFileName = "solution_settings_$timestamp.json"
Write-Host "INFO: Create settings file $settingsFileName"
$settingsCreated = New-SolutionSettingsFile -SolutionPath $solutionPath -SettingsFileName $settingsFileName -AiSearchConnectionId $AISearchConnectionId
$settingsFilePath = Join-Path $settingsDirectory $settingsFileName
Write-Host "INFO: Settings file path: $settingsFilePath"

# Step 6: Import the solution with settings file
if (-not (Import-PowerPlatformSolution -SolutionPath $solutionPath -PowerPlatformEnvironmentId $PowerPlatformEnvironmentId -SettingsFilePath $settingsFilePath)) {
    Write-Error "Solution import failed. Cannot continue."
    exit 1
}

# Step 7: Run solution checker if enabled
if ($RunSolutionChecker) {
    Write-Host "INFO: RunSolutionChecker is enabled. Running solution checker..."
    if (-not (Invoke-SolutionChecker -SolutionName $solutionOutputFileName -PowerPlatformEnvironmentId $PowerPlatformEnvironmentId)) {
        Write-Host "WARNING: Solution checker encountered issues. Review the logs for details."
    }
} else {
    Write-Host "INFO: RunSolutionChecker is disabled. Skipping solution checker."
}

# Summary
Write-Host "Power Platform solution deployment process completed"
Write-Host "Summary:"
Write-Host "  - Used connection ID: $AISearchConnectionId"
Write-Host "  - Settings file created: $(if ($settingsCreated) { 'Yes' } else { 'No' })"
Write-Host "  - Solution imported: Success"
Write-Host "  - Solution checker run: $(if ($RunSolutionChecker) { 'Yes' } else { 'No' })"

# Clean up the settings file
if (Test-Path $settingsFilePath) {
    Remove-Item -Path $settingsFilePath -Force
    Write-Host "Cleaned up temporary settings file"
}

# Clean up the solution file
if (Test-Path $solutionPath) {
    Remove-Item -Path $solutionPath -Force
    Write-Host "Cleaned up temporary solution file"
}

exit 0
#endregion
