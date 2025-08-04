variable "vm_github_runner_config" {
  type = object({
    runner_token = string
    runner_name  = string
    repo_owner   = string
    repo_name    = string
    runner_group = string
  })
  default = {
    runner_token = ""
    runner_name  = "azure-runner"
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
