# Broken Link to infra/providers.tf

##

/workspaces/Copilot-Studio-with-Azure-AI-Search/README.md

## Problem

There is a hyperlink in the "Data Collection" section labeled as `infra/providers.tf`, but the actual link directs to `./infra/provider.tf` (singular), not matching the filename referenced in the text. This could confuse or inconvenience readers who try to follow this link for further information or configuration context.

## Impact

Low: While not critical to execution, this mistake reduces documentation professionalism and frustrates users trying to quickly reference another file. It can also hinder onboarding for new contributors.

## Location

Last section, "## Data Collection"

## Code Issue

```
The `partner_id` configuration in [infra/providers.tf](./infra/provider.tf) enables anonymous
telemetry that helps us justify ongoing investment in maintaining and improving this template.
```

## Fix

Update the link to match the referenced filename:

```
The `partner_id` configuration in [infra/providers.tf](./infra/providers.tf) enables anonymous
telemetry that helps us justify ongoing investment in maintaining and improving this template.
```
