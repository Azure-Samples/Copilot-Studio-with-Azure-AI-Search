# Variables for Terraform state infrastructure

variable "subscription_id" {
  description = "The Azure subscription ID where the Terraform state infrastructure will be deployed"
  type        = string
  sensitive   = false
}

variable "location" {
  description = "The Azure region where the Terraform state infrastructure will be deployed"
  type        = string
  default     = "East US"
}

# Variables for GitHub integration

# variable "github_owner" {
#   description = "The GitHub organization or user account owner"
#   type        = string
#   default     = "Azure-Samples"
# }

# variable "github_repository" {
#   description = "The GitHub repository name"
#   type        = string
#   default     = "Copilot-Studio-with-Azure-AI-Search"
# }
