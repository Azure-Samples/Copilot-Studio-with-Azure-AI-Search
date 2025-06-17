# Title

YAML Data Files Lack Schema/Validation Enforcement

##

/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.AISearchConnectionExampleAzureAISearch_XHYhN5MyP7X87NpYSV1Pd/data
/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.ConversationStart/data
/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.EndofConversation/data
/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.Escalate/data
/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.Fallback/data
/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.MultipleTopicsMatched/data
/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.OnError/data
/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.ResetConversation/data
/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.Search/data
/src/powerplatform/copilot_studio_gold_agent/botcomponents/crf6d_aiSearchConnectionExample.topic.Signin/data

## Problem

There is no explicit schema reference, versioning, or schema validation mechanism present in any of the YAML `data` files for bot topics/dialogs. This means that accidental typos, missing required properties, or unsupported fields could go undetected, making the bot configuration error-prone and hard to validate during development or deployment.

Best practice is to add schema version information, and/or automated schema validation hooks (either in comments, file header, or as a CI/CD process) for maintainability and error prevention.

## Impact

High. Lack of schema enforcement may lead to runtime breaking changes, hard-to-trace bugs, or unintentional misconfigurations that impact the bot's production operation.

## Location

All topic YAML data files listed above.

## Code Issue

```yaml
# Absence of schema reference or enforced schema version:
kind: AdaptiveDialog
...
```

## Fix

Where supported, provide YAML schema references or document the schema version at the top of the file, e.g.:

```yaml
# yaml-language-server: $schema=https://path.to/dialog.schema.json
kind: AdaptiveDialog
...
```

Alternatively, maintain an external schema or validation job as a part of your build process to ensure consistent validation and early detection of structural/configuration errors across all dialog YAML files.
