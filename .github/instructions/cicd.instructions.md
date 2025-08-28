appliesTo: "cicd/**/*.tf"
---

# CICD Terraform Instructions

This directory (`cicd/`) contains Terraform infrastructure specifically for creating Azure remote state storage for the main project's Terraform deployments.

## Important: Scope Restriction
**When editing the `cicd/` folder, never view or edit code in the rest of the repository.** This CICD infrastructure is self-contained and separate from the main application infrastructure.

## Architecture Overview

The CICD infrastructure creates a secure, private Azure Storage Account for storing Terraform state with:
- **Private Network Only**: Storage account with `public_network_access_enabled = false`
- **RBAC Authentication**: Uses `shared_access_key_enabled = false` and Azure AD auth
- **Private Endpoints**: VNet-injected storage access via private DNS zones
- **Enterprise Security**: Checkov compliance, diagnostic logging, blob versioning

## File Organization

```
cicd/
├── terraform.tf        # Provider versions and requirements
├── providers.tf        # Azure provider configuration with storage_use_azuread = true
├── variables.tf        # Input variables (subscription_id, location)
├── tfstate.tf         # Storage account, container, RBAC, monitoring
├── network.tf         # VNet, subnet, NSG, private endpoint, DNS
├── outputs.tf         # Values for configuring backend in other projects
└── github_vars.tf     # GitHub repository variables (if using GitHub Actions)
```

## Critical Patterns

### Resource Naming Convention
All resources use `local` values with random suffix for uniqueness:
```hcl
locals {
  resource_group_name = "rg-tfstate-${random_id.suffix.hex}"
  storage_name        = "sttfstate${random_id.suffix.hex}"  # Note: no hyphens for storage
  vnet_name           = "vnet-tfstate-${random_id.suffix.hex}"
}
```

### Security-First Design
- Storage account uses RBAC only: `shared_access_key_enabled = false`
- Network isolation: private endpoints + NSG rules for port 443 only
- Checkov skip comments document security exceptions with justifications
- Role assignments for both blob data and account management

### Backend Configuration Output
The `outputs.tf` provides a `backend_config` object for easy consumption:
```hcl
output "backend_config" {
  value = {
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
    resource_group_name  = azurerm_resource_group.tfstate.name
    subscription_id      = var.subscription_id
  }
}
```

## Deployment Workflow

1. **Setup**: Copy `terraform.tfvars.json.example` → `terraform.tfvars.json`
2. **Deploy**: Standard `terraform init/plan/apply` 
3. **Configure**: Use outputs to setup backend in main `infra/` directory
4. **GitHub Integration**: Run `github_vars.tf` to set repository variables for CI/CD

## GitHub Variables Pattern

When using GitHub Actions, set these repository variables from outputs:
- `RS_STORAGE_ACCOUNT`: Storage account name for remote state
- `RS_CONTAINER_NAME`: Container name ("tfstate")  
- `RS_RESOURCE_GROUP`: Resource group containing storage account

## Common Maintenance

- **State Migration**: Use `terraform state` commands for resource moves
- **Security Updates**: Update provider versions in `terraform.tf`
- **Network Changes**: Modify subnet ranges in `network.tf` if conflicts occur
- **Access Management**: Add role assignments in `tfstate.tf` for new principals
