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



# Variables for GitHub Runner VM

variable "vm_github_runner_config" {
  type = object({
    runner_name  = string
    runner_token = string
    repo_owner   = string
    repo_name    = string
    runner_group = string
  })
  default = {
    runner_name  = "azure-runner"
    runner_token = ""
    repo_owner   = ""
    repo_name    = ""
    runner_group = "default"
  }
  description = "Configuration object for GitHub runner VM deployment (sensitive data only)"
  sensitive   = true
}

variable "github_runner_vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "VM size for the GitHub runner"
}

variable "github_runner_os_type" {
  type        = string
  default     = "linux"
  description = "Operating system type for the GitHub runner VM."
  validation {
    condition     = contains(["linux"], var.github_runner_os_type)
    error_message = "OS type must be 'linux'. Other OS types are not supported yet"
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

# variable "deploy_github_runner" {
#   type        = bool
#   default     = false
#   description = "Deploy GitHub Actions self-hosted runner infrastructure. Set to true to enable GitHub runner resources."
# }

# variable "enable_failover_github_runner" {
#   type        = bool
#   default     = false # Disabled to reduce runtime
#   description = "Enable the GitHub Actions self-hosted runner in the failover region. Set to true to deploy failover runner resources."
# }