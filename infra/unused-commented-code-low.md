# Excessive Commented-Out Code

##
/workspaces/Copilot-Studio-with-Azure-AI-Search/infra/main.search_configuration.tf

## Problem

The entire file is composed of commented-out code blocks, which appear to be previously intended resources, locals, and configuration for Azure Search index/indexer creation via custom Power Platform REST resources and polling.

Leaving large blocks of commented code in mainline branches or released infrastructure code is discouraged; it reduces clarity, risks confusion about what is "current", and is not self-documenting. The codebase is harder to maintain and increases the chance of merge conflicts or reintroducing deprecated logic.

## Impact

- Reduces codebase readability.
- Risks accidental re-activation of broken or deprecated logic.
- Can confuse contributors about the current infrastructure shape.

**Severity: Low**

## Location

- /infra/main.search_configuration.tf (entire file—all code is commented)

## Code Issue

```text
# Configuration of AI Search features required for CPS to do anything interesting.

# locals { ... }
# resource "powerplatform_rest" "search_index" { ... }
# resource "time_sleep" "wait_for_index" { ... }
# resource "powerplatform_rest" "search_indexer" { ... }
```

## Fix

Remove commented-out code before release or merging to main, or properly document its presence as an example (in README or a specific `/examples` directory if required).
If code is needed for reference or future use, move it to a documentation string or separate developer note file.

```text
# (Delete all blocks or move their reference into documentation or a sample folder)
```
