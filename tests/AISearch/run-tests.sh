#!/bin/bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# Test runner script for AI Search integration tests
# This script sets up the environment and runs AI Search tests using deployed azd resources

set -e

echo "=== AI Search Integration Test Runner ==="
echo "This script runs AI Search tests against deployed azd resources"
echo

# Check if we're in the tests/AISearch directory and find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check if azure.yaml exists in the project root
if [ ! -f "$PROJECT_ROOT/azure.yaml" ]; then
    echo "ERROR: Cannot find azure.yaml in project root: $PROJECT_ROOT"
    echo "Please ensure you're running this script from a valid project structure"
    exit 1
fi

echo "Project root: $PROJECT_ROOT"
echo "Running from: $SCRIPT_DIR"

# Check if azd is available
if ! command -v azd &> /dev/null; then
    echo "ERROR: Azure Developer CLI (azd) is not installed or not in PATH"
    echo "Please install azd: https://docs.microsoft.com/azure/developer/azure-developer-cli/install-azd"
    exit 1
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed or not in PATH"
    exit 1
fi

# Get current azd environment
echo "Getting current azd environment..."
AZD_ENV_NAME=$(azd env list --output json | jq -r '.[] | select(.IsDefault == true) | .Name' 2>/dev/null || echo "")

if [ -z "$AZD_ENV_NAME" ]; then
    echo "WARNING: No default azd environment found"
    echo "Available environments:"
    azd env list --output table
    echo
    read -p "Enter environment name to use: " AZD_ENV_NAME
    if [ -z "$AZD_ENV_NAME" ]; then
        echo "ERROR: No environment name provided"
        exit 1
    fi
fi

echo "Using azd environment: $AZD_ENV_NAME"

# Select the environment (do this from project root)
cd "$PROJECT_ROOT"
azd env select "$AZD_ENV_NAME"

# Get AI Search configuration from azd outputs
echo "Getting AI Search configuration from azd outputs..."

# Get all azd environment values (handles shell format output)
AZD_ENV_VALUES=$(azd env get-values)

# Function to extract value from shell variable format: key="value"
extract_value() {
    local key=$1
    echo "$AZD_ENV_VALUES" | grep "^${key}=" | cut -d'"' -f2 2>/dev/null || echo ""
}

# Export environment variables for the tests
export AZURE_AI_SEARCH_ENDPOINT=$(extract_value "ai_search_endpoint")

# Get base name and construct resource names using standard naming pattern
AI_SEARCH_BASE_NAME=$(extract_value "ai_search_base_index_name")
AI_SEARCH_BASE_NAME="${AI_SEARCH_BASE_NAME:-default}"

# Export resource names using standard naming pattern
export AZURE_AI_SEARCH_INDEX_NAME="${AI_SEARCH_BASE_NAME}-index"
export AZURE_AI_SEARCH_DATASOURCE_NAME="${AI_SEARCH_BASE_NAME}-ds"
export AZURE_AI_SEARCH_SKILLSET_NAME="${AI_SEARCH_BASE_NAME}-skills"
export AZURE_AI_SEARCH_INDEXER_NAME="${AI_SEARCH_BASE_NAME}-indexer"
export AI_SEARCH_BASE_INDEX_NAME="$AI_SEARCH_BASE_NAME"

# Validate required configuration
if [ -z "$AZURE_AI_SEARCH_ENDPOINT" ]; then
    echo "ERROR: AI_SEARCH_ENDPOINT not found in azd outputs"
    echo "Make sure your azd environment is deployed with 'azd up'"
    exit 1
fi

echo "Configuration:"
echo "  Endpoint: $AZURE_AI_SEARCH_ENDPOINT"
echo "  Index: $AZURE_AI_SEARCH_INDEX_NAME"
echo "  Datasource: $AZURE_AI_SEARCH_DATASOURCE_NAME"
echo "  Skillset: $AZURE_AI_SEARCH_SKILLSET_NAME"
echo "  Indexer: $AZURE_AI_SEARCH_INDEXER_NAME"
echo

# Check if Azure CLI is logged in
echo "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    echo "ERROR: Not logged in to Azure CLI"
    echo "Please run: az login"
    exit 1
fi

AZURE_ACCOUNT=$(az account show --query "name" -o tsv)
echo "Authenticated as: $AZURE_ACCOUNT"
echo

# Change to test directory for the actual test execution
cd "$SCRIPT_DIR"

# Check if requirements file exists
if [ ! -f "requirements-test.txt" ]; then
    echo "ERROR: requirements-test.txt not found in $SCRIPT_DIR/"
    exit 1
fi

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install -r requirements-test.txt

# Run the tests
echo
echo "=== Running AI Search Integration Tests ==="
echo

# Run pytest with verbose output
python3 -m pytest -v \
    --tb=short \
    --durations=10 \
    .

TEST_EXIT_CODE=$?

echo
echo "=== Test Execution Complete ==="

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All AI Search integration tests passed!"
    echo "🎉 Your AI Search deployment is working correctly"
else
    echo "❌ Some AI Search integration tests failed"
    echo "🔍 Check the test output above for details"
    echo
    echo "Common issues:"
    echo "  - Resources not deployed: Run 'azd up' first"
    echo "  - Authentication issues: Check 'az login' status"
    echo "  - Resource not ready: Wait a few minutes after deployment"
    echo "  - Wrong environment: Check 'azd env list' and select correct one"
fi

exit $TEST_EXIT_CODE
