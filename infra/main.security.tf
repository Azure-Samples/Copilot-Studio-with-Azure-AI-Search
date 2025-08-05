# ============================================================================
# IDENTITY RESOURCES
# ============================================================================

# Get current subscription info
data "azurerm_subscription" "current" {}

resource "azurerm_user_assigned_identity" "script_identity" {
  name                = "deployment-script-identity"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  tags                = var.tags
}

# ============================================================================
# AI SEARCH SERVICE PERMISSIONS (System-Assigned Identity)
# ============================================================================

# AI Search service to Azure OpenAI
resource "azurerm_role_assignment" "ai_search_to_aoai" {
  principal_id         = azurerm_search_service.ai_search.identity[0].principal_id
  scope                = module.azure_open_ai.resource_id
  role_definition_name = "Cognitive Services OpenAI User"
}

# AI Search service to main storage account (for indexing data)
resource "azurerm_role_assignment" "ai_search_to_storage" {
  principal_id         = azurerm_search_service.ai_search.identity[0].principal_id
  scope                = module.storage_account_and_container.resource_id
  role_definition_name = "Storage Blob Data Reader"
}

# ============================================================================
# DEPLOYMENT SCRIPT MANAGED IDENTITY PERMISSIONS
# ============================================================================

# --- Azure OpenAI Permissions ---
resource "azurerm_role_assignment" "script_cognitive_services_openai_user" {
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
  scope                = module.azure_open_ai.resource_id
  role_definition_name = "Cognitive Services OpenAI User"
}

# --- AI Search Permissions ---
resource "azurerm_role_assignment" "script_search_service_contributor" {
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
  scope                = azurerm_search_service.ai_search.id
  role_definition_name = "Search Service Contributor"
}

# --- Main Storage Account Permissions ---
resource "azurerm_role_assignment" "script_main_storage_blob_contributor" {
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
  scope                = module.storage_account_and_container.resource_id
  role_definition_name = "Storage Blob Data Contributor"
}

resource "azurerm_role_assignment" "script_main_storage_reader" {
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
  scope                = module.storage_account_and_container.resource_id
  role_definition_name = "Reader"
}

# --- Deployment Container Storage Account ---
resource "azurerm_role_assignment" "script_deployment_container_blob_contributor" {
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
  scope                = azurerm_storage_account.deployment_container.id
  role_definition_name = "Storage Blob Data Contributor"
}

resource "azurerm_role_assignment" "script_deployment_container_file_contributor" {
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
  scope                = azurerm_storage_account.deployment_container.id
  role_definition_name = "Storage File Data Privileged Contributor"
}

# ============================================================================
# TERRAFORM PRINCIPAL PERMISSIONS (for deployment-time operations)
# ============================================================================

resource "azurerm_role_assignment" "terraform_deployment_container_storage_access" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_storage_account.deployment_container.id
  role_definition_name = "Storage Blob Data Owner"
}

resource "azurerm_role_assignment" "terraform_deployment_container_account_contributor" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_storage_account.deployment_container.id
  role_definition_name = "Storage Account Contributor"
}

resource "azurerm_role_assignment" "terraform_deployment_container_file_access" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_storage_account.deployment_container.id
  role_definition_name = "Storage File Data Privileged Contributor"
}