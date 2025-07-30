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
