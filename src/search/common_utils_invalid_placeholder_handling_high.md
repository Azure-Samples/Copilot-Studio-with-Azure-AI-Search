# Title

Invalid Placeholder Handling in JSON Schema Preparation

##

/workspaces/Copilot-Studio-with-Azure-AI-Search/src/search/index_utils.py

## Problem

The `_prepare_json_schema` function in `index_utils.py` replaces placeholders by doing a simple `.replace(f"{key}", values_to_assign[key])`. This will match any occurrence of the key string—potentially replacing unintended substrings throughout the JSON, which can lead to subtle bugs if a key happens to match part of some real text or configuration (for example, replacing `<data_source_name>` anywhere instead of just placeholders, or colliding with other similar-looking content).

## Impact

High. This can lead to configuration corruption and unpredictable runtime behaviors if placeholder text is not replaced exactly or too widely. It would be especially problematic in larger JSON configurations and in scenarios where similar placeholders or text exist by coincidence.

## Location

/workspaces/Copilot-Studio-with-Azure-AI-Search/src/search/index_utils.py

## Code Issue

```text
def _prepare_json_schema(
    file_name: str,
    values_to_assign: dict
) -> str:
    ...
    for key in values_to_assign.keys():
        indexer_def = indexer_def.replace(f"{key}", values_to_assign[key])
    ...
```

## Fix

Use more robust placeholder replacement (for example, `{key}` should be `<key>` if template is using angle-bracket style); consider using a regular expression to match only placeholders that are delimited properly, or use a templating engine such as `string.Template` or `jinja2` for clarity and safety. Here's a minimal fix using plain string operations for this project (preserving current expectations):

```text
import re

def _prepare_json_schema(file_name: str, values_to_assign: dict) -> str:
    with open(file_name) as indexer_file:
        indexer_def = indexer_file.read()
    for key, value in values_to_assign.items():
        # Only replace placeholders in the form of <key>
        indexer_def = re.sub(rf"<{re.escape(key.strip('<>'))}>", value, indexer_def)
    return indexer_def
```

This ensures only exact placeholder patterns like `<data_source_name>` are replaced.
