<#
.SYNOPSIS
    Executes Azure Developer CLI (azd) commands with debug flag detection based on GitHub Actions debug logging settings.

.DESCRIPTION
    This script detects if GitHub Actions debug logging is enabled by checking the ACTIONS_STEP_DEBUG,
    ACTIONS_RUNNER_DEBUG, and RUNNER_DEBUG environment variables. If any of these are set to indicate
    debug mode, it automatically appends the --debug flag to the azd command.

.PARAMETER Command
    The azd command to execute (e.g., "provision", "down").

.PARAMETER Arguments
    Additional arguments to pass to the azd command (e.g., "--no-prompt", "--force", "--purge").

.EXAMPLE
    .\Invoke-AzdWithDebug.ps1 -Command "provision" -Arguments "--no-prompt"
    
    Executes: azd provision --no-prompt (or azd provision --no-prompt --debug if debug logging is enabled)

.EXAMPLE
    .\Invoke-AzdWithDebug.ps1 -Command "down" -Arguments "--no-prompt --force --purge"
    
    Executes: azd down --no-prompt --force --purge (or with --debug if debug logging is enabled)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    
    [Parameter(Mandatory = $false)]
    [string]$Arguments = ""
)

# Detect if debug logging is enabled
$debugEnabled = ($env:ACTIONS_STEP_DEBUG -eq "true") `
                -or ($env:ACTIONS_RUNNER_DEBUG -eq "true") `
                -or ($env:RUNNER_DEBUG -eq "1")

# Build the azd command
$azdCommand = "azd $Command"

# Add provided arguments
if ($Arguments) {
    $azdCommand += " $Arguments"
}

# Add debug flag if enabled
if ($debugEnabled) {
    $azdCommand += " --debug"
    Write-Host "Debug logging is enabled. Executing: $azdCommand"
} else {
    Write-Host "Executing: $azdCommand"
}

# Execute the command
Invoke-Expression $azdCommand

# Preserve the exit code
$exitCode = $LASTEXITCODE
exit $exitCode
