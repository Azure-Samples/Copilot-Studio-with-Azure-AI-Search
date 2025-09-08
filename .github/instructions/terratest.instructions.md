applyTo: '**/*_test.go'
description: 'Terratest Best Practices for Azure and Power Platform'
---

# Terratest Best Practices (Azure + Power Platform)

- Keep tests small and focused: one deployment scenario per `Test*` function with descriptive names.
- Organize tests by module/domain (e.g., networking, identity, search) to improve clarity.
- Isolate infrastructure per test: use unique resource groups or environments; never share Terraform state.
- Use unique names: append random suffixes (`random.UniqueId`) to avoid collisions.
- Always clean up: `defer terraform.Destroy(...)` even when assertions fail.
- Prefer retries over sleeps: use `retry.DoWithRetry` to poll for eventual consistency.
- Run tests in parallel when safe: `t.Parallel()` for independent tests.
- Assert outputs and resource state using Azure SDK/CLI validation where practical.
- Use Terratest defaults for init/apply/destroy error handling.
- Factor shared setup/teardown/validation helpers into common packages to keep tests DRY.

## Azure-specific guidance
- Use short-lived/ephemeral test subscriptions or resource groups; tag with `azd-env-name` and test metadata.
- Avoid public exposure: prefer private endpoints, private subnets, and secure networking defaults.
- Use managed identity or OIDC-based auth where possible; avoid embedding credentials in test code.

## Power Platform-specific guidance
- Use robust retry with exponential backoff for solution deployment and connection setup.
- Separate environment provisioning from solution import to reduce flakiness and timeouts.
- Parameterize PAC CLI inputs via environment variables; avoid reading secrets from files.
