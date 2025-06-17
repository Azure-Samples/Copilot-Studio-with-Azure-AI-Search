# Inconsistent or Premature Use of exit in Helper Functions

##

/workspaces/Copilot-Studio-with-AI-Search/azd-hooks/scripts/hooks/preprovision/run_checkov.ps1
/workspaces/Copilot-Studio-with-Azure-AI-Search/azd-hooks/scripts/hooks/preprovision/run_gitleaks.ps1
/workspaces/Copilot-Studio-with-AI-Search/azd-hooks/scripts/hooks/preprovision/run_tf_lint.ps1

## Problem

Each script defines helper functions (e.g., `Check-Checkov`, `Check-Gitleaks`, `Check-TFLint`) which, when encountering an error, call `exit 1`. Exiting the full script from inside a utility function makes the code harder to test/reuse, and centralizes error handling in a single place. It would be better for helper functions to use `throw` or return `$false` and handle the exit in the main script context, enhancing composability and making future debugging easier.

## Impact

Medium severity. Early exit in a helper function can break composition, pipeline chaining, and make debugging/testability more challenging. It makes these scripts less robust and modular.

## Location

- Helper functions within:
  - /workspaces/Copilot-Studio-with-AI-Search/azd-hooks/scripts/hooks/preprovision/run_gitleaks.ps1
  - /workspaces/Copilot-Studio-with-AI-Search/azd-hooks/scripts/hooks/preprovision/run_checkov.ps1
  - /workspaces/Copilot-Studio-with-AI-Search/azd-hooks/scripts/hooks/preprovision/run_tf_lint.ps1

## Code Issue

```text
function Check-Checkov {
    ...
    if ($null -eq $checkovPath) {
        Write-Error "Checkov is not installed or not found in PATH!`n"
        exit 1
    }
    ...
}
```

## Fix

Have the function `throw` or return a Boolean/signal, and process this in the entrypoint of the script. Example:

```text
function Check-Checkov {
    ...
    if ($null -eq $checkovPath) {
        Write-Error "Checkov is not installed or not found in PATH!`n"
        return $false
    }
    ...
    return $true
}

if (-not (Check-Checkov)) { exit 1 }
```

Or use `throw` for hard-failure:

```text
function Check-Checkov {
    if ($null -eq $checkovPath) {
        throw "Checkov is not installed or not found in PATH!"
    }
}
try {
    Check-Checkov
} catch {
    Write-Error $_
    exit 1
}
```
