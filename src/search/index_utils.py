"""
Utilities for managing AI Search service components.

This module contains functions to create or update an index, indexer, skillset, and datasource.
It serves as the primary endpoint for experiments with the AI Search service.
"""
import argparse
import os
import logging
from azure.identity import DefaultAzureCredential
from azure.search.documents.indexes import SearchIndexClient, SearchIndexerClient
from azure.search.documents.indexes.models import SearchIndex, SearchIndexerDataSourceConnection, SearchIndexer, SearchIndexerSkillset

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

APPLICATION_JSON_CONTENT_TYPE = "application/json"
AI_SEARCH_API_VERSION = "2024-07-01"
INDEX_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "index_config/documentIndex.json")
DATASOURCE_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "index_config/documentDataSource.json")
SKILLSET_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "index_config/documentSkillSet.json")
INDEXER_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "index_config/documentIndexer.json")


def create_or_update_skillset(
        skillset_name: str,
        index_name: str,
        skillset_file: str,
        ai_search_uri: str,
        credentials: DefaultAzureCredential,
):    
    """
    Create or update the skillset in the AI Search service.

    Args:
        skillset_name: The name of the skillset to create or update.
        index_name: The name of the index to use in the skillset.
        skillset_file: The path to the skillset definition file.
        ai_search_uri: The URI of the AI Search service.
        credentials: The Azure credentials to use for authentication.

    Returns:
        None
    """
    try:
        # Create a search indexer client
        indexer_client = SearchIndexerClient(
            ai_search_uri, credential=credentials, api_version=AI_SEARCH_API_VERSION
        )

        # read definition from the file and replace placeholders with actual values
        with open(skillset_file) as skillset_def:
            definition = skillset_def.read()

        definition = definition.replace("<search_index_name>", index_name)
        definition = definition.replace("<skillset_name>", skillset_name)

        # create an object of the skillset and initiate index creation process
        indexer = SearchIndexerSkillset.deserialize(definition, APPLICATION_JSON_CONTENT_TYPE)
        indexer_client.create_or_update_skillset(indexer=indexer)
    except Exception as e:
        logger.error(f"Failed to create or update the skillset '{skillset_name}': {e}")
        raise


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
        index_name: The name of the index to use in the indexer.
        skillset_name: The name of the skillset to use in the indexer.
        datasource_name: The name of the data source to use in the indexer.
        indexer_file: The path to the indexer definition file.
        ai_search_uri: The URI of the AI Search service.
        credential: The Azure credentials to use for authentication.

    Returns:
        None
    """
    # Create a search indexer client
    try:
        indexer_client = SearchIndexerClient(
            ai_search_uri, credential=credential, api_version=AI_SEARCH_API_VERSION
        )

        # read definition from the file and replace placeholders with actual values
        with open(indexer_file) as indexer_def:
            definition = indexer_def.read()

        definition = definition.replace("<search_indexer_name>", indexer_name)
        definition = definition.replace("<search_index_name>", index_name)
        definition = definition.replace("<skillset_name>", skillset_name)
        definition = definition.replace("<data_source_name>", datasource_name)

        # create an object of the indexer and initiate index creation process
        indexer = SearchIndexer.deserialize(definition, APPLICATION_JSON_CONTENT_TYPE)
        indexer_client.create_or_update_indexer(indexer=indexer)
    except Exception as e:
        logger.error(f"Failed to create or update the indexer '{indexer_name}': {e}")
        raise


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
    try:
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
            definition = datasource_def.read()

        definition = definition.replace("<connection_string>", conn_string)
        definition = definition.replace("<container_name>", container_name)
        definition = definition.replace("<data_source_name>", datasource_name)

        # create an object of the data source connection and initiate data source creation process
        data_source_connection = SearchIndexerDataSourceConnection.deserialize(
            definition, APPLICATION_JSON_CONTENT_TYPE
        )

        # Explicitly setting the connection string as it is required by the SearchIndexerDataSourceConnection object 
        # to properly establish the connection, even though credentials are provided.
        data_source_connection.connection_string = conn_string

        # Create or update the data source
        indexer_client.create_or_update_data_source_connection(data_source_connection)
    except Exception as e:
        logger.error(f"Failed to create or update the data source '{datasource_name}': {e}")
        raise


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
    try:
        index_client = SearchIndexClient(
            ai_search_uri, credential=credential, api_version=AI_SEARCH_API_VERSION
        )

        with open(index_file) as index_def:
            definition = index_def.read()

        # modify placeholders in the index definition
        definition = definition.replace("<search_index_name>", index_name)
        definition = definition.replace("<open_ai_uri>", open_ai_uri)

        # create an object of the index and initiate index creation process
        index = SearchIndex.deserialize(definition, APPLICATION_JSON_CONTENT_TYPE)
        index_client.create_or_update_index(index=index)
    except Exception as e:
        logger.error(f"Failed to create or update the index '{index_name}': {e}")
        raise


def main():
    """
    Create an indexer and related entities based on the configuration parameters.

    This function serves as the entry point for the script. It reads configuration parameters 
    from command-line arguments, authenticates with Azure using default credentials, and 
    orchestrates the creation or update of the following AI Search service components:
    
    - Search Index: Defines the structure of the searchable content.
    - Data Source: Specifies the source of the data to be indexed.
    - Skillset: Defines the AI enrichment pipeline for the data.
    - Indexer: Manages the process of pulling data from the data source, applying the skillset, 
      and populating the search index.

    The function expects the following command-line arguments:
    - --aisearch_name: The name of the AI Search service.
    - --base_index_name: The base name used to generate names for the index, data source, skillset, and indexer.
    - --openai_api_base: The base URL of the OpenAI API.
    - --subscription_id: The Azure subscription ID.
    - --resource_group_name: The name of the Azure resource group.
    - --storage_name: The name of the Azure storage account.
    - --container_name: The name of the Azure storage container.

    The function uses these parameters to construct the necessary components and logs the progress 
    of each operation.
    """
    logger.info("Read and check parameters.")
    # Extract the configuration parameters from the environment variables
    parser = argparse.ArgumentParser(description="Parameter parser")
    parser.add_argument(
        "--aisearch_name",
        required=True,
        help="name of the AI Search service",
    )
    parser.add_argument(
        "--base_index_name",
        required=True,
        help="base name to form the index, data source, skillset and indexer names",
    )
    parser.add_argument(
        "--openai_api_base",
        required=True,
        help="base URL of the OpenAI API",
    )
    parser.add_argument(
        "--subscription_id",
        required=True,
        help="Azure subscription ID",
    )
    parser.add_argument(
        "--resource_group_name",
        required=True,
        help="Azure resource group name",
    )
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

    # Using default Azure credentials assuming that it has all needed permissions
    logger.info("Authenticate code into Azure using default credentials.")
    credential = DefaultAzureCredential()

    ai_search_uri = f"https://{args.aisearch_name}.search.windows.net"

    # forming entity names based on the base name
    index_name = f"{args.base_index_name}-index"
    datasource_name = f"{args.base_index_name}-ds"
    skillset_name = f"{args.base_index_name}-skills"
    indexer_name = f"{args.base_index_name}-indexer"

    # Create the full document index
    logger.info("Initiate index creation method.")
    create_or_update_index(
        index_name,
        INDEX_SCHEMA_PATH,
        ai_search_uri,
        args.openai_api_base,
        credential,
    )
    logger.info("Index creation completed.")

    logger.info("Initiate data source creation method.")
    create_or_update_datasource(
        datasource_name,
        DATASOURCE_SCHEMA_PATH,
        ai_search_uri,
        args.subscription_id,
        args.resource_group_name,
        args.storage_name,
        args.container_name,
        credential,
    )
    logger.info("Data source creation completed.")


# This block ensures that the script runs the main function only when executed directly,
# and not when imported as a module in another script.
if __name__ == "__main__":
    main()
