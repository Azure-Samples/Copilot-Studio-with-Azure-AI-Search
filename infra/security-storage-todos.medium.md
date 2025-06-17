# Weak Storage Account Security and Leftover TODOs

##
/workspaces/Copilot-Studio-with-Azure-AI-Search/infra/main.storage.tf

## Problem

Several insecure defaults are configured for the storage account module in `/main.storage.tf`, such as:
- `shared_access_key_enabled = true`
- `public_network_access_enabled = true`
- `allow_nested_items_to_be_public = true`
- Container `public_access = "Blob"`

Each of these is explicitly marked with a `TODO` to restrict or harden the setting once multi-pass deployment or refactoring is added.
However, as checked-in, the configuration allows blob-level public access. This is best practice only for temporary development and not for production.

## Impact

- Storage may be publicly accessible, leaking data or credentials.
- Shared keys may be active and a target for credential theft/abuse.
- Reduces the security posture of the deployment by default.
- If left uncorrected, this can result in serious risk in real deployments (especially if TODOs are missed).

**Severity: Medium**

## Location

- /infra/main.storage.tf (module "storage_account_and_container")

## Code Issue

```text
  shared_access_key_enabled       = true # TODO turn this off once 2-pass deployment and config is added
  public_network_access_enabled   = true # TODO turn this off once 2-pass deployment and config is added
  allow_nested_items_to_be_public = true # TODO turn this off once 2-pass deployment and config is added
  ...
      public_access = "Blob" # TODO restrict access once 2-pass deployment and config is added
```

## Fix

- Set all insecure boolean options to `false` by default (unless in a clearly demo/dev-only module or explicitly gated by variable flag for ephemeral sandbox usage only).
- Remove or surface all security-impacting TODOs in documentation/readme or deployment gating logic.
- Review for security best practices and update config:

```text
  shared_access_key_enabled       = false
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  ...
      public_access = "None"
```

- If you intend to support dynamic changes at deploy/runtime, use variable toggles with clear prompts or README documentation warning about the risks.
