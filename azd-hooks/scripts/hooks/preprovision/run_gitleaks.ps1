function Check-Gitleaks {
    Write-Host "Checking if Gitleaks is installed...`n"

    # Check if Gitleaks exists in system path
    $gitleaksPath = Get-Command gitleaks -ErrorAction SilentlyContinue

    if ($null -eq $gitleaksPath) {
        Write-Error "Gitleaks is not installed or not found in PATH!`n"
        exit 1
    } else {
        Write-Host "Gitleaks is installed at: $($gitleaksPath.Source)`n"
        # Ensure /usr/local/bin is in PATH
        $env:PATH += ":/usr/local/bin"
        # Check if Gitleaks is executable
        if (-not (Test-Path $gitleaksPath.Source)) {
            Write-Error "Gitleaks is not executable!`n"
            exit 1
        } else {
            Write-Host "Gitleaks is executable.`n"
        }

    }
}

function Run-Gitleaks {
    param (
        [string]$ReportFormat,
        [string]$LogLevel,
        [switch]$Redact,
        [switch]$Verbose,
        [switch]$NoGit
    )

    Write-Host "Run Gitleaks detect cmd...`n"

    $SourcePath = (Get-Location)

    # Get current git branch and check if repository has commits
    $currentBranch = $null
    $hasCommits = $false
    
    try {
        Write-Host "Getting current git branch..."
        $currentBranch = git branch --show-current
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to get git branch, defaulting to 'unknown'"
            $currentBranch = "unknown"
        } else {
            Write-Host "Current git branch: $currentBranch"
            
            # Check if the repository has any commits
            try {
                git rev-parse HEAD 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $hasCommits = $true
                    Write-Host "Repository has commits, will use branch reference in log options."
                } else {
                    Write-Host "Repository has no commits yet, will skip branch reference in log options."
                }
            } catch {
                Write-Host "Cannot determine commit history, will skip branch reference in log options."
            }
        }
    } catch {
        Write-Warning "Error getting git branch: $_"
        $currentBranch = "unknown"
    }

    # Construct command options as an array
    $cmdOptions = @(
        "detect"
        "--config", "$SourcePath/.gitleaks.toml"
        "--source", "$SourcePath"
        "--report-path", "./gitleaks-report.$ReportFormat"
        "--report-format", "$ReportFormat"
        "--log-level", "$LogLevel"
    )

    # Only add log-opts if we have a valid branch name and the repository has commits.
    if ($currentBranch -ne "unknown" -and $hasCommits) {
        $cmdOptions += "--log-opts"
        $cmdOptions += "$currentBranch"
    }

    if ($Redact) { $cmdOptions += "--redact" }
    if ($Verbose) { $cmdOptions += "--verbose" }

    Write-Verbose "gitleaks $($cmdOptions -join ' ')`n"

    # Run Gitleaks command
    gitleaks @cmdOptions
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Error "gitleaks failed`n"
        exit 1
    }
    else {
        Write-Host "gitleaks passed`n"
        exit 0
    }

}

# First, check if Gitleaks is installed
Check-Gitleaks

# Then, run Gitleaks scan
Run-Gitleaks -ReportFormat "sarif" -LogLevel "info" -Redact -Verbose
