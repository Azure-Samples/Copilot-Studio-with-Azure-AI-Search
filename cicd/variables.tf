# Variables for Terraform state infrastructure

variable "subscription_id" {
  description = "The Azure subscription ID where the Terraform state infrastructure will be deployed"
  type        = string
  sensitive   = false
}

variable "location" {
  description = "The Azure region where the Terraform state infrastructure will be deployed"
  type        = string
  default     = "westus2"
}

variable "github_runner_type" {
  description = "Type of GitHub runner to deploy: 'vm' for Virtual Machine or 'aca' for Azure Container Apps"
  type        = string
  default     = "vm"
  validation {
    condition     = contains(["vm", "aca"], var.github_runner_type)
    error_message = "Runner type must be either 'vm' or 'aca'."
  }
}

# Variables for GitHub Runner VM
variable "github_runner_config" {
  type = object({
    runner_type  = optional(string, "vm")
    runner_name  = optional(string, "azure-runner")
    repo_owner   = string
    repo_name    = string
    runner_group = optional(string, "default")

    # vm configuration
    vm_size    = optional(string, "Standard_D2s_v3")
    vm_os_type = optional(string, "linux")

    # aca configuration
    min_replicas          = optional(number, 1)
    max_replicas          = optional(number, 3)
    cpu_requests          = optional(string, "1.0")
    memory_requests       = optional(string, "2Gi")
    workload_profile_type = optional(string, "Consumption") #D4?
    image_name            = optional(string, "")
    image_branch          = optional(string, "main")
    image_tag             = optional(string, "latest")
  })

  validation {
    condition = alltrue([
      length(var.github_runner_config.repo_owner) > 0,
      length(var.github_runner_config.repo_name) > 0,
    ])
    error_message = "repo_owner and repo_name are required and must be non-empty."
  }

  # Ensure replica values are valid for ACA runner type
  # See: Azure Container Apps - Scale apps and Quotas/limits
  # https://learn.microsoft.com/azure/container-apps/scale-app
  # https://learn.microsoft.com/azure/container-apps/quotas
  validation {
    condition = (
      var.github_runner_config.runner_type != "aca" ||
      (
        var.github_runner_config.min_replicas == floor(var.github_runner_config.min_replicas) &&
        var.github_runner_config.max_replicas == floor(var.github_runner_config.max_replicas) &&
        var.github_runner_config.min_replicas >= 0 &&
        var.github_runner_config.max_replicas >= 1 &&
        var.github_runner_config.max_replicas >= var.github_runner_config.min_replicas
      )
    )
    error_message = "When runner_type is 'aca', min_replicas must be an integer >= 0 and max_replicas must be an integer >= min_replicas (and >= 1)."
  }

  description = "Configuration object for GitHub runner VM deployment (sensitive data only)"
}

variable "github_runner_registration_token" {
  type        = string
  sensitive   = true
  description = "GitHub runner registration token"
}

# variable "github_runner_vm_size" {
#   type        = string
#   default     = "Standard_D2s_v3"
#   description = "VM size for the GitHub runner"
# }

# variable "github_runner_os_type" {
#   type        = string
#   default     = "linux"
#   description = "Operating system type for the GitHub runner VM."
#   validation {
#     condition     = contains(["linux"], var.github_runner_os_type)
#     error_message = "OS type must be 'linux'. Other OS types are not supported yet"
#   }
# }


variable "network_config" {
  type = object({
    vnet_address_space                  = list(string)
    storage_subnet_address_spaces       = list(string)
    github_runner_subnet_address_spaces = list(string)
  })
  default = {
    vnet_address_space                  = ["10.100.0.0/16"]
    storage_subnet_address_spaces       = ["10.100.1.0/24"]
    github_runner_subnet_address_spaces = ["10.100.2.0/24"]
  }

  validation {
    condition = alltrue([
      length(var.network_config.vnet_address_space) > 0,
      length(var.network_config.storage_subnet_address_spaces) > 0,
      length(var.network_config.github_runner_subnet_address_spaces) > 0,
    ])
    error_message = "All network_config lists must have at least one CIDR."
  }

  validation {
    condition = alltrue(concat(
      [for c in var.network_config.vnet_address_space : can(cidrnetmask(c))],
      [for c in var.network_config.storage_subnet_address_spaces : can(cidrnetmask(c))],
      [for c in var.network_config.github_runner_subnet_address_spaces : can(cidrnetmask(c))]
    ))
    error_message = "All entries in network_config must be valid CIDR notation (e.g., 10.0.0.0/16)."
  }

  validation {
    condition     = alltrue([for c in var.network_config.github_runner_subnet_address_spaces : tonumber(element(split("/", c), 1)) <= 23])
    error_message = "Each GitHub runner subnet must be /23 or larger (prefix length <= 23) for Azure Container Apps environment."
  }

  validation {
    condition = length(setintersection(
      var.network_config.storage_subnet_address_spaces,
      var.network_config.github_runner_subnet_address_spaces
    )) == 0
    error_message = "Storage and GitHub runner subnets must not reuse the same CIDR blocks."
  }

  validation {
    condition = alltrue([
      for s in concat(
        var.network_config.storage_subnet_address_spaces,
        var.network_config.github_runner_subnet_address_spaces
      ) : anytrue([for v in var.network_config.vnet_address_space : cidrcontains(v, cidrhost(s, 0))])
    ])
    error_message = "All subnets must be contained within one of the VNET address spaces."
  }
}

# variable "github_runner_config" {
#   type = object({
#     image_name                 = string
#     image_tag                  = string
#     github_pat                 = string
#     github_repo_owner          = string
#     github_repo_name           = string
#     github_runner_group        = string
#     github_runner_image_branch = string
#     min_replicas               = number
#     max_replicas               = number
#     cpu_requests               = string
#     memory_requests            = string
#     workload_profile_type      = string
#   })
#   description = "Configuration for GitHub self-hosted runners"
#   sensitive   = true
# }

# variable "primary_gh_runner_subnet_address_spaces" {
#   type        = list(string)
#   default     = ["10.1.10.0/23"]
#   description = "GitHub runner subnet address spaces in the primary VNET. Ensure there are no collisions with existing subnets. Must be /23 or larger for Container App Environment."
# }

# variable "failover_gh_runner_subnet_address_spaces" {
#   type        = list(string)
#   default     = ["10.2.10.0/23"]
#   description = "GitHub runner subnet address spaces in the failover VNET. Must be /23 or larger for Container App Environment."
# }

# variable "enable_failover_github_runner" {
#   type        = bool
#   default     = false # Disabled to reduce runtime
#   description = "Enable the GitHub Actions self-hosted runner in the failover region. Set to true to deploy failover runner resources."
# }