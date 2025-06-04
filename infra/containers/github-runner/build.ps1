#!/usr/bin/env pwsh
<#
.SYNOPSIS
    GitHub Actions Self-Hosted Runner – Container Build Script (PowerShell)

.DESCRIPTION
    Builds and pushes the GitHub runner container image to Azure Container Registry,
    targeting linux/amd64 via Docker Buildx.

.REQUIREMENTS
    - PowerShell 7.5
    - Docker
    - Azure CLI
#>

[CmdletBinding()]
param()

# Stop on any error
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

#–– Configuration ––
# Registry (login server), Image name & tag, Dockerfile path
$RegistryName     = $Env:ACR_LOGIN_SERVER
$ImageName        = if ($Env:GITHUB_RUNNER_IMAGE_NAME) { $Env:GITHUB_RUNNER_IMAGE_NAME } else { 'github-runner' }
$Version          = if ($Env:GITHUB_RUNNER_IMAGE_TAG)  { $Env:GITHUB_RUNNER_IMAGE_TAG  } else { 'latest' }
$DockerfilePath   = $PSScriptRoot

#–– Colorized output helpers ––
function Print-Status  { param($m) Write-Host "[INFO]    $m" -ForegroundColor Green }
function Print-Warning { param($m) Write-Host "[WARNING] $m" -ForegroundColor Yellow }
function Print-Error   { param($m) Write-Host "[ERROR]   $m" -ForegroundColor Red }

#–– Fail early if registry isn’t specified ––
if (-not $RegistryName) {
    Print-Error "Azure Container Registry login server not specified. Please set the ACR_LOGIN_SERVER environment variable."
    exit 1
}

#–– Verify prerequisites ––
function Check-Requirements {
    Print-Status "Checking requirements..."
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Print-Error "Docker is not installed. Please install Docker first."
        exit 1
    }
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Print-Error "Azure CLI is not installed. Please install the Azure CLI first."
        exit 1
    }
    Print-Status "All requirements satisfied."
}

#–– Login to ACR ––
function Login-ToAcr {
    Print-Status "Logging in to Azure Container Registry..."
    if ($Env:ACR_USERNAME -and $Env:ACR_PASSWORD) {
        # username/password auth
        $Env:ACR_PASSWORD | docker login $RegistryName --username $Env:ACR_USERNAME --password-stdin
    }
    else {
        # Azure CLI auth (strip ".azurecr.io" from login server)
        $AcrName = $RegistryName -replace '\.azurecr\.io$',''
        az acr login --name $AcrName | Out-Null
    }
    Print-Status "Successfully logged in to ACR."
}

#–– Build & push amd64 image ––
function Build-ImageAmd64 {
    Print-Status "Building linux/amd64 container image..."

    # ensure buildx builder exists
    $builders = (& docker buildx ls) -join "`n"
    if (-not ($builders | Select-String 'amd64-builder')) {
        Print-Status "Creating amd64-only builder..."
        docker buildx create --name amd64-builder --use | Out-Null
    }
    else {
        docker buildx use amd64-builder | Out-Null
    }

    Print-Status "Running buildx for linux/amd64..."
    docker buildx build `
      --platform linux/amd64 `
      --file "${DockerfilePath}/Dockerfile" `
      --tag  "${RegistryName}/${ImageName}:${Version}" `
      --tag  "${RegistryName}/${ImageName}-amd64:${Version}" `
      --push `
      "${DockerfilePath}"

    Print-Status "amd64 image built and pushed successfully."
}

#–– Main ––
function Main {
    Print-Status "Starting GitHub Runner container build process..."
    Print-Status "Registry:         ${RegistryName}"
    Print-Status "Image:            ${ImageName}:${Version}"
    Print-Status "Dockerfile path:  ${DockerfilePath}"

    Check-Requirements
    Login-ToAcr
    Build-ImageAmd64

    Print-Status "Build process completed successfully!"
    Print-Status "Image available at: ${RegistryName}/${ImageName}:${Version} (amd64)"
}

# Execute
Main
