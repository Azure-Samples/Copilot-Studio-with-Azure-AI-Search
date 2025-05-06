# Azure AI Search Python Scripts

These scripts are designed to assist in creating and managing Azure AI Search components, including indexes, indexers, data sources, and skillsets (if required). They streamline the setup process, enabling efficient configuration and deployment of search capabilities.

## How to test the scripts locally

To test the scripts locally, follow these steps to create and activate a new Conda environment:

```bash
# Create a new Conda environment with Python 3.12
conda create -n copilot python=3.12

# Activate the newly created environment
conda activate copilot
```

Next, install the required dependencies (find requirements.txt in the src folder):

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
python -m search.index_utils --aisearch_name <ai_search_name> --index_name <index_name> --openai_api_base <open_ai_endpoint>
```
