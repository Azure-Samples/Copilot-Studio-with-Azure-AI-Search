Write-Host "Execute: Pre-Provision Hook"

Write-Host "1- Run gitleaks cmd`n"

$gitleaksExitCode = & (Resolve-Path "./azd-hooks/scripts/hooks/run_gitleaks.ps1")

if ($gitleaksExitCode -ne 0) {
    Write-Error "gitleaks failed`n"
    exit 1
}
else {
    Write-Host "gitleaks passed`n"
}

Write-Host "==================== `n"
Write-Host "2- Run tf-lint cmd`n"

$tfLintExitCode = & (Resolve-Path "./azd-hooks/scripts/hooks/run_tf_lint.ps1")
write-host "tf-lint exit code: $tfLintExitCode"
if ($tfLintExitCode -ne 0) {
    Write-Error "tf-lint Hook failed`n"
    exit 1
}