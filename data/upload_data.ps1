<#
.SYNOPSIS
    Uploads all PDF files from the current directory to an Azure Blob Storage container.

.DESCRIPTION
    This script uses the Azure CLI to authenticate and upload files to Azure Blob Storage.
    It checks if the specified container exists and creates it if necessary.

.PARAMETER StorageAccountName
    The name of the Azure Storage account.

.PARAMETER ContainerName
    The name of the Azure Blob Storage container.

.EXAMPLE
    ./upload_data.ps1 -StorageAccountName "mystorageaccount" -ContainerName "mycontainer"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerName
)

# Get the current directory
$LocalFolder = Get-Location

# Check if the container exists, and create it if it doesn't
Write-Host "Checking if container '$ContainerName' exists in storage account '$StorageAccountName'..."
$ContainerExists = az storage container exists `
    --account-name $StorageAccountName `
    --name $ContainerName `
    --auth-mode login `
    --query "exists" `
    --output tsv

if ($ContainerExists -ne "true") {
    Write-Host "Container '$ContainerName' does not exist. Creating it..."
    az storage container create `
        --account-name $StorageAccountName `
        --name $ContainerName `
        --auth-mode login `
        --output none
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create container '$ContainerName'." -ForegroundColor Red
        exit 1
    }
    Write-Host "Container '$ContainerName' created successfully." -ForegroundColor Green
} else {
    Write-Host "Container '$ContainerName' already exists." -ForegroundColor Green
}

# Upload all PDF files from the current directory
Write-Host "Uploading PDF files from '$LocalFolder' to container '$ContainerName'..."
Get-ChildItem -Path $LocalFolder -Recurse -Filter *.pdf | ForEach-Object {
    $FilePath = $_.FullName
    $BlobName = $FilePath.Substring($LocalFolder.Length + 1) -replace '\\', '/'
    Write-Host "Uploading '$FilePath' as blob '$BlobName'..."
    az storage blob upload `
        --account-name $StorageAccountName `
        --container-name $ContainerName `
        --name $BlobName `
        --auth-mode login `
        --file $FilePath `
        --overwrite
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to upload '$FilePath'." -ForegroundColor Red
    } else {
        Write-Host "Uploaded '$FilePath' successfully." -ForegroundColor Green
    }
}

Write-Host "Upload process completed." -ForegroundColor Cyan
