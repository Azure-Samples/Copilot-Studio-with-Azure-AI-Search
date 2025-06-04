# GitHub Actions Self-Hosted Runner Module
# This module deploys GitHub Actions self-hosted runners on Azure Container Apps

locals {
  # Ensure container app name meets Azure naming requirements:
  # - lowercase alphanumeric or '-' only
  # - start with alphabetic, end with alphanumeric
  # - no consecutive '--'
  # - max 32 characters
  sanitized_env_name = lower(replace(var.environment_name, "/[^a-zA-Z0-9-]/", "-"))
  runner_name = substr(
    "ca-runner-${local.sanitized_env_name}-${var.unique_id}",
    0,
    32
  )
}

# Log Analytics Workspace for Container Apps
resource "azurerm_log_analytics_workspace" "github_runners" {
  name                = "law-github-runners-${var.unique_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Container Apps Environment
resource "azurerm_container_app_environment" "github_runners" {
  name                           = "cae-github-runners-${var.unique_id}"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.github_runners.id
  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = true
  tags                           = var.tags

  workload_profile {
    name                  = "wp-general"
    workload_profile_type = var.github_runner_config.workload_profile_type
    minimum_count         = var.github_runner_config.min_replicas
    maximum_count         = var.github_runner_config.max_replicas
  }
}

# Container App for GitHub Runners
resource "azurerm_container_app" "github_runner" {
  name                          = local.runner_name
  container_app_environment_id  = azurerm_container_app_environment.github_runners.id
  resource_group_name           = var.resource_group_name
  revision_mode                 = "Single"

  template {
    min_replicas = var.github_runner_config.min_replicas
    max_replicas = var.github_runner_config.max_replicas

    container {
      name   = var.github_runner_config.image_name
      image  = "${var.image_registry.server}/${var.github_runner_config.image_name}-amd64:${var.github_runner_config.image_tag}"
      cpu    = tonumber(var.github_runner_config.cpu_requests)
      memory = var.github_runner_config.memory_requests

      env {
        name  = "RUNNER_SCOPE"
        value = "repo"
      }
      env {
        name  = "REPO_URL"
        value = "https://github.com/${var.github_runner_config.github_repo_owner}/${var.github_runner_config.github_repo_name}"
      }
      env {
        name        = "ACCESS_TOKEN"
        secret_name = "github-pat"
      }
      env {
        name  = "RUNNER_GROUP"
        value = var.github_runner_config.github_runner_group
      }
      env {
        name  = "LABELS"
        value = "self-hosted,container-apps,${var.resource_group_name},${var.environment_name},${var.location},${var.unique_id}"
      }
      env {
        name  = "DISABLE_RUNNER_UPDATE"
        value = "true"
      }
      env {
        name  = "RUNNER_NAME"
        value = local.runner_name
      }
    }

    custom_scale_rule {
      name             = "gha-scaler"
      custom_rule_type = "github-runner"

      metadata = {
        githubApiURL              = "https://api.github.com"
        owner                     = var.github_runner_config.github_repo_owner
        repos                     = var.github_runner_config.github_repo_name
        targetWorkflowQueueLength = "1"
        labels                    = var.github_runner_config.github_runner_group
      }

      authentication {
        secret_name       = "github-pat"
        trigger_parameter = "personalAccessToken"
      }
    }
  }

  registry {
    server               = var.image_registry.server
    username             = var.image_registry.username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "github-pat"
    value = var.github_runner_config.github_pat
  }

  secret {
    name  = "acr-password"
    value = var.image_registry.password
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

resource "null_resource" "deregister_runner" {
  triggers = {
    pat    = var.github_runner_config.github_pat
    owner  = var.github_runner_config.github_repo_owner
    repo   = var.github_runner_config.github_repo_name
    runner = azurerm_container_app.github_runner.name
  }

  depends_on = [ azurerm_container_app.github_runner ]

  provisioner "local-exec" {
    when = destroy

    environment = {
      PAT    = self.triggers.pat
      OWNER  = self.triggers.owner
      REPO   = self.triggers.repo
      RUNNER = self.triggers.runner
    }

    command = <<-EOF
      # grab the runner ID from GitHub
      RUNNER_ID=$(
        curl -s \
          -H "Authorization: token $PAT" \
          -H "Accept: application/vnd.github.v3+json" \
          "https://api.github.com/repos/$OWNER/$REPO/actions/runners" \
        | jq -r '.runners[] | select(.name=="'"$RUNNER"'") | .id'
      )

      if [ -n "$RUNNER_ID" ]; then
        curl -s -X DELETE \
          -H "Authorization: token $PAT" \
          -H "Accept: application/vnd.github.v3+json" \
          "https://api.github.com/repos/$OWNER/$REPO/actions/runners/$RUNNER_ID"
        echo "➜ Deregistered self-hosted runner ID $RUNNER_ID"
      else
        echo "➜ No runner named '$RUNNER' found; skipping"
      fi
    EOF
  }
}
