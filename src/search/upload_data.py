"""
Upload data files from local directory to Azure Blob Storage.

By default, uploads all files in the specified directory. Use --file_pattern to filter specific file types.

Usage:
    python upload_data.py --storage_account_name <account> --container_name <container> --data_path <local_path>
    python upload_data.py --storage_account_name <account> --container_name <container> --data_path <local_path> --file_pattern "*.pdf,*.docx"
"""

import argparse
import fnmatch
import logging
import os
from pathlib import Path
from typing import List, Optional

from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
from azure.storage.blob import BlobServiceClient

logger = logging.getLogger(__name__)

# Setting the threshold of logger to DEBUG
logger.setLevel(logging.DEBUG)

# Create a console handler and set its level to DEBUG
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.DEBUG)

# Create a formatter and set it for the console handler
formatter = logging.Formatter(
    "%(asctime)s - %(name)s - %(levelname)s - %(message)s")
console_handler.setFormatter(formatter)

# Add the console handler to the logger
logger.addHandler(console_handler)

STORAGE_ACCOUNT_URL = "https://{storage_account_name}.blob.core.windows.net"


def matches_pattern(filename: str, file_patterns: List[str]) -> bool:
    """
    Check if filename matches any of the file patterns.
    
    Args:
        filename: Name of file to check
        file_patterns: List of file patterns to match (e.g., ['*.pdf', '*.docx'])
        
    Returns:
        True if file matches any pattern, False otherwise
    """
    for pattern in file_patterns:
        if fnmatch.fnmatch(filename.lower(), pattern.lower()):
            return True
    return False


def upload_data_files(
    credential: DefaultAzureCredential,
    storage_account_name: str,
    storage_container: str,
    local_folder: str,
    file_patterns: Optional[List[str]] = None,
):
    """
    Upload files from local folder to Azure Blob Storage.
    
    Args:
        credential: Azure credential for authentication
        storage_account_name: Name of the Azure Storage account
        storage_container: Name of the container to upload to
        local_folder: Local directory containing files to upload
        file_patterns: List of file patterns to match (default: ['*'] for all files)
    """
    if file_patterns is None:
        file_patterns = ['*']  # Default to all files
    
    logger.info(f"File patterns: {file_patterns}")
    
    account_url = STORAGE_ACCOUNT_URL.format(
        storage_account_name=storage_account_name)
    blob_service_client = BlobServiceClient(
        account_url=account_url, credential=credential
    )
    blob_container_client = blob_service_client.get_container_client(
        storage_container)

    if not blob_container_client.exists():
        logger.info(f"Creating {storage_container} container.")
        blob_container_client.create_container()
        logger.info("Done.")

    upload_count = 0
    for file in Path(local_folder).rglob("*"):
        if file.is_file() and matches_pattern(file.name, file_patterns):
            logger.info(f"Uploading {file} to {storage_container}.")

            # construct blob name from file path
            # everything rather than local_folder
            file_subpath = os.path.relpath(file, start=local_folder)

            # generate a unique name of the file
            file_name = file_subpath.replace(os.sep, "_")

            try:
                logger.info(f"Ready to copy: {str(file)} to {file_name}.")
                with open(file=str(file), mode="rb") as data:
                    blob_container_client.upload_blob(
                        name=file_name, data=data, overwrite=True
                    )
                logger.info("Done.")
                upload_count += 1
            except Exception as e:
                logger.error(f"Exception uploading file name {file_name}: {e}")
                raise
    
    logger.info(f"Successfully uploaded {upload_count} files matching patterns {file_patterns}.")


def main():
    """
    Upload files from local directory to Azure Blob Storage.
    
    This function reads the parameters from the command line, authenticates to Azure 
    using default credentials, and uploads files from a local directory 
    to a specified Azure Blob Storage container. File types can be filtered
    using the --file_pattern argument.
    """
    logger.info("Read and check parameters.")
    # Extract the configuration parameters from the command line arguments
    parser = argparse.ArgumentParser(description="Upload files to Azure Blob Storage")
    parser.add_argument(
        "--storage_account_name",
        required=True,
        help="Azure storage account name",
    )
    parser.add_argument(
        "--container_name",
        required=True,
        help="Azure storage container name",
    )
    parser.add_argument(
        "--data_path",
        required=True,
        help="Local folder path containing files to upload",
    )
    parser.add_argument(
        "--file_pattern",
        default="*",
        help="File patterns to match, comma-separated (e.g., '*.pdf,*.docx,*.txt'). Default: '*' (all files)",
    )
    # Add legacy support for old argument names (backward compatibility)
    parser.add_argument(
        "--storage_name",
        help="Azure storage account name (deprecated, use --storage_account_name)",
    )
    args = parser.parse_args()

    # Handle legacy argument names for backward compatibility
    storage_account_name = args.storage_account_name or args.storage_name
    if not storage_account_name:
        raise ValueError("storage_account_name is required")

    # Validate storage account name
    if not storage_account_name.islower() or not storage_account_name.isalnum():
        raise ValueError(
            "Storage account name must be a lowercase alphanumeric string (letters and digits)."
        )

    # Validate data path exists
    if not os.path.exists(args.data_path):
        raise ValueError(f"Data path does not exist: {args.data_path}")

    # Parse file patterns
    file_patterns = [pattern.strip() for pattern in args.file_pattern.split(',') if pattern.strip()]
    if not file_patterns:
        file_patterns = ['*']

    # Check if we're running in a managed identity environment
    azure_client_id = os.environ.get("AZURE_CLIENT_ID")

    if azure_client_id:
        logger.info(
            f"Using managed identity authentication with client ID: {azure_client_id}")
        credential = ManagedIdentityCredential(client_id=azure_client_id)
    else:
        logger.info(
            "Using default Azure credentials (fallback for local development).")
        credential = DefaultAzureCredential()

    # Upload the files
    logger.info(f"Uploading process has been started from local path: {args.data_path}")
    logger.info(f"File patterns: {file_patterns}")
    upload_data_files(
        credential=credential,
        storage_account_name=storage_account_name,
        storage_container=args.container_name,
        local_folder=args.data_path,
        file_patterns=file_patterns,
    )
    logger.info("Uploading process has been completed.")


# This block ensures that the script runs the main function only when executed directly,
# and not when imported as a module in another script.
if __name__ == "__main__":
    main()