variable "environment_name" {
  type        = string
  description = "The name of the azd environment to be deployed"
}

variable "github_runner_config" {
  type = object({
    image_name            = string
    image_tag             = string
    repo_owner            = string
    repo_name             = string
    runner_group          = string
    image_branch          = string
    min_replicas          = number
    max_replicas          = number
    cpu_requests          = string
    memory_requests       = string
    workload_profile_type = string
  })
  description = "Configuration for GitHub self-hosted runners"
  sensitive   = true
}

variable "github_runner_registration_token" {
  type        = string
  sensitive   = true
  description = "GitHub runner registration token"
}

variable "github_pat" {
  type        = string
  sensitive   = true
  description = "GitHub Personal Access Token with repo and admin:repo_hook scopes. (DEPRECATED: moving to GitHub App credentials)"
  default     = ""
}

variable "runner_subnet_id" {
  type        = string
  description = "The ID of the subnet where the Container Apps Environment will be deployed"
}

variable "location" {
  type        = string
  description = "The Azure region where resources will be deployed"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group where resources will be deployed"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources created by this module"
}

variable "unique_id" {
  type        = string
  description = "A unique identifier to include in resource names to avoid conflicts"
}


variable "private_endpoint_subnet_id" {
  type        = string
  description = "The ID of the subnet where private endpoints will be deployed"
}

variable "virtual_network_id" {
  type        = string
  description = "The ID of the virtual network where the private DNS zone will be linked"
}

# variable "openai_endpoint" {
#   type        = string
#   description = "The Azure OpenAI service endpoint URL"
# }
