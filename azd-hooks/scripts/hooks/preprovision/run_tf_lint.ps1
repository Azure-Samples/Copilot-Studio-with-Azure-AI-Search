function Check-TFLint {
    Write-Host "Checking if TFLint is installed...`n"

    # Check if TFLint exists in system path
    $tflintPath = Get-Command tflint -ErrorAction SilentlyContinue

    if ($null -eq $tflintPath) {
        Write-Error "TFLint is not installed or not found in PATH!`n"
        exit 1
    } else {
        Write-Host "TFLint is installed at: $($tflintPath.Source)`n"

        # Ensure /usr/local/bin is in PATH
        $env:PATH += ":/usr/local/bin"

        # Check if TFLint is executable
        if (-not (Test-Path $tflintPath.Source)) {
            Write-Error "TFLint is not executable!`n"
            exit 1
        } else {
            Write-Host "TFLint is executable.`n"
        }
    }
}

function Run-TFLint {
    Write-Host "Running TFLint...`n"

    Push-Location $PWD
    cd $PWD/infra

    # Define lint result file name
    $lintResFileName = "$((Get-Item -Path $PWD).BaseName)_lint_res.xml"
    $filePath = $lintResFileName -replace "/", "-"

    # Run TFLint and capture output
    & tflint 2>&1 | Out-File -FilePath $filePath
    $code = $LASTEXITCODE

    # Check if lint result file exists
    if (Test-Path $filePath) {
        if (-not (Get-Content $filePath | Where-Object { $_.Trim() -ne "" })) {
            Write-Output "TFLint passed"
            Pop-Location
            exit $code
        }
    } else {
        Write-Output "TFLint failed. Lint results are saved in: $lintResFileName, Path: $filePath`n"

        # Remove ANSI escape sequences
        (Get-Content $filePath) -replace "\x1b\[[0-9;]*m", "" | Set-Content $filePath
        Get-Content $filePath | ForEach-Object { Write-Error $_ -Verbose }

        Pop-Location
        exit $code
    }
}
# First, check if TFLint is installed
Check-TFLint

# Then, run Gitleaks scan
Run-TFLint
