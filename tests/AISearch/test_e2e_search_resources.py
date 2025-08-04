"""
End-to-end tests for Azure AI Search resources.

This module contains tests that validate the existence and configuration
of Azure AI Search resources (indexes, datasources, skillsets, indexers)
deployed via Azure Developer CLI (azd).

The tests use deployed resources rather than creating new ones,
making them suitable for validating production deployments.
"""

import asyncio
import json
from typing import Dict, Any, List, Optional

import pytest
from azure.core.credentials import AzureKeyCredential
from azure.core.exceptions import ResourceNotFoundError
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient, SearchIndexerClient


class SearchResourceTester:
    """
    Helper class for testing Azure AI Search resources.
    
    This class provides methods to validate the existence and configuration
    of search indexes, datasources, skillsets, and indexers.
    """

    def __init__(self, search_endpoint: str, credential):
        """
        Initialize the SearchResourceTester.

        Args:
            search_endpoint (str): The Azure AI Search service endpoint
            credential: Azure credential for authentication
        """
        self.search_endpoint = search_endpoint
        self.credential = credential
        
        # Initialize clients
        self.index_client = SearchIndexClient(
            endpoint=search_endpoint,
            credential=credential
        )
        
        self.indexer_client = SearchIndexerClient(
            endpoint=search_endpoint,
            credential=credential
        )

    def get_search_client(self, index_name: str) -> SearchClient:
        """
        Get a SearchClient for a specific index.

        Args:
            index_name (str): Name of the search index

        Returns:
            SearchClient: Client for the specified index
        """
        return SearchClient(
            endpoint=self.search_endpoint,
            index_name=index_name,
            credential=self.credential
        )

    def index_exists(self, index_name: str) -> bool:
        """
        Check if a search index exists.

        Args:
            index_name (str): Name of the index to check

        Returns:
            bool: True if the index exists, False otherwise
        """
        try:
            self.index_client.get_index(index_name)
            return True
        except ResourceNotFoundError:
            return False
        except Exception as e:
            print(f"Error checking index existence: {e}")
            return False

    def datasource_exists(self, datasource_name: str) -> bool:
        """
        Check if a datasource exists.

        Args:
            datasource_name (str): Name of the datasource to check

        Returns:
            bool: True if the datasource exists, False otherwise
        """
        try:
            self.indexer_client.get_data_source_connection(datasource_name)
            return True
        except ResourceNotFoundError:
            return False
        except Exception as e:
            print(f"Error checking datasource existence: {e}")
            return False

    def skillset_exists(self, skillset_name: str) -> bool:
        """
        Check if a skillset exists.

        Args:
            skillset_name (str): Name of the skillset to check

        Returns:
            bool: True if the skillset exists, False otherwise
        """
        try:
            self.indexer_client.get_skillset(skillset_name)
            return True
        except ResourceNotFoundError:
            return False
        except Exception as e:
            print(f"Error checking skillset existence: {e}")
            return False

    def indexer_exists(self, indexer_name: str) -> bool:
        """
        Check if an indexer exists.

        Args:
            indexer_name (str): Name of the indexer to check

        Returns:
            bool: True if the indexer exists, False otherwise
        """
        try:
            self.indexer_client.get_indexer(indexer_name)
            return True
        except ResourceNotFoundError:
            return False
        except Exception as e:
            print(f"Error checking indexer existence: {e}")
            return False

    def get_index_document_count(self, index_name: str) -> int:
        """
        Get the number of documents in a search index.

        Args:
            index_name (str): Name of the index

        Returns:
            int: Number of documents in the index
        """
        try:
            search_client = self.get_search_client(index_name)
            
            # Use search with count=True to get document count
            results = search_client.search(
                search_text="*",
                include_total_count=True,
                top=0  # We only want the count, not the documents
            )
            
            return results.get_count() or 0
        except Exception as e:
            print(f"Error getting document count for index {index_name}: {e}")
            return 0

    def get_index_configuration(self, index_name: str) -> Optional[Dict[str, Any]]:
        """
        Get the configuration of a search index.

        Args:
            index_name (str): Name of the index

        Returns:
            Optional[Dict[str, Any]]: Index configuration or None if not found
        """
        try:
            index = self.index_client.get_index(index_name)
            return {
                "name": index.name,
                "fields": [{"name": f.name, "type": f.type, "searchable": f.searchable} for f in index.fields],
                "scoring_profiles": [sp.name for sp in (index.scoring_profiles or [])],
                "suggesters": [s.name for s in (index.suggesters or [])],
                "analyzers": [a.name for a in (index.analyzers or [])],
            }
        except Exception as e:
            print(f"Error getting index configuration for {index_name}: {e}")
            return None

    def get_datasource_configuration(self, datasource_name: str) -> Optional[Dict[str, Any]]:
        """
        Get the configuration of a datasource.

        Args:
            datasource_name (str): Name of the datasource

        Returns:
            Optional[Dict[str, Any]]: Datasource configuration or None if not found
        """
        try:
            datasource = self.indexer_client.get_data_source_connection(datasource_name)
            return {
                "name": datasource.name,
                "type": datasource.type,
                "container": getattr(datasource.container, 'name', None) if datasource.container else None,
                "description": datasource.description,
            }
        except Exception as e:
            print(f"Error getting datasource configuration for {datasource_name}: {e}")
            return None

    def get_skillset_configuration(self, skillset_name: str) -> Optional[Dict[str, Any]]:
        """
        Get the configuration of a skillset.

        Args:
            skillset_name (str): Name of the skillset

        Returns:
            Optional[Dict[str, Any]]: Skillset configuration or None if not found
        """
        try:
            skillset = self.indexer_client.get_skillset(skillset_name)
            return {
                "name": skillset.name,
                "skills": [{"name": getattr(s, 'name', 'Unknown'), "type": type(s).__name__} for s in (skillset.skills or [])],
                "description": skillset.description,
            }
        except Exception as e:
            print(f"Error getting skillset configuration for {skillset_name}: {e}")
            return None

    def get_indexer_configuration(self, indexer_name: str) -> Optional[Dict[str, Any]]:
        """
        Get the configuration of an indexer.

        Args:
            indexer_name (str): Name of the indexer

        Returns:
            Optional[Dict[str, Any]]: Indexer configuration or None if not found
        """
        try:
            indexer = self.indexer_client.get_indexer(indexer_name)
            return {
                "name": indexer.name,
                "data_source_name": indexer.data_source_name,
                "target_index_name": indexer.target_index_name,
                "skillset_name": indexer.skillset_name,
                "description": indexer.description,
                "is_disabled": indexer.is_disabled,
            }
        except Exception as e:
            print(f"Error getting indexer configuration for {indexer_name}: {e}")
            return None

    def run_indexer(self, indexer_name: str) -> bool:
        """
        Run an indexer and wait for completion.

        Args:
            indexer_name (str): Name of the indexer to run

        Returns:
            bool: True if indexer ran successfully, False otherwise
        """
        try:
            self.indexer_client.run_indexer(indexer_name)
            print(f"Started indexer: {indexer_name}")
            
            # Wait for indexer to complete (simple polling)
            max_wait_time = 300  # 5 minutes
            wait_interval = 10  # 10 seconds
            waited_time = 0
            
            while waited_time < max_wait_time:
                status = self.indexer_client.get_indexer_status(indexer_name)
                if status.last_result and status.last_result.status in ["success", "transientFailure", "persistentFailure"]:
                    success = status.last_result.status == "success"
                    if success:
                        print(f"Indexer {indexer_name} completed successfully")
                    else:
                        print(f"Indexer {indexer_name} failed with status: {status.last_result.status}")
                        if hasattr(status.last_result, 'error_message'):
                            print(f"Error: {status.last_result.error_message}")
                    return success
                
                import time
                time.sleep(wait_interval)
                waited_time += wait_interval
                print(f"Waiting for indexer {indexer_name} to complete... ({waited_time}s)")
            
            print(f"Indexer {indexer_name} did not complete within {max_wait_time} seconds")
            return False
            
        except Exception as e:
            print(f"Error running indexer {indexer_name}: {e}")
            return False


