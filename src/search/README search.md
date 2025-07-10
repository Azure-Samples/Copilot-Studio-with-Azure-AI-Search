# Azure AI Search Python Scripts

These scripts are designed to assist in creating and managing Azure AI Search components, including
indexes, indexers, data sources, and skillsets (if required). They streamline the setup process,
enabling efficient configuration and deployment of search capabilities.

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
python -m src.search.index_utils \
  --aisearch_name <ai_search_name> \
  --base_index_name <base_index_name> \
  --openai_api_base <open_ai_endpoint> \
  --subscription_id <subscription_id> \
  --resource_group_name <resource_group_name> \
  --storage_name <storage_name> \
  --container_name <container_name>
```

The `base_index_name` parameter simplifies the script configuration by reducing the number of required
parameters. The script automatically generates names for the index, skillset, indexer, and data source
by appending the suffixes `-index`, `-skills`, `-indexer`, and `-ds` to the provided base name.

## Testing

The `test/` directory contains pytest-based end-to-end tests for Azure AI Search resources. The tests
verify that Azure AI Search resources (index, indexer, datasource, skillset) exist and function correctly.

### 📈 CI/CD Integration

> **IMPORTANT NOTE:** This test can be invoked using the self-hosted runner Github Action workflow called
[`test-runner.yaml`](/.github/workflows/test-runner.yaml), but the use of private runners is required.

### 🏗️ Test Structure

The test files include:

- **`test_e2e_search_resources.py`** - Main test module with pytest test classes
- **`conftest.py`** - Pytest configuration and fixtures
- **`pytest.ini`** - Pytest configuration file
- **`requirements-test.txt`** - Test dependencies

### 🚀 Quick Start: Running Tests

#### Github Workflow on Private, Self-Hosted Github Runners

0. **Private Github Runner**: Ensure that a Github runner exists as a part of your `azd up` process.
1. **Unique Identifier**: Grab the 5 character string that Terraform process generated for your
  resource group.
2. **Kick Off Workflow**: Run `Test Search Service on Private Github Runner` from Github Actions.
  A modal appears that requires the 5 character string; paste the string into the input field labeled
  `Resource Group ID Tag (5 Characters)`. The other input fields have default values but can be changed.
3. **Wait for Results**: The workflow handles both the data upload - described in detail separately
  in [`data/readme.md`](/data/README.md) - and the tests for the search service itself.
4. **Check on Tests**: The workflow saves the pytest results as a workflow artifact and then renders
  the results in a human-consumable way on the workflow run itself.

#### "Locally" When Using a Deployment Script

0. **Logged in with Managed Identity**: Ensure the managed identity is signed in.
1. **Data on Storage Account**: Ensure that the data has been uploaded as recommended in the
  [`data/readme.md`](/data/README.md).
2. **Required Environment Variables**:

   ```bash
   export AISEARCH_NAME="your-search-service-name"
   export INDEX_NAME="your-index-name"
   export DATASOURCE_NAME="your-datasource-name"
   export SKILLSET_NAME="your-skillset-name"
   export INDEXER_NAME="your-indexer-name"
   ```

3. **Run the Tests**:

Since the tests also run as a part of CI/CD, the names of the resources are passed through arguments
when run on the command line.

```bash
# Install dependencies inside whichever virtual environment you're in
pip install -r requirements-test.txt

# Run all tests with JUnit XML output
pytest test_e2e_search_resources.py \
  --aisearch-name $AISEARCH_NAME \
  --index-name $INDEX_NAME \
  --datasource-name $DATASOURCE_NAME \
  --skillset-name $SKILLSET_NAME \
  --indexer-name $INDEXER_NAME \
  --junitxml=test-results.xml \
  --html=test-report.html \
  -v
```

### 📊 Test Output

The tests generate multiple output formats:

#### JUnit XML Report

- **File**: `test-results.xml`
- **Use**: CI/CD integration, build systems
- **Format**: Standard JUnit XML compatible with most CI systems

#### HTML Report

- **File**: `test-report.html`
- **Use**: Human-readable test results with detailed information
- **Features**: Self-contained HTML with screenshots and logs

### 🧪 Test Categories

#### Resource Existence Tests (`TestSearchResourcesExistence`)

- `test_index_exists()` - Verifies search index exists and has proper structure
- `test_datasource_exists()` - Verifies datasource exists and is configured
- `test_skillset_exists()` - Verifies skillset exists with skills
- `test_indexer_exists()` - Verifies indexer exists and references correct resources

#### Content Tests (`TestSearchIndexContent`)

- `test_index_has_content()` - Verifies index contains documents
- `test_wildcard_search_count()` - Tests document count with wildcard search
- `test_keyword_search_benefits()` - Tests keyword search functionality
- `test_nonexistent_keyword_search()` - Tests search for non-existent terms

#### Comprehensive Test

- `test_full_e2e_suite()` - Runs all validations in a single comprehensive test

### 🔧 Configuration

#### Environment Variables

| Variable | Description |
|----------|-------------|
| `AISEARCH_NAME` | Azure AI Search service name |
| `INDEX_NAME` | Search index name |
| `DATASOURCE_NAME` | Datasource name |
| `SKILLSET_NAME` | Skillset name |
| `INDEXER_NAME` | Indexer name |

#### Pytest Configuration

The `pytest.ini` file contains:

- JUnit XML output configuration
- HTML report settings
- Logging configuration
- Test markers definition
- Timeout settings
