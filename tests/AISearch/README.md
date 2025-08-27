# Azure AI Search End-to-End Tests

This directory contains end-to-end tests for Azure AI Search resources deployed via Azure Developer CLI (azd). These tests validate the existence, configuration, and functionality of search indexes, datasources, skillsets, and indexers.

## Overview

The tests are designed to work with **deployed** Azure AI Search resources rather than creating new ones. This makes them suitable for:

- Validating production deployments
- Continuous integration pipelines
- Post-deployment verification
- Regression testing

**Important:** These tests are **optional** and require manual configuration. They are disabled by default in the automated workflow.

## Prerequisites

Before running these tests, you must complete the following configuration:

### 1. Make AI Search Endpoint Public

The AI Search service must be accessible from the test runner. Configure network access in the Azure portal:

1. Navigate to your AI Search service
2. Go to **Networking** → **Firewalls and virtual networks**
3. Select one of the following options:
   - **All networks** (for testing purposes)
   - **Selected IP addresses** and add the test runner's IP address

### 2. Assign RBAC Role

The user or service principal running the tests must have the **Search Index Data Contributor** role:

1. Navigate to your AI Search service in the Azure portal
2. Go to **Access control (IAM)** → **Add role assignment**
3. Select **Search Index Data Contributor** role
4. Assign to the user or service principal that will execute the tests

**For local testing:** Assign the role to your Azure AD user account  
**For CI/CD pipelines:** Assign the role to the service principal used for authentication

## Test Structure

### Test Files

- `test_e2e_search_resources.py` - Main test file containing all test classes
- `conftest.py` - Pytest configuration and fixtures
- `pytest.ini` - Pytest configuration settings
- `requirements-test.txt` - Python dependencies for testing

### Test Classes

1. **TestSearchResourcesExistence** - Validates that all required resources exist
2. **TestSearchResourcesConfiguration** - Validates resource configurations
3. **TestSearchIndexContent** - Validates index content and search functionality
4. **TestSearchIndexerOperations** - Validates indexer operations
5. **TestSearchPipelineIntegration** - End-to-end pipeline validation

## Configuration

### Environment Variables

The tests read configuration from environment variables that are typically set by azd. The resource names are automatically discovered from the deployed Azure AI Search service rather than using hardcoded values:

```bash
# Required: AI Search service endpoint
AZURE_AI_SEARCH_ENDPOINT=https://your-search-service.search.windows.net

# Base name for AI Search resources (automatically suffixed to create resource names)
AI_SEARCH_BASE_INDEX_NAME=default
```

The tests automatically construct resource names using the standard naming pattern:
- Index: `{base_name}-index`
- Datasource: `{base_name}-ds` 
- Skillset: `{base_name}-skills`
- Indexer: `{base_name}-indexer`

The tests read configuration from environment variables that are typically set by azd:

```bash
# Required: AI Search service endpoint
AZURE_AI_SEARCH_ENDPOINT=https://your-search-service.search.windows.net

# Base name (used to construct all resource names)
AI_SEARCH_BASE_INDEX_NAME=documents

# The following are automatically calculated:
# AZURE_AI_SEARCH_INDEX_NAME=documents-index
# AZURE_AI_SEARCH_DATASOURCE_NAME=documents-ds
# AZURE_AI_SEARCH_SKILLSET_NAME=documents-skills
# AZURE_AI_SEARCH_INDEXER_NAME=documents-indexer
```

### Command Line Options

You can also provide configuration via command line arguments:

```bash
pytest --aisearch-endpoint=https://your-search-service.search.windows.net \
       --index-name=documents \
       --datasource-name=documents-datasource \
       --skillset-name=documents-skillset \
       --indexer-name=documents-indexer
```

## Authentication

The tests use Azure's DefaultAzureCredential chain, which supports:

1. Azure CLI authentication (recommended for local development)
2. Managed Identity (for Azure-hosted CI/CD)
3. Service Principal via environment variables
4. Interactive browser authentication

### Local Development

For local testing, ensure you're authenticated with Azure CLI:

```bash
az login
az account set --subscription "Your Subscription Name"
```

### CI/CD Pipelines

For automated pipelines, use either:

