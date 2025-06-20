# APP INSIGHTS VARIABLES

variable "resource_share_user" {
  type        = set(string)
  default     = []
  description = "A set of Microsoft Entra ID object IDs for the interactive admin users who will initially have access to the resources created by this pattern. Example: ['object-id-1', 'object-id-2']"
}

variable "azd_environment_name" {
  description = "The name of the azd environment to be deployed"
  type        = string
}

variable "app_insights_sections" {
  type = map(object({
    query = string
    name  = string
    chart = string
  }))
  default = {
    section_1 = {
      query = "traces\n| where message contains \"Log Number\"\n| summarize requestCount = count() by bin(timestamp, 5s)\n| order by timestamp asc"
      name  = "Requests over time."
      chart = "unstackedbar"
    }
    section_2 = {
      query = "traces\n| where message contains \"Log Number\"\n| extend topic=customDimensions[\"topic\"]\n| summarize amount=count() by bin(timestamp, 10s), tostring(topic)"
      name  = "All requests split into topics."
      chart = "barchart"
    }
    section_3 = {
      query = "traces\n| where message contains \"Log Number\"\n| extend topic=customDimensions[\"topic\"]\n| limit 20"
      name  = "Last 20 requests."
      chart = "table"
    }
    section_4 = {
      query = "traces\n| where message contains \"Log Number\"\n| extend app_timestamp_real = todouble(customDimensions[\"timestamp\"])\n| extend app_timestamp = unixtime_seconds_todatetime(app_timestamp_real)\n| extend time_difference = tolong(timestamp - app_timestamp)\n| summarize average=avg(time_difference) by bin(timestamp, 5s)"
      name  = "Response time by timestamp."
      chart = "timechart"
    }
    section_5 = {
      query = "traces\n| where message contains \"Log Number\"\n| extend app_timestamp_real = todouble(customDimensions[\"timestamp\"])\n| extend app_timestamp = unixtime_seconds_todatetime(app_timestamp_real)\n| extend time_difference = tolong(timestamp - app_timestamp)\n| summarize average=avg(time_difference)"
      name  = "Avg time per response overall."
      chart = "stat"
    }
    section_6 = {
      query = "traces\n| where message contains \"Log Number\"\n| extend topic=customDimensions[\"topic\"]\n| extend app_timestamp_real = todouble(customDimensions[\"timestamp\"])\n| extend app_timestamp = unixtime_seconds_todatetime(app_timestamp_real)\n| extend time_difference = tolong(timestamp - app_timestamp)\n| summarize average=avg(time_difference) by bin(timestamp, 10s), tostring(topic)\n| render barchart"
      name  = "Avg time per response per topic."
      chart = "barchart"
    }
  }
  description = "A map of App Insights sections, each containing a KQL query, name, and chart type."
}

variable "app_insights_workbook_description" {
  type        = string
  default     = "# Description of Workbook\n\nThis workbook is designed as a starting point to monitor your Copilot and template for further workbooks.\n\n## Queries\n\nThe default queries include:\n\n1. Number of incoming requests over time overall\n2. Number of Requests split into topics\n3. List of last n requests (default: n = 20)\n4. Response time by timestamp (scatter chart or timechart to see outliers)\n5. Avg time per response overall \n6. Avg time per response per topic"
  description = "The description at the top of the workbook, in markdown format"
}

variable "cognitive_deployments" {
  type = map(object({
    name = string
    model = object({
      format  = string
      name    = string
      version = string
    })
    scale = object({
      type = string
      capacity = optional(number)
    })
    rai_policy_name = string
  }))
  default = {
    "gpt-4" = {
      name = "text-embedding-3-large"
      model = {
        format  = "OpenAI"
        name    = "text-embedding-3-large"
        version = "1"
      }
      scale = {
        type = "Standard"
        capacity = 100
      }
      rai_policy_name = "Microsoft.DefaultV2"
    }
  }
  description = <<DESCRIPTION
  A map of cognitive model deployments to create on the Azure OpenAI Cognitive Services account. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
  - `name` - (Required) The name of the deployment.
  - `model` - (Required) The model to deploy.
    - `format` - "OpenAI"
    - `name` - The name of the model to deploy.
    - `version` - The version of the model to deploy.
  - `scale` - (Required) The scale of the model.
    - `type` - The type of scale to use. Possible values are `Standard`.
  - `rai_policy_name` - (Required) The name of the RAI policy to use for the deployment.
  example:
  ```
  {
    "gpt-4" = {
      name = "gpt-4"
      model = {
        format  = "OpenAI"
        name    = "gpt-4"
        version = "0125-Preview"
      }
      scale = {
        type = "Standard"
      }
      rai_policy_name = "Microsoft.DefaultV2"
    }
    "text-embedding-ada-002" = {
      name = "text-embedding-ada-002"
      model = {
        format  = "OpenAI"
        name    = "text-embedding-ada-002"
        version = "2"
      }
      scale = {
        type = "Standard"
      }
      rai_policy_name = "Microsoft.DefaultV2"
    }
  }
  ```
  DESCRIPTION
}

