# Poor Practice: Use of cd and $PWD Directly in Scripts without Validation

##

/workspaces/Copilot-Studio-with-Azure-AI-Search/azd-hooks/scripts/hooks/preprovision/run_tf_lint.ps1

## Problem

The script uses `cd $PWD/infra` and uses $PWD to construct paths. This risks errors if $PWD is not what is expected (e.g., if the script is sourced, or $PWD is redefined/unexpectedly changed). Also, `cd` is used instead of verbose push/pop, which makes directory state more implicit. It's better to use `Push-Location`/`Pop-Location` and construct paths from `$PSScriptRoot` or parameter input for robustness.

## Impact

Low severity. It's technically functional but can lead to subtle directory bugs, especially when refactoring or running under different execution contexts.

## Location

- /workspaces/Copilot-Studio-with-Azure-AI-Search/azd-hooks/scripts/hooks/preprovision/run_tf_lint.ps1

## Code Issue

```text
Push-Location $PWD
cd $PWD/infra
# ...
$lintResFileName = "$((Get-Item -Path $PWD).BaseName)_lint_res.xml"
```

## Fix

Use `$PSScriptRoot` to explicitly locate the script's directory or have the infra dir as a parameter. Use Push-Location/Pop-Location only. Example:

```text
Push-Location "$PSScriptRoot/infra"
# ...
$lintResFileName = "lint_res.xml"
# ...
Pop-Location
```

Or:

```text
param ([string]$InfraDir = "$PSScriptRoot/infra")
Push-Location $InfraDir
# ...
Pop-Location
```
