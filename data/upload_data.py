"""
Initialize blob storage with local data.

We assume that this code will be executed just once to prepare a blob container for experiments.
"""
import argparse
import logging
import os
from pathlib import Path
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient


logger = logging.getLogger(__name__)

# Setting the threshold of logger to DEBUG
logger.setLevel(logging.DEBUG)

# Create a console handler and set its level to DEBUG
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.DEBUG)

# Create a formatter and set it for the console handler
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)

# Add the console handler to the logger
logger.addHandler(console_handler)

STORAGE_ACCOUNT_URL = "https://{storage_account_name}.blob.core.windows.net"


def upload_data_files(
    credential: DefaultAzureCredential,
    storage_account_name: str,
    storage_container: str,
    local_folder: str,
):

    account_url = STORAGE_ACCOUNT_URL.format(storage_account_name=storage_account_name)
    blob_service_client = BlobServiceClient(
        account_url=account_url, credential=credential
    )
    blob_container_client = blob_service_client.get_container_client(storage_container)

    if not blob_container_client.exists():
        logger.info(f"Creating {storage_container} container.")
        blob_container_client.create_container()
        logger.info("Done.")

    for file in Path(local_folder).rglob("*.pdf"):
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
        except Exception as e:
            logger.info(f"Exception uploading file name {file_name}: {e}")
            raise

def main():
    """
    Upload data files to Azure Blob Storage.
    This function reads the parameters from the command line, authenticates to Azure using default credentials,
    and uploads the files from a specified local folder to a specified Azure Blob Storage container.
    """
    logger.info("Read and check parameters.")
    # Extract the configuration parameters from the environment variables
    parser = argparse.ArgumentParser(description="Parameter parser")
    parser.add_argument(
        "--storage_name",
        required=True,
        help="Azure storage account name",
    )
    parser.add_argument(
        "--container_name",
        required=True,
        help="Azure storage container name",
    )
    args = parser.parse_args()

    # Validate storage account name
    if not args.storage_name.islower() or not args.storage_name.isalnum():
        raise ValueError("Storage account name must be a lowercase alphanumeric string (letters and digits).")

    # Using default Azure credentials assuming that it has all needed permissions
    logger.info("Authenticate code into Azure using default credentials.")
    credential = DefaultAzureCredential()


    # Create the full document index
    logger.info("Uploading process has been started.")
    upload_data_files(
        credential=credential,
        storage_account_name=args.storage_name,
        storage_container=args.container_name,
        local_folder=os.path.dirname(__file__),
    )
    logger.info("Uploading process has been completed.")


# This block ensures that the script runs the main function only when executed directly,
# and not when imported as a module in another script.
if __name__ == "__main__":
    main()