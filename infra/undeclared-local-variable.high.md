# Reference to Undeclared Local Variable

##
/workspaces/Copilot-Studio-with-Azure-AI-Search/infra/main.connections.tf

## Problem

In `main.connections.tf`, the resource `powerplatform_connection.ai_search_connection` has this attribute in its body:

```hcl
connection_parameters = jsonencode({
  ConnectionEndpoint = local.search_endpoint_url
  AdminKey           = azurerm_search_service.ai_search.primary_key
})
```

However, `local.search_endpoint_url` is not declared anywhere in this file, only in `main.tf`,
where it is defined as a local. Unless `main.connections.tf` is assembled in the same scope as `main.tf`, this will cause an error at plan or apply time due to a missing local variable.

## Impact

- Results in a Terraform error due to an undeclared reference, blocking plan and apply for this resource.
- Keeps the codebase from working out-of-the-box in modular, testable, or partial apply contexts.
- Hinders maintainability and increases cognitive load when tracing variable reference sources.

**Severity: HIGH**

## Location

- /infra/main.connections.tf (resource `powerplatform_connection.ai_search_connection`, reference to `local.search_endpoint_url`)

## Code Issue

```text
connection_parameters = jsonencode({
    ConnectionEndpoint = local.search_endpoint_url
    AdminKey           = azurerm_search_service.ai_search.primary_key
  })
```

## Fix

Declare the local directly in `main.connections.tf` if it is required here, or flip this value into a module input variable and pass it through explicitly for clarity and maintainability.
Example fix:

```text
locals {
  search_endpoint_url = "https://${azurerm_search_service.ai_search.name}.search.windows.net"
}

...
connection_parameters = jsonencode({
    ConnectionEndpoint = local.search_endpoint_url
    AdminKey           = azurerm_search_service.ai_search.primary_key
  })
```

Alternatively, use a variable:

```text
variable "search_endpoint_url" {
  description = "Azure Search endpoint URI."
  type        = string
}

# and use as
connection_parameters = jsonencode({
    ConnectionEndpoint = var.search_endpoint_url
    AdminKey           = azurerm_search_service.ai_search.primary_key
  })
```

Then pass it as a value in your root module or parent.
