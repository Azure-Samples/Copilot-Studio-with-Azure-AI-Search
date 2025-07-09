# Title

Uninformative Error Messages in Naming and URL Validation

##

/workspaces/Copilot-Studio-with-Azure-AI-Search/src/search/common_utils.py

## Problem

The error messages used in the `absolute_url` and `valid_name` functions are terse and do not include guidance on what the expected format or allowed characters are. For example:
- `"'{value}' is not a valid name"` is vague.
- `"'{value}' contains invalid characters. Look at the documentation for naming conventions."` is a bit better, but still not very actionable since the documentation may not always be at hand.

## Impact

Low. The script works, but error reporting is less friendly, especially for new users or in automation contexts where clear, actionable error messages aid troubleshooting significantly.

## Location

/workspaces/Copilot-Studio-with-Azure-AI-Search/src/search/common_utils.py

## Code Issue

```text
raise argparse.ArgumentTypeError(f"'{value}' is not a valid name")
...
raise argparse.ArgumentTypeError(f"'{value}' contains invalid characters. Look at the documentation for naming conventions.")
```

## Fix

Provide error messages that explicitly describe what is expected. For example:

```text
raise argparse.ArgumentTypeError(
    f"'{value}' is not a valid name. Names must contain only alphanumeric characters, '-', or '_', and must not be empty."
)
...
raise argparse.ArgumentTypeError(
    f"'{value}' contains invalid characters. Names must only include letters, numbers, '-', or '_'."
)
```

This guidance helps the user resolve the input issues quickly.
