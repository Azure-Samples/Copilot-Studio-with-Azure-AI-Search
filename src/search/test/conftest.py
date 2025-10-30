# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

"""
Pytest configuration and fixtures for Azure AI Search E2E tests.
"""

import os
import pytest
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
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
        "--azure-client-id",
        action="store",
        default=None,
        help="Managed Identity client ID",
    )
    parser.addoption(
        "--aisearch-name",
        action="store",
        default=None,
        help="Azure AI Search service name",
    )
    parser.addoption(
        "--index-name", action="store", default=None, help="Search index name"
    )
    parser.addoption(
        "--datasource-name", action="store", default=None, help="Search datasource name"
    )
    parser.addoption(
        "--skillset-name", action="store", default=None, help="Search skillset name"
    )
    parser.addoption(
        "--indexer-name", action="store", default=None, help="Search indexer name"
    )


@pytest.fixture(scope="session")
def azure_credential(request):
    """
    Azure credential fixture that provides authentication for tests.

    Args:
        request: pytest request object to access command line options

    Returns:
        Azure credential object (ManagedIdentity or Default)
    """
    load_dotenv()

    # Get Azure Client ID from command line or environment variable
    azure_client_id = request.config.getoption("--azure-client-id") or os.environ.get(
        "AZURE_CLIENT_ID"
    )

    if azure_client_id:
        return ManagedIdentityCredential(client_id=azure_client_id)
    else:
        return DefaultAzureCredential()


@pytest.fixture(scope="session")
def ai_search_uri(request):
    """
    AI Search service URI fixture.

    Args:
        request: pytest request object to access command line options

    Returns:
        str: The AI Search service URI
    """
    # Get AI Search name from command line or environment variable
    aisearch_name = request.config.getoption("--aisearch-name") or os.environ.get(
        "AISEARCH_NAME"
    )

    if not aisearch_name:
        pytest.skip(
            "AI Search name not provided via --aisearch-name or AISEARCH_NAME environment variable"
        )

    return f"https://{aisearch_name}.search.windows.net"


@pytest.fixture(scope="session")
def search_tester(ai_search_uri, azure_credential):
    """
    SearchResourceTester fixture.

    Args:
        ai_search_uri: AI Search service URI
        azure_credential: Azure credential

    Returns:
        SearchResourceTester: Configured tester instance
    """
    return SearchResourceTester(ai_search_uri, azure_credential)


@pytest.fixture(scope="session")
def resource_names(request):
    """
    Resource names fixture that reads from command line arguments or environment variables.

    Args:
        request: pytest request object to access command line options

    Returns:
        dict: Dictionary containing resource names
    """
    names = {
        "index_name": (
            request.config.getoption("--index-name") or os.environ.get("INDEX_NAME")
        ),
        "datasource_name": (
            request.config.getoption("--datasource-name")
            or os.environ.get("DATASOURCE_NAME")
        ),
        "skillset_name": (
            request.config.getoption("--skillset-name")
            or os.environ.get("SKILLSET_NAME")
        ),
        "indexer_name": (
            request.config.getoption("--indexer-name") or os.environ.get("INDEXER_NAME")
        ),
    }

    # Validate that all required names are provided
    missing = [key for key, value in names.items() if not value]
    if missing:
        missing_vars = [f"--{key.replace('_', '-')}" for key in missing]
        pytest.skip(
            f"Missing required values. Provide via command line arguments {', '.join(missing_vars)} "
            f"or environment variables: {', '.join(missing)}"
        )

    return names


def pytest_configure(config):
    """
    Configure pytest with custom markers.
    """
    config.addinivalue_line("markers", "unit: mark test as a unit test")
    config.addinivalue_line("markers", "integration: mark test as an integration test")
    config.addinivalue_line("markers", "e2e: mark test as an end-to-end test")
    config.addinivalue_line(
        "markers", "search_resource: mark test as testing search resources"
    )


def pytest_collection_modifyitems(config, items):
    """
    Automatically mark tests based on their names and locations.
    """
    for item in items:
        # Mark all tests in this file as e2e and search_resource tests
        if "test_e2e_search_resources" in str(item.fspath):
            item.add_marker(pytest.mark.e2e)
            item.add_marker(pytest.mark.search_resource)
