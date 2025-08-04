"""
Pytest configuration and fixtures for Azure AI Search E2E tests.

This module provides fixtures for testing Azure AI Search resources
using endpoints and configuration from the deployed AZD environment.
"""

import os
import pytest
import json
from azure.identity import DefaultAzureCredential, AzureCliCredential
from test_e2e_search_resources import SearchResourceTester

try:
    from dotenv import load_dotenv
except ImportError:
    def load_dotenv():
        return None


def pytest_addoption(parser):
    """
    Add command line options for pytest.
    """
    parser.addoption(
        "--aisearch-endpoint",
        action="store",
        default=None,
        help="Azure AI Search service endpoint URL",
    )
    parser.addoption(
        "--index-name", 
        action="store", 
        default=None, 
        help="Search index name"
    )
    parser.addoption(
        "--datasource-name", 
        action="store", 
        default=None, 
        help="Search datasource name"
    )
    parser.addoption(
        "--skillset-name", 
        action="store", 
        default=None, 
        help="Search skillset name"
    )
    parser.addoption(
        "--indexer-name", 
        action="store", 
        default=None, 
        help="Search indexer name"
    )


@pytest.fixture(scope="session")
def azure_credential():
    """
    Azure credential fixture that provides authentication for tests.
    
    Uses DefaultAzureCredential which supports multiple authentication methods:
    - Environment variables (service principal)
    - Managed identity
    - Azure CLI
    - Interactive browser
    
    Returns:
        Azure credential object
    """
    load_dotenv()
    
    # Try Azure CLI credential first (common in CI/CD with federated identity)
    try:
        return AzureCliCredential()
    except Exception:
        # Fall back to DefaultAzureCredential
        return DefaultAzureCredential()


@pytest.fixture(scope="session")
def ai_search_endpoint(request):
    """
    AI Search service endpoint fixture.
    
    Gets the endpoint from:
    1. Command line argument --aisearch-endpoint
    2. Environment variable AZURE_AI_SEARCH_ENDPOINT
    3. Environment variable AISEARCH_ENDPOINT (backward compatibility)
    
    Args:
        request: pytest request object to access command line options
    
    Returns:
        str: The AI Search service endpoint URL
    """
    # Get AI Search endpoint from multiple sources
    endpoint = (
        request.config.getoption("--aisearch-endpoint") or
        os.environ.get("AZURE_AI_SEARCH_ENDPOINT") or
        os.environ.get("AISEARCH_ENDPOINT")
    )
    
    if not endpoint:
        pytest.skip(
            "AI Search endpoint not provided. Set via --aisearch-endpoint argument "
            "or AZURE_AI_SEARCH_ENDPOINT environment variable"
        )
    
    # Ensure endpoint has proper format
    if not endpoint.startswith("https://"):
        endpoint = f"https://{endpoint}"
    if not endpoint.endswith(".search.windows.net"):
        if "." not in endpoint.replace("https://", ""):
            endpoint = f"{endpoint}.search.windows.net"
    
    return endpoint


@pytest.fixture(scope="session")
def search_tester(ai_search_endpoint, azure_credential):
    """
    SearchResourceTester fixture.
    
    Args:
        ai_search_endpoint: AI Search service endpoint URL
        azure_credential: Azure credential
    
    Returns:
        SearchResourceTester: Configured tester instance
    """
    return SearchResourceTester(ai_search_endpoint, azure_credential)


@pytest.fixture(scope="session")
def resource_names(request):
    """
    Resource names fixture that reads from command line arguments or environment variables.
    
    Gets resource names from AZD environment outputs or explicit configuration.
    
    Args:
        request: pytest request object to access command line options
    
    Returns:
        dict: Dictionary containing resource names
    """
    # Helper function to get the first non-null value
    def get_first_non_null(*values):
        """
        Helper function to get the first non-null value from a list of values.
        Used to handle cases where environment variables might be null or empty.
        
        Args:
            *values: Variable number of values to check
            
        Returns:
            The first non-null, non-empty value, or None if all are null/empty
        """
        for value in values:
            if value and value.strip():
                return value.strip()
        return None
    
    names = {
        "index_name": get_first_non_null(
            request.config.getoption("--index-name"),
            os.environ.get("AZURE_AI_SEARCH_INDEX_NAME"),
            os.environ.get("AI_SEARCH_INDEX_NAME"),
            os.environ.get("INDEX_NAME"),
            f"{os.environ.get('AI_SEARCH_BASE_INDEX_NAME', 'default')}-index"  # fallback
        ),
        "datasource_name": get_first_non_null(
            request.config.getoption("--datasource-name"),
            os.environ.get("AZURE_AI_SEARCH_DATASOURCE_NAME"),
            os.environ.get("AI_SEARCH_DATASOURCE_NAME"),
            os.environ.get("DATASOURCE_NAME"),
            f"{os.environ.get('AI_SEARCH_BASE_INDEX_NAME', 'default')}-ds"  # fallback
        ),
        "skillset_name": get_first_non_null(
            request.config.getoption("--skillset-name"),
            os.environ.get("AZURE_AI_SEARCH_SKILLSET_NAME"),
            os.environ.get("AI_SEARCH_SKILLSET_NAME"),
            os.environ.get("SKILLSET_NAME"),
            f"{os.environ.get('AI_SEARCH_BASE_INDEX_NAME', 'default')}-skills"  # fallback
        ),
        "indexer_name": get_first_non_null(
            request.config.getoption("--indexer-name"),
            os.environ.get("AZURE_AI_SEARCH_INDEXER_NAME"),
            os.environ.get("AI_SEARCH_INDEXER_NAME"),
            os.environ.get("INDEXER_NAME"),
            f"{os.environ.get('AI_SEARCH_BASE_INDEX_NAME', 'default')}-indexer"  # fallback
        ),
    }
    
    # Validate that we have all required names
    missing_names = [key for key, value in names.items() if not value]
    if missing_names:
        pytest.skip(
            f"Missing required resource names: {missing_names}. "
            "Ensure azd deployment is complete and outputs are available, "
            "or provide names via command line arguments or environment variables."
        )
    
    # Log the resource names being used
    print(f"\\nUsing AI Search resource names:")
    for key, value in names.items():
        print(f"  {key}: {value}")
    
    return names


def pytest_configure(config):
    """
    Configure pytest with custom markers.
    """
    config.addinivalue_line("markers", "unit: mark test as a unit test")
    config.addinivalue_line("markers", "integration: mark test as an integration test")
    config.addinivalue_line("markers", "e2e: mark test as an end-to-end test")
    config.addinivalue_line("markers", "search_resource: mark test as testing search resources")
    config.addinivalue_line("markers", "search_content: mark test as testing search content")


def pytest_collection_modifyitems(config, items):
    """
    Automatically mark tests based on their names and locations.
    """
    for item in items:
        # Mark all tests in this directory as e2e tests
        if "test_e2e_search_resources" in str(item.fspath):
            item.add_marker(pytest.mark.e2e)
            
            # Mark resource existence tests
            if "TestSearchResourcesExistence" in str(item.cls):
                item.add_marker(pytest.mark.search_resource)
            
            # Mark content tests  
            if "TestSearchIndexContent" in str(item.cls):
                item.add_marker(pytest.mark.search_content)
