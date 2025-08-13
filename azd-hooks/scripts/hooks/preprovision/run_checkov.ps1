function Check-Checkov {
    Write-Host "Checking if Checkov is installed...`n"

    # Check if Checkov exists in system path
    $checkovPath = Get-Command checkov -ErrorAction SilentlyContinue

    if ($null -eq $checkovPath) {
        Write-Error "Checkov is not installed or not found in PATH!`n"
        exit 1
    } else {
        Write-Host "Checkov is installed at: $($checkovPath.Source)`n"

        # Ensure /usr/local/bin is in PATH (for Linux/macOS)
        $env:PATH += ":/usr/local/bin"

        # Check if Checkov is executable
        if (-not (Test-Path $checkovPath.Source)) {
            Write-Error "Checkov is not executable!`n"
            exit 1
        } else {
            Write-Host "Checkov is executable.`n"
        }
    }
}

function Run-Checkov {    param (
        [string]$ReportFormat,
        [string]$TfDirectory = "./infra")
    Write-Host "Running Checkov...`n"

    # Define checkov result file name
    $CheckovResFileName= "checkov-results.$ReportFormat"

    # Run Checkov and capture output
    checkov -d $TfDirectory --quiet --framework terraform -o $ReportFormat --output-file "./$CheckovResFileName" --soft-fail
    $exitCode = $LASTEXITCODE

    # Check if lint result file exists
     if ($exitCode -ne 0) {
        Write-Error "checkov failed`n"
        exit 1
    }
    else {
        Write-Host "checkov passed`n"
        exit 0
    }
}

# First, check if Checkov is installed
Check-Checkov

#Run Checkov
Run-Checkov -ReportFormat sarif
