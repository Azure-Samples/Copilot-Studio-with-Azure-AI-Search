# Cognitive Services OpenAI user for AI Search MI to AOAI resource
resource "azurerm_role_assignment" "ai_search_to_aoai" {
  principal_id         = azurerm_search_service.ai_search.identity[0].principal_id
  scope                = module.azure_open_ai.resource_id
  role_definition_name = "Cognitive Services OpenAI User"
}

# Blob read for AI Search
resource "azurerm_role_assignment" "ai_search_to_storage" {
  principal_id         = azurerm_search_service.ai_search.identity[0].principal_id
  scope                = module.storage_account_and_container.resource_id
  role_definition_name = "Storage Blob Data Reader"
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = module.storage_account_and_container.resource_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}

resource "azurerm_role_assignment" "file_data_privileged_contributor" {
  scope                = module.storage_account_and_container.resource_id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}