class TestSearchResourcesExistence:
    """
    Test class for validating the existence of Azure AI Search resources.
    """

    @pytest.mark.asyncio
    async def test_index_exists(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test that the search index exists.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        index_name = resource_names["index_name"]
        exists = search_tester.index_exists(index_name)
        assert exists, f"Search index '{index_name}' does not exist"

    @pytest.mark.asyncio
    async def test_datasource_exists(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test that the datasource exists.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        datasource_name = resource_names["datasource_name"]
        exists = search_tester.datasource_exists(datasource_name)
        assert exists, f"Datasource '{datasource_name}' does not exist"

    @pytest.mark.asyncio
    async def test_skillset_exists(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test that the skillset exists.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        skillset_name = resource_names["skillset_name"]
        exists = search_tester.skillset_exists(skillset_name)
        assert exists, f"Skillset '{skillset_name}' does not exist"

    @pytest.mark.asyncio
    async def test_indexer_exists(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test that the indexer exists.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        indexer_name = resource_names["indexer_name"]
        exists = search_tester.indexer_exists(indexer_name)
        assert exists, f"Indexer '{indexer_name}' does not exist"


class TestSearchResourcesConfiguration:
    """
    Test class for validating the configuration of Azure AI Search resources.
    """

    @pytest.mark.asyncio
    async def test_index_configuration(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test the search index configuration.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        index_name = resource_names["index_name"]
        config = search_tester.get_index_configuration(index_name)
        
        assert config is not None, f"Could not retrieve configuration for index '{index_name}'"
        assert config["name"] == index_name
        assert len(config["fields"]) > 0, "Index should have at least one field"
        
        # Check for required fields based on typical document index structure
        field_names = [field["name"] for field in config["fields"]]
        expected_fields = ["chunk_id", "chunk", "title"]  # Common fields in chunk-based indexes
        
        # Check that at least some expected fields exist (not all may be present)
        found_fields = [field for field in expected_fields if field in field_names]
        assert len(found_fields) > 0, f"Index should contain at least one of these fields: {expected_fields}. Found: {field_names}"

    @pytest.mark.asyncio
    async def test_datasource_configuration(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test the datasource configuration.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        datasource_name = resource_names["datasource_name"]
        config = search_tester.get_datasource_configuration(datasource_name)
        
        assert config is not None, f"Could not retrieve configuration for datasource '{datasource_name}'"
        assert config["name"] == datasource_name
        assert config["type"] is not None, "Datasource should have a type"

    @pytest.mark.asyncio
    async def test_skillset_configuration(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test the skillset configuration.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        skillset_name = resource_names["skillset_name"]
        config = search_tester.get_skillset_configuration(skillset_name)
        
        assert config is not None, f"Could not retrieve configuration for skillset '{skillset_name}'"
        assert config["name"] == skillset_name
        # Skillsets can be empty, so we don't require skills

    @pytest.mark.asyncio
    async def test_indexer_configuration(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test the indexer configuration.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        indexer_name = resource_names["indexer_name"]
        config = search_tester.get_indexer_configuration(indexer_name)
        
        assert config is not None, f"Could not retrieve configuration for indexer '{indexer_name}'"
        assert config["name"] == indexer_name
        assert config["data_source_name"] is not None, "Indexer should have a data source"
        assert config["target_index_name"] is not None, "Indexer should have a target index"


class TestSearchIndexContent:
    """
    Test class for validating the content of search indexes.
    """

    @pytest.mark.parametrize("min_expected_documents", [1, 5, 10])
    @pytest.mark.asyncio
    async def test_index_has_documents(
        self, 
        search_tester: SearchResourceTester, 
        resource_names: Dict[str, str], 
        min_expected_documents: int
    ):
        """
        Test that the search index contains the expected minimum number of documents.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
            min_expected_documents: Minimum number of documents expected
        """
        index_name = resource_names["index_name"]
        document_count = search_tester.get_index_document_count(index_name)
        
        assert document_count >= min_expected_documents, (
            f"Index '{index_name}' contains {document_count} documents, "
            f"but expected at least {min_expected_documents}"
        )

    @pytest.mark.asyncio
    async def test_index_search_functionality(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test basic search functionality against the index.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        index_name = resource_names["index_name"]
        search_client = search_tester.get_search_client(index_name)
        
        # Perform a simple search
        try:
            results = search_client.search(search_text="*", top=5)
            result_list = list(results)
            
            # Verify we can retrieve results
            assert len(result_list) >= 0, "Search should return results or empty list without errors"
            
            # If there are results, verify they have expected structure
            if result_list:
                first_result = result_list[0]
                assert isinstance(first_result, dict), "Search results should be dictionaries"
                assert "@search.score" in first_result, "Search results should include search score"
                
        except Exception as e:
            pytest.fail(f"Search functionality test failed: {e}")


class TestSearchIndexerOperations:
    """
    Test class for validating indexer operations.
    """

    @pytest.mark.asyncio
    async def test_indexer_can_run(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test that the indexer can be run successfully.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        indexer_name = resource_names["indexer_name"]
        
        # Note: This test actually runs the indexer, which may take time
        # Consider skipping this test in CI environments or making it optional
        success = search_tester.run_indexer(indexer_name)
        
        assert success, f"Indexer '{indexer_name}' failed to run successfully"

    @pytest.mark.asyncio
    async def test_indexer_status(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test that indexer status can be retrieved.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        indexer_name = resource_names["indexer_name"]
        
        try:
            status = search_tester.indexer_client.get_indexer_status(indexer_name)
            assert status is not None, f"Could not retrieve status for indexer '{indexer_name}'"
            assert hasattr(status, 'status'), "Indexer status should have a status attribute"
            
        except Exception as e:
            pytest.fail(f"Failed to get indexer status: {e}")


# Integration test that validates the entire search pipeline
class TestSearchPipelineIntegration:
    """
    Integration tests for the complete search pipeline.
    """

    @pytest.mark.asyncio
    async def test_complete_search_pipeline(self, search_tester: SearchResourceTester, resource_names: Dict[str, str]):
        """
        Test the complete search pipeline from datasource to searchable content.

        Args:
            search_tester: SearchResourceTester fixture
            resource_names: Resource names fixture
        """
        # Verify all components exist
        index_name = resource_names["index_name"]
        datasource_name = resource_names["datasource_name"]
        skillset_name = resource_names["skillset_name"]
        indexer_name = resource_names["indexer_name"]
        
        # Check existence of all components
        assert search_tester.index_exists(index_name), f"Index '{index_name}' does not exist"
        assert search_tester.datasource_exists(datasource_name), f"Datasource '{datasource_name}' does not exist"
        assert search_tester.skillset_exists(skillset_name), f"Skillset '{skillset_name}' does not exist"
        assert search_tester.indexer_exists(indexer_name), f"Indexer '{indexer_name}' does not exist"
        
        # Verify indexer configuration links components correctly
        indexer_config = search_tester.get_indexer_configuration(indexer_name)
        assert indexer_config is not None, "Could not retrieve indexer configuration"
        assert indexer_config["data_source_name"] == datasource_name, "Indexer should reference the correct datasource"
        assert indexer_config["target_index_name"] == index_name, "Indexer should target the correct index"
        assert indexer_config["skillset_name"] == skillset_name, "Indexer should use the correct skillset"
        
        # Verify the index has content
        document_count = search_tester.get_index_document_count(index_name)
        assert document_count > 0, f"Index '{index_name}' should contain documents after indexing"
        
        # Verify search functionality works
        search_client = search_tester.get_search_client(index_name)
        results = search_client.search(search_text="*", top=1)
        result_list = list(results)
        
        assert len(result_list) > 0, "Search should return at least one result"
        
        print(f"\\nSearch pipeline validation successful:")
        print(f"  - Index: {index_name} ({document_count} documents)")
        print(f"  - Datasource: {datasource_name}")
        print(f"  - Skillset: {skillset_name}")
        print(f"  - Indexer: {indexer_name}")
        print(f"  - Search functionality: Working")