variable "cps_container_name" {
  type        = string
  default     = "copilot-studio-sample-data"
  description = "The name of the storage container for the Copilot Studio bot's test data."
}

variable "cps_storage_replication_type" {
  type        = string
  default     = "LRS"
  description = "The replication type to use for the storage account the CPS bot's AI Search resource's datasource will connect to"
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

# variable "failover_ai_search_subnet_address_spaces" {
#   type        = list(string)
#   default     = ["10.2.0.0/24"]
#   description = "AI Search subnet address spaces. Ensure there are no collisions with existing subnets."
# }

variable "failover_location" {
  type        = string
  default     = "westus"
  description = "Failover region for deployment."
}

variable "failover_subnet_address_spaces" {
  type        = list(string)
  default     = ["10.2.1.0/24"]
  description = "Failover subnet address spaces."
}

variable "failover_subnet_name" {
  type        = string
  default     = "power-platform-failover-subnet"
  description = "The name of the failover subnet. Used in the Power Platform Enterprise Policy network connection."
}

variable "failover_vnet_address_spaces" {
  type        = list(string)
  default     = ["10.2.0.0/16"]
  description = "Failover virtual network address spaces."
}

variable "include_app_insights" {
  type        = bool
  default     = false
  description = "Include Application Insights in the deployment."
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Region where the resources should be deployed."
  nullable    = false
}

variable "power_platform_environment" {
  type = object({
    name              = string
    id                = string # Optional. If provided, the module will attempt to use the existing environment. If left blank, a new environment will be created.
    language_code     = number
    currency_code     = string
    security_group_id = string
    environment_type  = string
    location          = string
  })
  default = {
    name              = "Copilot Studio + Azure AI"
    id                = ""                                     # Optional. If provided, the module will attempt to use the existing environment. If left blank, a new environment will be created.
    language_code     = 1033                                   # English
    security_group_id = "00000000-0000-0000-0000-000000000000" # Optional. If provided, the module will attempt to expose the environment to the specified security group.
    currency_code     = "USD"
    environment_type  = "Sandbox"
    location          = "unitedstates"
  }
  description = <<DESCRIPTION
  - `name`: The name of the Power Platform environment to be managed.
  - `language_code`: The language code for the Power Platform environment.
  - `currency_code`: The currency code for the Power Platform environment.
  - `security_group_id`: The ID of the security group to be used for initial access to the Power Platform environment.
  - `environment_type`: The type of the Power Platform environment to be managed.
  - `location`: The location of the Power Platform environment.
DESCRIPTION
}

variable "power_platform_managed_environment" {
  type = object({
    id                         = string # Optional. If provided, the module will attempt to use the existing managed environment. If left blank, a new environment will be created.
    is_usage_insights_disabled = bool
    is_group_sharing_disabled  = bool
    limit_sharing_mode         = string
    max_limit_user_sharing     = number
    solution_checker_mode      = string
    suppress_validation_emails = bool
    maker_onboarding_markdown  = string
    maker_onboarding_url       = string
  })
  default = {
    id                         = "" # Optional. If provided, the module will attempt to use the existing managed environment. If left blank, a new environment will be created.
    is_usage_insights_disabled = false
    is_group_sharing_disabled  = false
    limit_sharing_mode         = "ExcludeSharingToSecurityGroups"
    max_limit_user_sharing     = 0
    solution_checker_mode      = "None"
    suppress_validation_emails = false
    maker_onboarding_markdown  = ""
    maker_onboarding_url       = ""
  }
  description = "Configuration for the Power Platform managed environment"
}

# variable "primary_ai_search_subnet_address_spaces" {
#   type        = list(string)
#   default     = ["10.1.7.0/24"]
#   description = "AI Search subnet address spaces. Ensure there are no collisions with existing subnets."
# }

variable "primary_location" {
  type        = string
  default     = "eastus"
  description = "Primary region for deployment."
}

variable "primary_subnet_address_spaces" {
  type        = list(string)
  default     = ["10.1.6.0/24"]
  description = "Primary subnet address spaces. Ensure there are no collisions with existing subnets."
}

variable "primary_subnet_name" {
  type        = string
  default     = "power-platform-primary-subnet"
  description = "The name of the primary subnet. Used in the Power Platform Enterprise Policy network connection."
}

variable "primary_vnet_address_spaces" {
  type        = list(string)
  default     = ["10.1.0.0/16"]
  description = "Primary virtual network address spaces."
}

variable "resource_prefix" {
  type        = string
  default     = "cpmonitor"
  description = "Prefix for all resource names"
}

variable "resource_suffix" {
  type        = string
  default     = "001"
  description = "Suffix for all resource names"
}

variable "tags" {
  type = map(string)
  default = {
    name = "AZD-MCS-AZAI"
  }
  description = "The tags for the resources."
}

variable "ai_search_config" {
  type = object({
    sku                           = string
    partition_count               = number
    replica_count                 = number
    public_network_access_enabled = bool
  })
  default = {
    sku                           = "basic"
    partition_count               = 1
    replica_count                 = 1
    public_network_access_enabled = false
  }
  description = "Configuration options for Azure AI Search service. The sku determines pricing tier, partition_count affects index update SLA, and replica_count affects query SLA requirements."

  validation {
    condition     = contains(["free", "basic", "standard", "standard2", "standard3", "storage_optimized_l1", "storage_optimized_l2", "ultra"], var.ai_search_config.sku)
    error_message = "The sku value must be one of: free, basic, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2, or ultra."
  }

  validation {
    condition     = var.ai_search_config.partition_count >= 1 && var.ai_search_config.partition_count <= 12
    error_message = "The partition_count value must be between 1 and 12."
  }

  validation {
    condition     = var.ai_search_config.replica_count >= 1 && var.ai_search_config.replica_count <= 12
    error_message = "The replica_count value must be between 1 and 12."
  }
}

variable "primary_pe_subnet_address_spaces" {
  description = "Address space for the primary private endpoint subnet"
  type        = list(string)
  default     = ["10.1.8.0/24"]
}

variable "failover_pe_subnet_address_spaces" {
  description = "Address space for the failover private endpoint subnet"
  type        = list(string)
  default     = ["10.2.8.0/24"]
}

variable "github_runner_config" {
  type = object({
    image_name                  = string
    image_tag                   = string
    github_pat                  = string
    github_repo_owner           = string
    github_repo_name            = string
    github_runner_group         = string
    github_runner_image_branch  = string
    min_replicas                = number
    max_replicas                = number
    cpu_requests                = string
    memory_requests             = string
    workload_profile_type       = string
  })
  description = "Configuration for GitHub self-hosted runners"
  sensitive   = true
}

variable "primary_gh_runner_subnet_address_spaces" {
  type        = list(string)
  default     = ["10.1.10.0/23"]
  description = "GitHub runner subnet address spaces in the primary VNET. Ensure there are no collisions with existing subnets. Must be /23 or larger for Container App Environment."
}

variable "failover_gh_runner_subnet_address_spaces" {
  type        = list(string)
  default     = ["10.2.10.0/23"]
  description = "GitHub runner subnet address spaces in the failover VNET. Must be /23 or larger for Container App Environment."
}

variable "deploy_github_runner" {
  type        = bool
  default     = false
  description = "Deploy GitHub Actions self-hosted runner infrastructure. Set to true to enable GitHub runner resources."
}

variable "enable_failover_github_runner" {
  type        = bool
  default     = false # Disabled to reduce runtime
  description = "Enable the GitHub Actions self-hosted runner in the failover region. Set to true to deploy failover runner resources."
}
