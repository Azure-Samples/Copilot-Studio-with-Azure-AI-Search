# Required data

Initial data to upload into a blob storage to make this template working are located in this folder in pdf format.

To upload initial data into the blob storage you can pick one of the options from below.

_Note: By default, this solution deploys all Azure resources to a VNet. To successfully execute any of the commands outlined in this README, they must be run from within the network._

## How to upload data into the storage using the Python script

To execute the upload_data.py script, ensure you have Python 3.8+ installed and the required dependencies (azure-identity and azure-storage-blob) by running `pip install azure-identity azure-storage-blob`. Authenticate to Azure using `az login` or environment variables for service principal credentials.

Run the script from the terminal with the following command:

python -m upload_data --storage_name <your_storage_account_name> --container_name <your_container_name>

Replace <your_storage_account_name> and <your_container_name> with your Azure Storage account and container names. The script uploads all .pdf files from its directory to the specified container, creating the container if it doesn't exist. Ensure the storage account name is lowercase and contains only letters. Logs will confirm the upload process.

## How to upload data using the Linux Shell Script

Authenticate to Azure using `az login` or environment variables for service principal credentials. Execute the script:

```bash
./upload_data.sh <storage_account_name> <container_name>
```

Replace <storage_account_name> and <container_name> with your Azure Storage account and container names.

## How to upload data using the PowerShell Script

Authenticate to Azure using `az login` or environment variables for service principal credentials. Execute the PowerShell script:

```bash
./upload_data.ps1 -StorageAccountName <storage_account_name> -ContainerName <container_name>
```

Replace <storage_account_name> and <container_name> with your Azure Storage account and container names.
