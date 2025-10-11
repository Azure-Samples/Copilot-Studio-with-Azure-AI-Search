set -euo pipefail

echo "=== Search Index Configuration Script Start ==="
echo "Storage account: $MAIN_STORAGE_ACCOUNT_NAME"
echo "Search service: $SEARCH_SERVICE_NAME"
echo "Repository URL: $GITHUB_REPO_URL"

# Wait for RBAC permissions to fully propagate (Azure can take time to propagate permissions)
echo "=== Waiting for RBAC permissions to propagate ==="
sleep 30

# Verify main storage account exists
az storage account show --name $MAIN_STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP_NAME --output table

# Setup Python environment
python3 -m venv /tmp/venv && source /tmp/venv/bin/activate
pip install --upgrade pip

# Download only the necessary scripts
mkdir -p /tmp/scripts && cd /tmp/scripts
az storage blob download-batch --destination . --source scripts --account-name $SCRIPT_STORAGE_ACCOUNT_NAME --auth-mode login

# Step 1: Fetch data files from source to local directory
echo "=== Step 1: Fetching data files from $DATA_SOURCE_TYPE source ==="

# First install requirements from the src/search directory where fetch_data.py is located
cd /tmp/scripts/src/search
pip install -r requirements.txt

# Create local data directory
mkdir -p /tmp/local_data

# Fetch data using fetch_data.py
python fetch_data.py \
  --source_type "$DATA_SOURCE_TYPE" \
  --source_url "$DATA_SOURCE_URL" \
  --source_path "$DATA_SOURCE_PATH" \
  --output_dir "/tmp/local_data" \
  --file_pattern "$DATA_FILE_PATTERN"

# Step 2: Upload fetched data files to main storage account
echo "=== Step 2: Uploading data files to main storage account ==="
echo "Debug: MAIN_STORAGE_ACCOUNT_NAME = $MAIN_STORAGE_ACCOUNT_NAME"
echo "Debug: DATA_CONTAINER_NAME = $DATA_CONTAINER_NAME"
echo "Debug: AZURE_CLIENT_ID = $AZURE_CLIENT_ID"

# Verify managed identity authentication works
echo "=== Testing Azure authentication ==="
az account show
echo "=== Testing storage account access ==="
az storage account show --name "$MAIN_STORAGE_ACCOUNT_NAME" --resource-group $RESOURCE_GROUP_NAME --output table
echo "=== Testing storage container list access ==="
az storage container list --account-name "$MAIN_STORAGE_ACCOUNT_NAME" --auth-mode login --output table || echo "Container list failed"
echo "=== Testing specific container exists ==="
az storage container exists --name "$DATA_CONTAINER_NAME" --account-name "$MAIN_STORAGE_ACCOUNT_NAME" --auth-mode login || echo "Container exists check failed"

# Test creating container if it doesn't exist using Azure CLI (this should work if RBAC is correct)
echo "=== Testing container creation with Azure CLI ==="
az storage container create --name "$DATA_CONTAINER_NAME" --account-name "$MAIN_STORAGE_ACCOUNT_NAME" --auth-mode login || echo "Container creation failed"

# Run upload_data.py from the correct directory  
python upload_data.py \
  --storage_account_name "$MAIN_STORAGE_ACCOUNT_NAME" \
  --container_name "$DATA_CONTAINER_NAME" \
  --data_path "/tmp/local_data" \
  --file_pattern "$DATA_FILE_PATTERN"

# Step 3: Configure search index
echo "=== Step 3: Configuring search index ==="
python index_utils.py \
  --aisearch_name $SEARCH_SERVICE_NAME \
  --base_index_name "$BASE_INDEX_NAME" \
  --openai_api_base $OPENAI_ENDPOINT \
  --subscription_id $SUBSCRIPTION_ID \
  --resource_group_name $RESOURCE_GROUP_NAME \
  --storage_name "$MAIN_STORAGE_ACCOUNT_NAME" \
  --container_name $DATA_CONTAINER_NAME \
  --client_id "$AZURE_CLIENT_ID"
  
echo "=== Search index configuration completed successfully ==="
