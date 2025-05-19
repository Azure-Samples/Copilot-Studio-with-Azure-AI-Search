Write-Host "Run tf-lint cmd...`n"
Push-Location $PWD

cd $PWD/infra
# Define lint result file name
$lintResFileName = "$((Get-Item -Path $PWD).BaseName)_lint_res.xml"
$filePath = $lintResFileName -replace "/", "-"

# Run TFLint and capture output
$tflintOutput = & tflint 2>&1 | Out-File -FilePath $filePath
$code = $LASTEXITCODE

if (-not (Get-Content $filePath | Where-Object { $_.Trim() -ne "" })) {
    Write-Output "TFLint passed"
    Pop-Location
    exit $code
} else {
    Write-Output "TFLint failed. Lint results are saved in: $lintResFileName, Path:$filePath`n"
    (Get-Content $filePath) -replace "\x1b\[[0-9;]*m", "" | Set-Content $filePath
    Get-Content $filePath | ForEach-Object { Write-Error $_ -Verbose }
    Pop-Location
    exit $code
}