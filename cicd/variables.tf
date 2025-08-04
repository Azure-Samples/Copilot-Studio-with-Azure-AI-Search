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
    github_runner_name  = string
    github_runner_token = string
    github_repo_owner   = string
    github_repo_name    = string
    github_runner_group = string
  })
  default = {
    github_runner_name  = "azure-runner"
    github_runner_token = ""
    github_repo_owner   = ""
    github_repo_name    = ""
    github_runner_group = "default"
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
