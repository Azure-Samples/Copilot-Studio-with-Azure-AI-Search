resource "azapi_resource" "run_python_from_github" {
  type = "Microsoft.Resources/deploymentScripts@2023-08-01"
  name                = "run-python-from-github"
  //location            = azurerm_resource_group.this.location
  parent_id           = azurerm_resource_group.this.id
identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.script_identity.id]
  }
  body = {
    kind = "AzureCLI"
    location= azurerm_resource_group.this.location
    properties = {
      azCliVersion = "2.45.0"
      retentionInterval  = "P1D"
      cleanupPreference = "OnSuccess"
      timeout            = "PT15M"
      storageAccountSettings = {
        storageAccountName = module.storage_account_and_container.name
      }
      containerSettings = {
        subnetIds = [
          {
            id = "${azurerm_subnet.main.id}"
          }
        ]
      }
      scriptContent = <<EOF
        echo "Cloning private GitHub repo..."
        git clone https://github.com/sbaidachni/deploymentscript.git repo
        cd repo
        cd data
        # TODO this can go once requirements.txt lives in this repo
        pip install --force-reinstall "msal[broker]==1.20.0" "msal-extensions~=1.0.0"
        pip install -r requirements.txt
        python -m upload_data --storage_name $STORAGE_ACCOUNT_NAME --container_name data
        cd ../src/search
        pip install -r requirements.txt
        # TODO make sure we don't need explicit az login --identity here
        python -m src.search.index_utils --aisearch_name ${azurerm_search_service.ai_search.name} --base_index_name "default-index" --openai_api_base ${module.azure_open_ai.endpoint} --subscription_id ${data.azurerm_client_config.current.subscription_id} --resource_group_name ${azurerm_resource_group.this.name} --storage_name ${module.storage_account_and_container.name} --container_name ${var.cps_container_name}
      EOF
      environmentVariables = [
        {
          name = "STORAGE_ACCOUNT_NAME"
          value = "${module.storage_account_and_container.name}"
        }
      ]  
    }
  }
}