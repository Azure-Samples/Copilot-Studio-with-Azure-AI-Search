#!/bin/bash

# Description:
# This script uploads all PDF files from the current directory to an Azure Blob Storage container.
# It uses the Azure CLI for authentication and file uploads.

# Usage:
# ./upload_data.sh <storage_account_name> <container_name>

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <storage_account_name> <container_name>"
    exit 1
fi

STORAGE_ACCOUNT_NAME=$1
CONTAINER_NAME=$2
LOCAL_FOLDER=$(pwd)

# Check if the container exists, and create it if it doesn't
echo "Checking if container '$CONTAINER_NAME' exists in storage account '$STORAGE_ACCOUNT_NAME'..."
CONTAINER_EXISTS=$(az storage container exists --account-name "$STORAGE_ACCOUNT_NAME" --name "$CONTAINER_NAME" --auth-mode login --query "exists" --output tsv)

if [ "$CONTAINER_EXISTS" != "true" ]; then
    echo "Container '$CONTAINER_NAME' does not exist. Creating it..."
    az storage container create --account-name "$STORAGE_ACCOUNT_NAME" --name "$CONTAINER_NAME" --auth-mode login --output none
    if [ $? -ne 0 ]; then
        echo "Failed to create container '$CONTAINER_NAME'."
        exit 1
    fi
    echo "Container '$CONTAINER_NAME' created successfully."
else
    echo "Container '$CONTAINER_NAME' already exists."
fi

# Upload all PDF files from the current directory
echo "Uploading PDF files from '$LOCAL_FOLDER' to container '$CONTAINER_NAME'..."
for file in $(find "$LOCAL_FOLDER" -type f -name "*.pdf"); do
    # Generate a unique blob name by replacing directory separators with underscores
    BLOB_NAME=$(echo "$file" | sed "s|$LOCAL_FOLDER/||" | tr '/' '_')
    echo "Uploading '$file' as blob '$BLOB_NAME'..."
    az storage blob upload --account-name "$STORAGE_ACCOUNT_NAME" --container-name "$CONTAINER_NAME" --name "$BLOB_NAME" --auth-mode login --file "$file" --overwrite
    if [ $? -ne 0 ]; then
        echo "Failed to upload '$file'."
    else
        echo "Uploaded '$file' successfully."
    fi
done

echo "Upload process completed."