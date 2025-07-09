# Duplicate Addition of /usr/local/bin to PATH in Multiple Scripts

##

/workspaces/Copilot-Studio-with-Azure-AI-Search/azd-hooks/scripts/hooks/preprovision/run_gitleaks.ps1
/workspaces/Copilot-Studio-with-Azure-AI-Search/azd-hooks/scripts/hooks/preprovision/run_checkov.ps1
/workspaces/Copilot-Studio-with-Azure-AI-Search/azd-hooks/scripts/hooks/preprovision/run_tf_lint.ps1

## Problem

Each of the scripts for Gitleaks, Checkov, and TFLint unconditionally append `:/usr/local/bin` to the `PATH` environment variable. If these scripts are called in the same execution environment or multiple times, this results in repeated path segments, which is unnecessary and can eventually lead to excessively long `PATH` values.

## Impact

Repeated modification of the environment can cause confusion, environmental bloat, and unexpected behaviors if scripts run in chained sessions. This is a medium severity issue because it is not usually breaking, but represents poor code hygiene and possible future bugs.

## Location

- /workspaces/Copilot-Studio-with-Azure-AI-Search/azd-hooks/scripts/hooks/preprovision/run_gitleaks.ps1
- /workspaces/Copilot-Studio-with-Azure-AI-Search/azd-hooks/scripts/hooks/preprovision/run_checkov.ps1
- /workspaces/Copilot-Studio-with-Azure-AI-Search/azd-hooks/scripts/hooks/preprovision/run_tf_lint.ps1

## Code Issue

```text
# Example from run_gitleaks.ps1, run_checkov.ps1, run_tf_lint.ps1
$env:PATH += ":/usr/local/bin"
```

## Fix

Add a check before modifying the `PATH` environment variable to ensure that `/usr/local/bin` is only added if not already present. Place this in a helper function or at the start of the script.

```text
if ($env:PATH -notmatch ":/usr/local/bin($|:)") {
    $env:PATH += ":/usr/local/bin"
}
```

Or, to be more robust and idempotent, a reusable function:

```text
function Ensure-Path {
    param (
        [string]$PathSegment
    )
    if (-not ($env:PATH.Split(":") -contains $PathSegment)) {
        $env:PATH = "$env:PATH:$PathSegment"
    }
}

# Usage
Ensure-Path "/usr/local/bin"
```
