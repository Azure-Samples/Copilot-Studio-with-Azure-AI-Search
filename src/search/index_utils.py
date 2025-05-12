"""
This module contains functions to create index, indexer, and datasource.

This module is the primary endpoint for experiments with AI Search service
"""
import argparse
import os

from azure.identity import DefaultAzureCredential
from azure.search.documents.indexes import SearchIndexClient, SearchIndexerClient
from azure.search.documents.indexes.models import SearchIndex, SearchIndexerDataSourceConnection, SearchIndexer


APPLICATION_JSON_CONTENT_TYPE = "application/json"
AI_SEARCH_API_VERSION = "2024-07-01"
INDEX_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "index_config/documentIndex.json")
DATASOURCE_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "index_config/documentDataSource.json")
SKILLSET_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "index_config/documentSkillSet.json")
INDEXER_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "index_config/documentIndexer.json")


def create_or_update_indexer(
        indexer_name: str,
        index_name: str,
        skillset_name: str,
        datasource_name: str,
        indexer_file: str,
        ai_search_uri: str,
        credential: DefaultAzureCredential,
):
    """
    Create or update the indexer in the AI Search service.

    Args:
        indexer_name: The name of the indexer to create or update.
        index_name: The name of the index to create or update.
        skillset_name: The name of the skillset to use.
        datasource_name: The name of the data source to use.
        indexer_file: The path to the indexer definition file.
        ai_search_uri: The URI of the AI Search service.
        credential: The Azure credentials to use for authentication.

    Returns:
        None
    """
    # Create a search indexer client
    indexer_client = SearchIndexerClient(
        ai_search_uri, credential=credential, api_version=AI_SEARCH_API_VERSION
    )

    # read definition from the file and replace placeholders with actual values
    with open(indexer_file) as indexer_def:
        definition= indexer_def.read()
  
    definition = definition.replace("<search_indexer_name>", indexer_name)
    definition = definition.replace("<search_index_name>", index_name)
    definition = definition.replace("<skillset_name>", skillset_name)
    definition = definition.replace("<data_source_name>", datasource_name)

    # create an object of the indexer and initiate index creation process
    indexer = SearchIndexer.deserialize(definition, APPLICATION_JSON_CONTENT_TYPE)
    indexer_client.create_or_update_indexer(indexer=indexer)



def create_or_update_datasource(
        datasource_name: str,
        datasource_file: str,
        ai_search_uri: str,
        subscription_id: str,
        resource_group_name: str,
        storage_account_name: str,
        container_name: str,
        credential: DefaultAzureCredential,
):
    """
    Create or update the data source in the AI Search service.

    Args:
        datasource_name: The name of the data source to create or update.
        datasource_file: The path to the data source definition file.
        subscription_id: The Azure subscription ID.
        resource_group_name: The name of the Azure resource group.
        storage_account_name: The name of the Azure storage account.
        container_name: The name of the Azure storage container.
        ai_search_uri: The URI of the AI Search service.
        credential: The Azure credentials to use for authentication.

    Returns:
        None
    """
    # Create the connection string for the storage account applying Entra ID approach
    # The connection string is in the format: "ResourceId=/subscriptions/{subscription_id}/resourceGroups/{resource_group_name}/providers/Microsoft.Storage/storageAccounts/{storage_account_name};"
    conn_string = _get_storage_conn_string(
        subscription_id, storage_account_name, resource_group_name)

    # Create a search indexer client
    indexer_client = SearchIndexerClient(
        ai_search_uri, credential=credential, api_version=AI_SEARCH_API_VERSION
    )

    # read definition from the file and replace placeholders with actual values
    with open(datasource_file) as datasource_def:
        definition= datasource_def.read()
  
    definition = definition.replace("<connection_string>", conn_string)
    definition = definition.replace("<container_name>", container_name)
    definition = definition.replace("<data_source_name>", datasource_name)

    # create an object of the data source connection and initiate data source creation process
    data_source_connection = SearchIndexerDataSourceConnection.deserialize(
        definition, APPLICATION_JSON_CONTENT_TYPE
    )

    # Don't know why this is necessary, the connection string is in the credentials, it's not happy without it
    data_source_connection.connection_string = conn_string

    # Create or update the data source
    indexer_client.create_or_update_data_source_connection(data_source_connection)


def _get_storage_conn_string(
    subscription_id: str,
    storage_account_name: str,
    resource_group_name: str,
) -> str:
    conn_string = f"ResourceId=/subscriptions/{subscription_id}" \
        f"/resourceGroups/{resource_group_name}/providers/Microsoft.Storage" \
        f"/storageAccounts/{storage_account_name};"

    return conn_string


def create_or_update_index(
        index_name: str,
        index_file: str,
        ai_search_uri: str,
        open_ai_uri: str,
        credential: DefaultAzureCredential,
):
    """
    Create or update the index in the AI Search service.

    Args:
        index_name: The name of the index to create or update.
        ai_search_uri: The URI of the AI Search service.
        credential: The Azure credentials to use for authentication.

    Returns:
        None
    """
    index_client = SearchIndexClient(
        ai_search_uri, credential=credential, api_version=AI_SEARCH_API_VERSION
    )

    with open(index_file) as index_def:
        definition= index_def.read()
  
    # modify placeholders in the index definition
    definition = definition.replace("<search_index_name>", index_name)
    definition= definition.replace("<open_ai_uri>", open_ai_uri)

    # create an object of the index and initiate index creation process
    index = SearchIndex.deserialize(definition, APPLICATION_JSON_CONTENT_TYPE)
    index_client.create_or_update_index(index=index)



def main():
    """Create an indexer based on the configuration parameters and branch name."""

    # Extract the configuration parameters from the environment variables
    parser = argparse.ArgumentParser(description="Parameter parser")
    parser.add_argument(
        "--aisearch_name",
        required=True,
        help="name of the AI Search service",
    )
    parser.add_argument(
        "--index_name",
        required=True,
        help="name of the index to create or delete",
    )
    parser.add_argument(
        "--openai_api_base",
        required=True,
        help="base URL of the OpenAI API",
    )
    args = parser.parse_args()
    
    # Using default Azure credentials assuming that it has all needed permissions
    credential = DefaultAzureCredential()

    ai_search_uri = f"https://{args.aisearch_name}.search.windows.net"

    # Create the Index
    index_client = SearchIndexClient(
        ai_search_uri, credential=credential, api_version=AI_SEARCH_API_VERSION
    )

    # Create the full document index
    create_or_update_index(
        args.index_name,
        INDEX_SCHEMA_PATH,
        ai_search_uri,
        args.openai_api_base,
        credential,
    )


if __name__ == "__main__":
    main()
