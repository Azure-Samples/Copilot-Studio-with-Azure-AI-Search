# Unnecessary `null` Tag Defaults

##
/workspaces/Copilot-Studio-with-Azure-AI-Search/infra/modules/copilot_studio/variables.tf

## Problem

The default for the `tags` variable is set to `null`. This is not needed in modern Terraform (0.13 and newer), can cause issues with resource `merge` logic, and may interfere with type expectations in resource modules. Defaulting to an empty map is safer and more idiomatic than using `null` for tags.

## Impact

- Can lead to confusion or extra conditionals required in resources consuming `var.tags`.
- Increases chance of resource creation failure if `null` ends up merged, or values expect a map.
- Consistency with Terraform ecosystem standards is reduced.

**Severity: Low**

## Location

- /infra/modules/copilot_studio/variables.tf (variable `tags`)

## Code Issue

```text
variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}
```

## Fix

Set the default to an empty map:

```text
variable "tags" {
  type        = map(string)
  default     = {}
  description = "(Optional) Tags of the resource."
}
```

This follows the principle of least surprise for tags.
