# Possible Principal Object Access Array Bug in azurerm_role_assignment

##
/workspaces/Copilot-Studio-with-Azure-AI-Search/infra/main.security.tf

## Problem

In the usage of `azurerm_search_service.ai_search.identity[0].principal_id` in `azurerm_role_assignment.ai_search_to_aoai` and `azurerm_role_assignment.ai_search_to_storage`, the assumption is that only one system-assigned identity is ever present. If the identities object changes or Azure provider internals change such that this becomes a map/object, the code could break. Also, for clarity, using `.principal_id` directly on the `identity` block (when only system-assigned is true) is more robust and improves readability.

## Impact

- Can result in plan/apply errors if the resource shape changes or multiple identities are present.
- Reduces code robustness and forward compatibility.
- Increases maintainability cost if Azure resource or provider changes.

**Severity: Medium**

## Location

- /infra/main.security.tf (references to `azurerm_search_service.ai_search.identity[0].principal_id`)

## Code Issue

```text
resource "azurerm_role_assignment" "ai_search_to_aoai" {
  principal_id         = azurerm_search_service.ai_search.identity[0].principal_id
  ...
}
resource "azurerm_role_assignment" "ai_search_to_storage" {
  principal_id         = azurerm_search_service.ai_search.identity[0].principal_id
  ...
}
```

## Fix

If only system-assigned MI is ever used, prefer:

```text
principal_id = azurerm_search_service.ai_search.identity.principal_id
```

If user-assigned are ever possible, add a conditional or loop that supports both cases robustly.

Update both role assignment resources accordingly.