1. **Federated Identity** (recommended for GitHub Actions)
2. **Service Principal** with these environment variables:
   ```bash
   AZURE_CLIENT_ID=your-client-id
   AZURE_CLIENT_SECRET=your-client-secret
   AZURE_TENANT_ID=your-tenant-id
   ```

## Running Tests

### Prerequisites

1. Install Python dependencies:
   ```bash
   pip install -r requirements-test.txt
   ```

2. Ensure Azure AI Search resources are deployed via azd:
   ```bash
   azd up
   ```

3. Set environment variables or prepare command line arguments

### Basic Test Execution

Run all tests:
```bash
pytest
```

Run tests with verbose output:
```bash
pytest -v
```

Run only resource existence tests:
```bash
pytest -m search_resource
```

Run only content tests:
```bash
pytest -m search_content
```

### Test Markers

The tests use markers to categorize different types of tests:

- `e2e` - End-to-end tests
- `search_resource` - Resource existence/configuration tests
- `search_content` - Content and search functionality tests
- `slow` - Tests that may take longer to complete

Skip slow tests:
```bash
pytest -m "not slow"
```

### Parameterized Tests

Some tests are parameterized to run with different expected values:

- Document count tests run with minimum expected counts of 1, 5, and 10 documents

## Integration with AZD

These tests are designed to integrate with azd workflows:

### After Deployment

Run tests after `azd up` to validate the deployment:

```bash
# Deploy infrastructure and applications
azd up

# Run validation tests
cd tests/AISearch
pytest
```

### In CI/CD Pipelines

The tests can be integrated into GitHub Actions or other CI/CD systems:

```yaml
- name: Run AI Search Tests
  run: |
    cd tests/AISearch
    pip install -r requirements-test.txt
    pytest --junitxml=test-results.xml
  env:
    AZURE_AI_SEARCH_ENDPOINT: ${{ steps.get_outputs.outputs.AZURE_AI_SEARCH_ENDPOINT }}
```

## Test Results

### Success Criteria

Tests pass when:
- All required resources exist
- Resources have valid configurations
- Index contains expected minimum documents
- Search functionality works correctly
- Indexer operations complete successfully

### Common Issues

1. **Authentication Failures**
   - Ensure Azure CLI is logged in
   - Verify service principal credentials
   - Check subscription access

2. **Resource Not Found**
   - Verify azd deployment completed successfully
   - Check resource names match deployment
   - Ensure correct subscription/resource group

3. **Empty Index**
   - Run indexer manually if needed
   - Check datasource connectivity
   - Verify skillset configuration

## Customization

### Adding New Tests

To add new test cases:

1. Create test methods in appropriate test classes
2. Use existing fixtures for authentication and configuration
3. Add appropriate markers for categorization
4. Update documentation

### Modifying Expected Values

Update test parameters in the test file:

```python
@pytest.mark.parametrize("min_expected_documents", [1, 5, 10, 50])  # Add more values
```

### Custom Resource Names

Update the `resource_names` fixture in `conftest.py` to support additional naming patterns or sources.

## Troubleshooting

### Debug Mode

Run with debug logging:
```bash
pytest -v -s --log-cli-level=DEBUG
```

### Individual Test Execution

Run specific test classes:
```bash
pytest TestSearchResourcesExistence -v
```

Run specific test methods:
```bash
pytest test_index_exists -v
```

### Timeout Issues

For slow environments, increase timeout in `pytest.ini`:
```ini
timeout = 600  # 10 minutes
```

## Best Practices

1. **Run tests after deployment** - Always validate with `pytest` after `azd up`
2. **Use in CI/CD** - Integrate tests into your deployment pipeline
3. **Monitor regularly** - Run tests periodically to catch configuration drift
4. **Customize for your data** - Adjust expected document counts and field names
5. **Handle failures gracefully** - Tests are designed to provide clear error messages

## Related Documentation

- [Azure AI Search Documentation](https://docs.microsoft.com/azure/search/)
- [Azure Developer CLI](https://docs.microsoft.com/azure/developer/azure-developer-cli/)
- [Azure Identity Library](https://docs.microsoft.com/python/api/azure-identity/)
- [Pytest Documentation](https://docs.pytest.org/)
