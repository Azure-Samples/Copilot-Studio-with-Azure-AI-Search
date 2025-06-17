# Title

Redundant Logger Handlers Can Cause Duplicate Log Entries

##

/workspaces/Copilot-Studio-with-Azure-AI-Search/src/search/index_utils.py

## Problem

The logging setup at the top of `index_utils.py` unconditionally adds a `StreamHandler` to the logger. If this module is imported elsewhere (as opposed to only being run as a main script), or if the main script is executed multiple times in some odd interactive environment, this can lead to multiple handlers being attached to the same logger. That produces duplicate log lines because all handlers execute.

## Impact

Low. Unlikely to affect most script runs, but can produce annoying output if this module is imported elsewhere, or if it is run more than once in a persistent environment.

## Location

/workspaces/Copilot-Studio-with-Azure-AI-Search/src/search/index_utils.py

## Code Issue

```text
logger = logging.getLogger(__name__)
...
console_handler = logging.StreamHandler()
...
logger.addHandler(console_handler)
```

## Fix

Check if the logger already has handlers before adding a new handler:

```text
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
if not logger.hasHandlers():
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
```

This prevents adding duplicate handlers.
