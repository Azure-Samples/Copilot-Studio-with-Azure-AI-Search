function Run-Gitleaks {
     param (
        [string]$ReportFormat,
        [string]$LogLevel,
        [switch]$Redact,
        [switch]$Verbose,
        [switch]$NoGit
    )

    write-Host "Run Gitleaks detect cmd...`n"

    $SourcePath = (Get-Location)

    # Construct command options as an array
    $cmdOptions = @(
        "detect"
        "--config", "$SourcePath\.gitleaks.toml"
        "--source", "$SourcePath"
        "--report-path", "./gitleaks-report.$ReportFormat"
        "--report-format", "$ReportFormat"
        "--log-level", "$LogLevel"
    )

    if ($Redact) { $cmdOptions += "--redact" }
    if ($Verbose) { $cmdOptions += "--verbose" }

    Write-Verbose "gitleaks $($cmdOptions -join ' ')`n"

    # Run Gitleaks command
    gitleaks @cmdOptions
    $exitCode = $LASTEXITCODE

    # return $exitCode
    if ($exitCode -ne 0) {
        Write-Error "gitleaks failed`n"
        exit 1
    }
    else {
        Write-Host "gitleaks passed`n"
        exit 0
    }

}

Run-Gitleaks -ReportFormat "sarif" -LogLevel "info" -Redact -Verbose
