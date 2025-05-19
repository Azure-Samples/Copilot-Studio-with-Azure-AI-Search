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

    return $exitCode
}

Run-Gitleaks -ReportFormat "sarif" -LogLevel "info" -Redact -Verbose

# function Run-Gitleaks {
#      param (
#         [string]$ReportFormat,
#         [string]$LogLevel,
#         [switch]$Redact,
#         [switch]$Verbose,
#         [switch]$NoGit
#     )

#     Write-Output "Run Gitleaks detect cmd"

#     $SourcePath = (Get-Location)
#     Write-Output "SourcePath: $SourcePath"

#     # Construct command options as an array
#     $cmdOptions = @(
#         "detect"
#         "--config", "$SourcePath\.gitleaks.toml"
#         "--source", "$SourcePath"
#         "--report-path", "./gitleaks-report.$ReportFormat"
#         "--report-format", "$ReportFormat"
#         "--log-level", "$LogLevel"
#     )

#     if ($Redact) { $cmdOptions += "--redact" }
#     if ($Verbose) { $cmdOptions += "--verbose" }

#     Write-Output "gitleaks $($cmdOptions -join ' ')"

#     # Run Gitleaks command
#     gitleaks @cmdOptions
#     $exitCode = $LASTEXITCODE
#     # exit $exitCode
#     return $exitCode
# }

# Run-Gitleaks -ReportFormat "sarif" -LogLevel "info" -Redact -Verbose