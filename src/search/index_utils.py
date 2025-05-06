"""
This module contains functions to create index, indexer, and datasource.

This module is the primary endpoint for experiments with AI Search service
"""
import argparse
import os

from azure.identity import DefaultAzureCredential
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import SearchIndex


APPLICATION_JSON_CONTENT_TYPE = "application/json"
AI_SEARCH_API_VERSION = "2024-07-01"
INDEX_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "index_config/documentIndex.json")


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
        defenition = index_def.read()
  
    # modify placeholders in the index definition
    defenition = defenition.replace("<search_index_name>", index_name)
    defenition = defenition.replace("<open_ai_uri>", open_ai_uri)

    # create an object of the index and initiate index creation process
    index = SearchIndex.deserialize(defenition, APPLICATION_JSON_CONTENT_TYPE)
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
