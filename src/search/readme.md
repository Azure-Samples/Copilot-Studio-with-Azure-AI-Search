# Azure AI Search Python Scripts

These scripts are designed to assist in creating and managing Azure AI Search components, including indexes, indexers, data sources, and skillsets (if required). They streamline the setup process, enabling efficient configuration and deployment of search capabilities.

## How to test the scripts locally

To test the scripts locally, follow these steps to create and activate a new virtual environment:

```bash
# Create a new virtual environment with Python 3.12
python -m venv copilot

# Activate the newly created environment
source copilot/bin/activate  # On Windows, use: copilot\Scripts\activate
```

Next, install the required dependencies (find requirements.txt in the src/search folder):

```bash
pip install -r requirements.txt
```

Log in to your Azure account to use your credentials in the code:

```bash
az login -t <your-tenant-id>
```

Finally, run the script using the following command:

```bash
# Modify the path according to your current folder
python -m src.search.index_utils --aisearch_name <ai_search_name> --base_index_name <base_index_name> --openai_api_base <open_ai_endpoint> --subscription_id <subscription_id> --resource_group_name <resource_group_name> --storage_name <storage_name> --container_name <container_name>
```

The `base_index_name` parameter simplifies the script configuration by reducing the number of required parameters. The script automatically generates names for the index, skillset, indexer, and data source by appending the suffixes `-index`, `-skills`, `-indexer`, and `-ds` to the provided base name.
