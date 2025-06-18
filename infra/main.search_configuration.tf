resource "azapi_resource" "run_python_from_github" {
  type = "Microsoft.Resources/deploymentScripts@2023-08-01"
  name                = "run-python-from-github"
  location            = azurerm_resource_group.this.location
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
        pip install -r requirements.txt
        python -m upload_data --storage_name $STORAGE_ACCOUNT_NAME --container_name data
        cd ../src/search
        pip install -r requirements.txt
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