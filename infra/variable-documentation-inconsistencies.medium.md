# Variable Documentation Inconsistencies and Redundancy

##
/workspaces/Copilot-Studio-with-Azure-AI-Search/infra/modules/copilot_studio/variables.tf, /workspaces/Copilot-Studio-with-Azure-AI-Search/infra/variables.tf

## Problem

There is inconsistent usage and duplication in input variable blocks and their descriptions between module and root variable definitions. For example, the root variable `power_platform_environment` (in `/infra/variables.tf`) and the module definition for the same have mostly duplicated structure and documentation, but this can easily drift and confuse users. Some description fields are partial, use improper formatting/syntax for Terraform docs, or don't match coding style (see `failover_subnet_name`, `customer_managed_key`).

There are also variables tagged as `tflint-ignore: terraform_unused_declarations` in the module that are exposed but stated as not applicable (see `customer_managed_key`).

## Impact

- May lead to drift and inconsistent documentation about how variables are used or required between the root and modules.
- Reduces maintainability as documentation has to be updated in two places.
- Incomplete or mismatched variable descriptions impact usability via Terraform registry/module documentation.
- Confusing to end users regarding which variables are required and for what purpose.

**Severity: Medium**

## Location

- /infra/variables.tf (variable definitions)
- /infra/modules/copilot_studio/variables.tf (module variable definitions, doc comments)

## Code Issue

```text
variable "failover_subnet_name" {
  type        = string
  description = "The name of the failover subnet. Used in the Power Platform Enterprise Policy network connection."
}

# tflint-ignore: terraform_unused_declarations
variable "customer_managed_key" { ... }

variable "power_platform_environment" { ... }
```

## Fix

- Use a single source of truth for variable structure and comments if possible. 
- Export module input/output variable documentation using automation (`terraform-docs` or similar tooling) to avoid drift.
- Avoid copy-pasting large docs in both root and module; instead, use brief, clear, and direct comments.
- Do not expose non-applicable variables (e.g., `customer_managed_key`) unless necessary for a contract, and clearly mark them as ignored with a comment.
- Ensure all descriptions are full sentences with clear, consistent style.

Example (brief, non-redundant comment):

```text
variable "failover_subnet_name" {
  type        = string
  description = "Name of the subnet used as failover network in the Enterprise Policy."
}
```

Consider moving canonical documentation to one layer, and referring to it in the other (or embedding/inheriting `description` fields via tooling).
