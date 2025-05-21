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
      -SolutionPath "../powerplatform/GoldAgent.zip" `
      -PowerPlatformEnvironmentId "your-environment-id" `
      -AISearchConnectionId "<AI Search Connection ID from Terraform Outputs>"

.PARAMETER SolutionPath
    Path to the solution zip file to deploy

.PARAMETER PowerPlatformEnvironmentId
    ID of the Power Platform environment to deploy to

.PARAMETER LogDirectory
    Directory where logs will be stored

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
    [string]$LogDirectory = "$PSScriptRoot/power_platform_deployment_logs",
    
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

# Setup logging
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $LogDirectory "power_platform_deploy_$timestamp.log"

# Create logs directory if it doesn't exist
if (!(Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

# Function to log messages
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
    
    # Also write to log file
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

# Function to ensure PAC CLI is installed
function Test-PacCliInstalled {
    Write-Log "Checking if PAC CLI is installed"
    try {
        $pacVersion = & pac help 2>&1 | Select-String "Microsoft Power Platform CLI"
        if ($pacVersion) {
            Write-Log "Using PAC CLI: $pacVersion"
            return $true
        }        else {
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
# Function to handle PAC CLI authentication
function Set-PacAuthentication {    
    param (        
        [bool]$UseGithubFederated
    )
    
    Write-Log "Starting authentication"

    # Try Github federated auth first if explicitly requested or if environment variables are available
    if ($UseGithubFederated -and
        (![string]::IsNullOrEmpty($env:POWER_PLATFORM_CLIENT_ID) -and 
         ![string]::IsNullOrEmpty($env:POWER_PLATFORM_TENANT_ID))) {
            Write-Log "Setting a PAC auth profile based on GitHub federated authentication"
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
        
        Write-Log "Found service principal environment variables, using service principal authentication"

        # Create new service principal auth profile
        Write-Log "Creating new service-principal-auth profile"
        # Execute the auth create command and capture output
        $authOutput = & pac auth create --name service-principal-auth `
                    --applicationId $env:POWER_PLATFORM_CLIENT_ID `
                    --clientSecret $env:POWER_PLATFORM_CLIENT_SECRET `
                    --tenant $env:POWER_PLATFORM_TENANT_ID `
                    --accept-cleartext-caching 2>&1 | Out-String

        # Log the output from the auth create command
        Write-Log "PAC auth create output: $authOutput"

        & pac auth select --name service-principal-auth    } else {
        # Try to find active pac CLI auth profile
        $activeLine = pac auth list | Where-Object { $_ -match '^\[\d+\]\s+\*\s+' }
        $tokens = $activeLine -split '\s+'
        $activeName = $tokens[3]
        
        # If we found an active profile, it's already set - just use it. If not, create a new one.
        if ([string]::IsNullOrEmpty($activeName)) {
            Write-Log "Creating new az-cli-auth profile"
            & pac auth create --name az-cli-auth
            & pac auth select --name az-cli-auth
        } else {
            Write-Log "Using existing active auth profile: $activeName"
        }
    }
}

# Function to ensure the environment is accessible
function Test-EnvironmentAccess {    param (
        [Parameter(Mandatory = $true)]
        [string]$PowerPlatformEnvironmentId
    )
    
    Write-Log "Checking access to environment $PowerPlatformEnvironmentId"
    try {
        & pac org who --environment $PowerPlatformEnvironmentId
        Write-Log "Environment is accessible"
        return $true
    } 
    catch {
        Write-Log "Authentication failed or token expired. Attempting to reauthenticate..." -Level "WARNING"
        
        # Try to reauthenticate
        Set-PacAuthentication -UseGithubFederated $UseGithubFederated
        
        # Try again
        try {
            & pac org who --environment $PowerPlatformEnvironmentId
            Write-Log "Environment is now accessible after reauthentication"
            return $true
        }        catch {
            Write-Error "Failed to access environment even after reauthentication: $_"
            exit 1
        }
    }
}

#region Connection Setup
# Function to create settings file from solution
function New-SolutionSettingsFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SolutionPath,
        
        [Parameter(Mandatory = $true)]
        [string]$SettingsFileName,
        
        [Parameter(Mandatory = $false)]
        [string]$AiSearchConnectionId = ""
    )
    
    Write-Log "Creating settings file for solution $SolutionPath"
    
    # Create the settings file from the solution
    try {
        # Use the settings directory instead of the current directory
        $SettingsFilePath = Join-Path $settingsDirectory $SettingsFileName
        
        & pac solution create-settings --solution-zip $SolutionPath --settings-file $SettingsFilePath
        
        if (Test-Path $SettingsFilePath) {
            Write-Log "Settings file created successfully at $SettingsFilePath"
            
            # Read the settings file
            $settingsContent = Get-Content -Path $SettingsFilePath -Raw
            $settings = ConvertFrom-Json -InputObject $settingsContent -Depth 10
            
            # Check if there are connection references to update
            if ($settings.ConnectionReferences -and $settings.ConnectionReferences.Count -gt 0) {
                Write-Log "Found $($settings.ConnectionReferences.Count) connection references in settings file"
                
                # Loop through connection references and update values
                foreach ($connectionRef in $settings.ConnectionReferences) {
                    # Check which connector we're dealing with
                    if ($connectionRef.ConnectorId -match "shared_azureaisearch") {
                        Write-Log "Found AI Search connection reference (ConnectorId: $($connectionRef.ConnectorId))" 

                        if (![string]::IsNullOrEmpty($AiSearchConnectionId)) {
                            Write-Log "Setting AI Search connection ID to: $AiSearchConnectionId"
                            $connectionRef.ConnectionId = $AiSearchConnectionId
                        } else {
                            Write-Log "No AI Search connection ID provided - connection reference will remain unchanged" -Level "WARNING"
                        }
                    } else {
                        Write-Log "Skipping connection reference for connector: $($connectionRef.ConnectorId)"
                    }
                }
                
                # Save the updated settings file
                $updatedJson = ConvertTo-Json -InputObject $settings -Depth 10
                Set-Content -Path $SettingsFilePath -Value $updatedJson -Force
                
                Write-Log "Updated settings file saved"            # Output the settings file content to the log (masked for security)
                $maskedSettings = $settings | ConvertTo-Json -Depth 10
                Write-Log "Settings file updated successfully"
                
                return $true
            } 
        }
        return $false
    } catch {
        Write-Log "Error creating settings file: $_" -Level "ERROR"
        return $false
    }
}

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
    
    $maxRetries = 3
    $retry = 0
    $success = $false
    
    while ($retry -lt $maxRetries -and !$success) {
        $retry++
        Write-Log "Importing solution from $SolutionPath (Attempt $retry of $maxRetries)"
        
        try {
            # Execute the import command and capture the output
            $importOutput = & pac solution import --path $SolutionPath --environment $PowerPlatformEnvironmentId --settings-file $SettingsFilePath --force-overwrite 2>&1 | Out-String

            $checkOutput = & pac solution list --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
            $solutionName = [System.IO.Path]::GetFileNameWithoutExtension($SolutionPath)
            
            if ($checkOutput -match $solutionName) {
                $success = $true
                Write-Log "Solution import verified successfully - found in environment"
            } else {                Write-Error "Solution import validation failed - solution not found in environment"
                exit 1
            }
        } 
        catch {
            $errorMessage = $_.ToString()
            Write-Log "Solution import failed on attempt ${retry}: ${errorMessage}" -Level "ERROR"
            
            # Check if this is an authentication error
            if ($errorMessage -match "AADSTS70008" -or 
                $errorMessage -match "token.*expired" -or 
                $errorMessage -match "401 Unauthorized") {
                
                Write-Log "Authentication error detected. Attempting to reauthenticate..." -Level "WARNING"
                Set-PacAuthentication -UseGithubFederated $UseGithubFederated
                
                # Try again immediately after re-authentication
                try {
                    $importOutput = & pac solution import --path $SolutionPath --environment $PowerPlatformEnvironmentId --settings-file $SettingsFilePath --force-overwrite 2>&1 | Out-String
                    
                    # Check if the output contains failure indicators
                    if ($importOutput -match "fail|error|exception" -and -not $importOutput -match "success") {                        Write-Error "Solution import appears to have failed with output: $importOutput"
                        exit 1
                    }
                    
                    # Validate the solution was actually imported
                    $checkOutput = & pac solution list --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
                    $solutionName = [System.IO.Path]::GetFileNameWithoutExtension($SolutionPath)
                    
                    if ($checkOutput -match $solutionName) {
                        $success = $true
                        Write-Log "Solution imported successfully after reauthentication"
                        continue
                    } else {                        Write-Error "Solution import validation failed after reauthentication"
                        exit 1
                    }
                } 
                catch {
                    Write-Error "Solution import failed even after reauthentication."
                    exit 1
                }
            }
            
            # If not the last retry, wait before trying again
            if ($retry -lt $maxRetries) {
                $waitTime = [Math]::Pow(2, $retry) * 30 # Exponential backoff
                Write-Log "Waiting $waitTime seconds before next retry..."
                Start-Sleep -Seconds $waitTime
            } 
            else {                Write-Error "Failed to import solution after $maxRetries attempts."
                exit 1
            }
        }
    }
    
    if (!$success) {        Write-Error "Solution import ultimately failed after all retry attempts"
        exit 1
    }
    
    # Wait for solution to be fully imported
    Write-Log "Waiting for solution import to stabilize..."
    Start-Sleep -Seconds 30
    
    # Publish all customizations
    Write-Log "Publishing all customizations..."
    try {
        $publishOutput = & pac solution publish --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
          # Check if the output contains failure indicators
        if (-not ($publishOutput -match "success")) {
            Write-Error "Solution publish appears to have failed with output: $publishOutput"
            exit 1
        }
        
        Write-Log "Solution publication completed successfully"
        return $true
    } 
    catch {
        $errorMessage = $_.ToString()
        Write-Log "Publishing customizations failed: $errorMessage" -Level "ERROR"
        
        # Check if this is an authentication error
        if ($errorMessage -match "AADSTS70008" -or 
            $errorMessage -match "token.*expired" -or 
            $errorMessage -match "401 Unauthorized") {
            
            Write-Log "Authentication error detected. Attempting to reauthenticate..." -Level "WARNING"
            Set-PacAuthentication -UseGithubFederated $UseGithubFederated
            
            # Try again immediately after re-authentication
            try {
                $publishOutput = & pac solution publish --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
                
                # Check if the output contains failure indicators
                if ($publishOutput -match "fail|error|exception" -and -not $publishOutput -match "success") {
                    Write-Log "Solution publish appears to have failed with output: $publishOutput" -Level "ERROR"
                    return $false
                }
                
                Write-Log "Solution published successfully after reauthentication"
                return $true
            } 
            catch {
                Write-Log "Publishing customizations failed even after reauthentication: $_" -Level "ERROR"
                return $false
            }
        } 
        else {
            return $false
        }
    }
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
    
    Write-Log "Running solution checker for $SolutionName..."
    
    try {        # Run solution checker
        $checkerOutput = & pac solution check --path $SolutionPath --environment $PowerPlatformEnvironmentId 2>&1 | Out-String
        
        # Check if the output contains failure indicators
        if ($checkerOutput -match "fail|error|exception" -and -not $checkerOutput -match "success") {
            Write-Log "Solution checker appears to have failed with output: $checkerOutput" -Level "WARNING"
            return $false
        }
        
        # Try to parse the JSON output for more detailed information
        try {
            $checkerResults = $checkerOutput | ConvertFrom-Json
            $issueCount = $checkerResults.Issues.Count
            
            if ($issueCount -gt 0) {
                Write-Log "Solution checker found $issueCount issues" -Level "WARNING"
                foreach ($issue in $checkerResults.Issues) {
                    Write-Log "Issue: $($issue.Description) - Severity: $($issue.Severity)" -Level "WARNING"
                }
            } else {
                Write-Log "Solution checker completed with no issues detected"
            }
        } catch {
            # If we can't parse as JSON, just log the raw output
            Write-Log "Solution checker output (could not parse as JSON): $checkerOutput"
        }
        
        return $true
    } 
    catch {
        $errorMessage = $_.ToString()
        Write-Error "Solution checker failed: $errorMessage"
        exit 1
    }
}
#endregion

#region Main Execution

Write-Log "Starting Power Platform solution deployment process"
Write-Log "Solution path: $SolutionPath"
Write-Log "Environment ID: $PowerPlatformEnvironmentId"
Write-Log "Log directory: $LogDirectory"
Write-Log "Run solution checker: $RunSolutionChecker"
Write-Log "AI Search connection ID: $(if ([string]::IsNullOrEmpty($AISearchConnectionId)) { "Not provided" } else { "Provided" })"
Write-Log "Use GitHub federated: $UseGithubFederated"


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
    Write-Log "Cannot access the environment. Cannot continue." -Level "ERROR"
    exit 1
}

# Step 4: Get the solution name from the zip file
$solutionName = [System.IO.Path]::GetFileNameWithoutExtension($SolutionPath)
Write-Log "Solution name determined as: $solutionName"

if ([string]::IsNullOrWhiteSpace($AISearchConnectionId)) {
    Write-Log "No specific connection IDs provided." -Level "WARNING"
}

# Step 5: Create settings file from solution
$settingsFileName = "solution_settings_$timestamp.json"
Write-Log "Creating settings file $settingsFileName"
$settingsCreated = New-SolutionSettingsFile -SolutionPath $SolutionPath -SettingsFileName $settingsFileName -AiSearchConnectionId $AISearchConnectionId
$settingsFilePath = Join-Path $settingsDirectory $settingsFileName
Write-Log "Settings file path: $settingsFilePath"

# Step 6: Import the solution with settings file
if (-not (Import-PowerPlatformSolution -SolutionPath $SolutionPath -PowerPlatformEnvironmentId $PowerPlatformEnvironmentId -SettingsFilePath $settingsFilePath)) {
    Write-Log "Solution import failed. Cannot continue." -Level "ERROR"
    exit 1
}

# Step 7: Run solution checker if enabled
if ($RunSolutionChecker) {
    Write-Log "RunSolutionChecker is enabled. Running solution checker..."
    if (-not (Invoke-SolutionChecker -SolutionName $solutionName -PowerPlatformEnvironmentId $PowerPlatformEnvironmentId)) {
        Write-Log "Solution checker encountered issues. Review the logs for details." -Level "WARNING"
    }
} else {
    Write-Log "RunSolutionChecker is disabled. Skipping solution checker."
}

# Summary
Write-Log "Power Platform solution deployment process completed"
Write-Log "Summary:"
Write-Log "  - Used connection ID: $AISearchConnectionId"
Write-Log "  - Settings file created: $(if ($settingsCreated) { 'Yes' } else { 'No' })"
Write-Log "  - Solution imported: Success"
Write-Log "  - Solution checker run: $(if ($RunSolutionChecker) { 'Yes' } else { 'No' })"

# Clean up the settings file
if (Test-Path $settingsFilePath) {
    Remove-Item -Path $settingsFilePath -Force
    Write-Log "Cleaned up temporary settings file"
}

exit 0
#endregion
