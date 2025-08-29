# Azure Container Registry for GitHub Runner Docker images

resource "azurerm_container_registry" "github_runners" {
  # checkov:skip=CKV_AZURE_139: We need to enable public network access until networkRuleBypassAllowedForTasks actually works
  # checkov:skip=CKV_AZURE_164: Not needed since image is built and published together with ACR creation
  # checkov:skip=CKV_AZURE_165: Deploying with minimal infrastructure for evaluation and cost-saving
  # checkov:skip=CKV_AZURE_166: Not needed since image is built and published together with ACR creation
  # checkov:skip=CKV_AZURE_233: Deploying with minimal infrastructure for evaluation and cost-saving
  # checkov:skip=CKV_AZURE_237: We need to enable public network access until networkRuleBypassAllowedForTasks actually works
  name                     = "acr${var.unique_id}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  sku                      = "Premium"
  admin_enabled            = false
  retention_policy_in_days = 7

  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azapi_update_resource" "allow_task_network_bypass" {
  type        = "Microsoft.ContainerRegistry/registries@2025-05-01-preview"
  resource_id = azurerm_container_registry.github_runners.id

  body = {
    properties = {
      networkRuleBypassAllowedForTasks = true
    }
  }

  depends_on = [
    azurerm_container_registry.github_runners,
  ]
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-${var.unique_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr-${var.unique_id}"
    private_connection_resource_id = azurerm_container_registry.github_runners.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "acr-dns-link-${var.unique_id}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_role_assignment" "user_identity_acr_pull" {
  scope                = azurerm_container_registry.github_runners.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.github_runner.principal_id

  depends_on = [azurerm_private_endpoint.acr]
}

resource "azurerm_container_registry_task" "github_runner_build" {
  name                  = "build-github-runner-${var.unique_id}"
  container_registry_id = azurerm_container_registry.github_runners.id

  platform {
    os           = "Linux"
    architecture = "amd64"
  }

  docker_step {
    dockerfile_path = "Dockerfile"
    # Note: Use "cicd/github_runner_aca" for context_path when enabling source_trigger
    context_path         = "https://github.com/${var.github_runner_config.repo_owner}/${var.github_runner_config.repo_name}#${var.github_runner_config.image_branch}:cicd/github_runner_aca"
    context_access_token = var.github_pat # Use var.github_pat for private repos, but should not be needed for public
    image_names          = ["${var.github_runner_config.image_name}:${var.github_runner_config.image_tag}"]
  }

  # This webhook allows ACR tasks to listen for new commits from the specified repo branch
  # and re-build the image automatically.
  # Since webhook creation requires admin/repo permissions that can be restricted in some organizations,
  # we have disabled this feature by default to avoid issues.

  # source_trigger {
  #   name           = "manual-trigger"
  #   repository_url = "https://github.com/${var.github_runner_config.github_repo_owner}/${var.github_runner_config.github_repo_name}"
  #   source_type    = "Github"
  #   branch         = var.github_runner_config.github_runner_image_branch
  #   events         = ["commit"]

  #   authentication {
  #     token      = var.github_pat
  #     token_type = "PAT"
  #   }
  # }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_private_endpoint.acr,
    azapi_update_resource.allow_task_network_bypass
  ]
}

resource "azurerm_container_registry_task_schedule_run_now" "github_runner_build" {
  container_registry_task_id = azurerm_container_registry_task.github_runner_build.id

  depends_on = [
    azurerm_container_registry_task.github_runner_build
  ]
}
