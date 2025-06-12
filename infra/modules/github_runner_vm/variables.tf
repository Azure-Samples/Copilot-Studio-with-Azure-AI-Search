variable "enable_vm_github_runner" {
  type        = bool
  default     = false
  description = "Enable GitHub self-hosted runner deployment"
}

variable "vm_github_runner_config" {
  type = object({
    github_runner_name    = string
    github_runner_token   = string
    github_runner_url     = string
    github_repo_owner     = string
    github_repo_name      = string
    github_runner_group   = string
  })
  default = {
    github_runner_name    = "azure-runner"
    github_runner_token   = ""
    github_runner_url     = ""
    github_repo_owner     = ""
    github_repo_name      = ""
    github_runner_group   = "default"
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
  description = "Operating system type for the GitHub runner VM (linux or windows)"
  validation {
    condition     = contains(["linux", "windows"], var.github_runner_os_type)
    error_message = "OS type must be either 'linux' or 'windows'."
  }
}

variable "location" {
  type        = string
  description = "Azure region where resources will be deployed"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "unique_id" {
  type        = string
  description = "Unique identifier for resource naming"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet where the GitHub runner VM will be deployed"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}