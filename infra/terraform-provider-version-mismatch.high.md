# Terraform Provider Version Mismatch

##
/workspaces/Copilot-Studio-with-Azure-AI-Search/infra/provider.tf, /workspaces/Copilot-Studio-with-Azure-AI-Search/infra/modules/copilot_studio/terraform.tf

## Problem

There are conflicting versions of Terraform and required providers specified across 
multiple `terraform` blocks. In `/infra/provider.tf`, the required Terraform version is `>= 1.1.7, < 2.0.0` and some providers (e.g., azurerm, powerplatform, random) use `~>` version constraints. However, in `/infra/modules/copilot_studio/terraform.tf`, Terraform version is set to `>= 1.9, < 2.0` and provider constraints are pinned to different versions (for instance, azurerm v4.29.0 without a flexible constraint).

## Impact

Mixing tightly-pinned versions (without `~>`) and explicit version minimums causes module initialization failures for mismatching versions. This can result in provider incompatibilities, broken dependency lock files, or plan/apply failures when using the module as a child or in automation.

**Severity: HIGH**

## Location

- /infra/provider.tf (`terraform.required_version`, `required_providers` blocks)
- /infra/modules/copilot_studio/terraform.tf (`terraform.required_version`, `required_providers` blocks)

## Code Issue

```text
# /infra/provider.tf
terraform {
  required_version = ">= 1.1.7, < 2.0.0"
  required_providers {
    ...
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.29.0"
    }
    ...
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
    ...
  }
}

# /infra/modules/copilot_studio/terraform.tf
terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.29.0"
    }
    ...
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    ...
  }
}
```

## Fix

Unify the Terraform version and provider version constraints across the root and module.
Prefer using compatible version ranges (e.g., `~> 4.29, < 5.0`) instead of exact versions for providers. 
Set `required_version` consistently. Example fix:

```text
# In BOTH files, use:
terraform {
  required_version = ">= 1.1.7, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.29.0"
    }
    ...
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
    ...
  }
}

# This ensures both root and child modules use compatible versions and avoids initialization errors.
```

Update any dependency lock files if needed.
