# Azure Container Registry for GitHub Runner Docker images

resource "azurerm_container_registry" "github_runners" {
  name                            = "acr${var.unique_id}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  sku                             = "Premium"
  admin_enabled                   = false

  # We need to enable public network access until
  # networkRuleBypassAllowedForTasks actually works
  public_network_access_enabled   = true # false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azapi_update_resource" "allow_task_network_bypass" {
  type = "Microsoft.ContainerRegistry/registries@2025-05-01-preview"
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
  name                      = "privatelink.azurecr.io"
  resource_group_name       = var.resource_group_name
  tags                      = var.tags
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
  scope                 = azurerm_container_registry.github_runners.id
  role_definition_name  = "AcrPull"
  principal_id          = azurerm_user_assigned_identity.github_runner.principal_id

  depends_on            = [azurerm_private_endpoint.acr]
}

resource "azurerm_container_registry_task" "github_runner_build" {
  name                  = "build-github-runner-${var.unique_id}"
  container_registry_id = azurerm_container_registry.github_runners.id

  platform {
    os           = "Linux"
    architecture = "amd64"
  }

  docker_step {
    dockerfile_path      = "Dockerfile"
    context_path         = "infra/containers/github-runner"
    context_access_token = var.github_runner_config.github_pat
    image_names          = ["${var.github_runner_config.image_name}:${var.github_runner_config.image_tag}"]
  }

  source_trigger {
    name           = "manual-trigger"
    repository_url = "https://github.com/${var.github_runner_config.github_repo_owner}/${var.github_runner_config.github_repo_name}"
    source_type    = "Github"
    branch         = var.github_runner_config.github_runner_image_branch
    events         = ["commit"]

    authentication {
      token      = var.github_runner_config.github_pat
      token_type = "PAT"
    }
  }

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
