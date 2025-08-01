<#
.SYNOPSIS
Checks the existence of the RS_CONTAINER_NAME environment variable.

.DESCRIPTION
This script checks if the RS_CONTAINER_NAME environment variable is set. 
The presence or absence of this variable is used to determine whether 
local storage should be used or not.

#>
$script:infraDir = "infra"
$script:providerConfPath = Join-Path $script:infraDir "provider.conf.json"
$script:providerTfPath = Join-Path $script:infraDir "provider.tf"

function Initialize-LocalStorage {
    Write-Host "Function 'Initialize-LocalStorage' called - Local state is enabled"
    
    try {
        # 1. Override the content of provider.conf.json with {}
        Write-Host "Setting up provider.conf.json for local storage..."
        
        # Check if the infra directory exists
        if (-not (Test-Path -Path $script:infraDir)) {
            Write-Host "✗ Infra directory not found at path: $script:infraDir"
            throw "Infra directory does not exist"
        }
        
        # Check if provider.conf.json exists, create if it doesn't
        if (-not (Test-Path -Path $script:providerConfPath)) {
            Write-Host "⚠ provider.conf.json not found, creating new file..."
        }
        
        Set-Content -Path $script:providerConfPath -Value "{}" -Encoding UTF8
        Write-Host "✓ provider.conf.json updated successfully"
        
        # 2. Update provider.tf to use local backend
        Write-Host "Configuring Terraform backend for local storage..."
   
        
        # Check if provider.tf exists
        if (-not (Test-Path -Path $script:providerTfPath)) {
            Write-Host "✗ provider.tf not found at path: $script:providerTfPath"
            throw "provider.tf file does not exist"
        }
        
        # Read the current content
        $content = Get-Content -Path $script:providerTfPath -Raw
        
        # Define the new terraform block with local backend
        $newTerraformBlock = @"
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
"@
        
        # Use regex to replace the first terraform block (the one with backend configuration)
        # This pattern matches the terraform block that contains backend configuration
        $pattern = '(?s)terraform\s*\{[^}]*backend\s*"[^"]*"\s*\{[^}]*\}[^}]*\}'
        
        if ($content -match $pattern) {
            $updatedContent = $content -replace $pattern, $newTerraformBlock
            Set-Content -Path $script:providerTfPath -Value $updatedContent -Encoding UTF8
            Write-Host "✓ provider.tf updated to use local backend"
        } else {
            Write-Host "⚠ Could not find terraform backend block in provider.tf"
        }
        
    } catch {
        Write-Host "✗ Error configuring local storage: $($_.Exception.Message)"
        throw
    }
}

function Initialize-RemoteStorage {
    Write-Host "Function 'Initialize-RemoteStorage' called - Remote state is enabled"
    try {
        # 1. Update the content of provider.conf.json with remote storage configuration
        Write-Host "Setting up provider.conf.json for remote storage..."

        # Check if the infra directory exists
        if (-not (Test-Path -Path $script:infraDir)) {
            Write-Host "✗ Infra directory not found at path: $script:infraDir"
            throw "Infra directory does not exist"
        }
        
        # Check if provider.conf.json exists, create if it doesn't
        if (-not (Test-Path -Path $script:providerConfPath)) {
            Write-Host "⚠ provider.conf.json not found, creating new file..."
        }
        
        $remoteStorageConfig = @"
{
    "storage_account_name": "`${RS_STORAGE_ACCOUNT}`",
    "container_name": "`${RS_CONTAINER_NAME}`",
    "key": "azd/`${AZURE_ENV_NAME}`/terraform.tfstate",
    "resource_group_name": "`${RS_RESOURCE_GROUP}`",
    "use_azuread_auth": "true"
}
"@
        Set-Content -Path $script:providerConfPath -Value $remoteStorageConfig -Encoding UTF8
        Write-Host "✓ provider.conf.json updated successfully for remote storage"
        
        # 2. Update provider.tf to use azurerm backend
        Write-Host "Configuring Terraform backend for remote storage..."
        
        # Check if provider.tf exists
        if (-not (Test-Path -Path $script:providerTfPath)) {
            Write-Host "✗ provider.tf not found at path: $script:providerTfPath"
            throw "provider.tf file does not exist"
        }
        
        # Read the current content
        $content = Get-Content -Path $script:providerTfPath -Raw
        
        # Define the new terraform block with azurerm backend
        $newTerraformBlock = @"
terraform {
  backend "azurerm" {
  }
}
"@
        
        # Use regex to replace the first terraform block (the one with backend configuration)
        # This pattern matches the terraform block that contains backend configuration
        $pattern = '(?s)terraform\s*\{[^}]*backend\s*"[^"]*"\s*\{[^}]*\}[^}]*\}'
        
        if ($content -match $pattern) {
            $updatedContent = $content -replace $pattern, $newTerraformBlock
            Set-Content -Path $script:providerTfPath -Value $updatedContent -Encoding UTF8
            Write-Host "✓ provider.tf updated to use azurerm backend"
        } else {
            Write-Host "⚠ Could not find terraform backend block in provider.tf"
        }
        
    } catch {
        Write-Host "✗ Error configuring remote storage: $($_.Exception.Message)"
        throw
    }
}


Write-Host "Checking if RS_CONTAINER_NAME environment variable exists..."
# Check if RS_CONTAINER_NAME azd environment variable exists
try {
    $rsContainerName = $env:RS_CONTAINER_NAME
    if ($rsContainerName) {
        Write-Host "✓ RS_CONTAINER_NAME environment variable exists with value: $rsContainerName"
        
        # Check if the value is not empty or null
        if (-not [string]::IsNullOrWhiteSpace($rsContainerName)) {
            Write-Host "✓ RS_CONTAINER_NAME is set to a valid value"
            Initialize-RemoteStorage
        } else {
            Write-Host "ℹ RS_CONTAINER_NAME is empty or null"
            Initialize-LocalStorage
        }
    } else {
        Write-Host "✗ RS_CONTAINER_NAME environment variable does not exist or is empty"
        azd env set RS_CONTAINER_NAME ""
        Initialize-LocalStorage
    }
} catch {
    Write-Host "✗ Error checking RS_CONTAINER_NAME environment variable: $($_.Exception.Message)"
    Write-Host "ℹ Make sure you're in an azd environment directory"
    exit 1
}