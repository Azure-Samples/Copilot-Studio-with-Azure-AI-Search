# Copilot Instructions

## Coding Guidelines

### Terraform Best Practices

- Use `snake_case` for all variable, resource, and module names.
- Use double quotes (`"`) for strings, not single quotes.
- Use `#` for for both single-line and multi-line comments, not `//` or `/* ... */`.
- Place one argument per line for readability.
- Always include a `description` for variables and outputs.
- Use `locals` to define computed values or constants.
- Prefer `for_each` over `count` when managing unique resources.
- Use `terraform fmt` to enforce consistent formatting.
- Group related resources together in logical files.
- Keep resource blocks under 100 lines each.
- Use modules to encapsulate reusable code.
- Use `main.tf`, `variables.tf`, `outputs.tf`, and `locals.tf` to organize root modules.
- Use explicit types in `variable` blocks.
- Avoid hardcoding values; use variables or locals instead.
- Use `depends_on` only when dependency is not implied.
- Avoid interpolations like `"${var.foo}"`; use `var.foo` directly.
- Always pin provider versions using `~>` or exact versions.
- Avoid using data sources for static values.
- Use backend configuration blocks for remote state setup.
- Add tags to all resources that support them.
- Validate inputs using `validation` blocks in variables.
- Prefer `compact`, `merge`, and `flatten` over manual list iteration.
- Avoid mixing resource creation and data fetching in a single module.
- Use meaningful resource names, not just "this" or "example".
- Document every module with a `README.md`.
- Use `terraform-docs` to generate module documentation.
- Avoid null/default patterns by setting default values explicitly.
- Prefer smaller modules over large monolithic ones.
- Mark variables and outputs containing secrets as `sensitive` to prevent accidental exposure in logs or Terraform state.
- Use lifecycle rules like `create_before_destroy` with caution.
- Never store secrets in plain text in `.tf` files.
- Do not commit `.tfstate`, `.tfvars`, or `.terraform/` folders.

## Testing

### Terratest Best Practices for Azure and Power Platform (Test Coding Only)

- **Keep tests small and focused** – one deployment scenario per test function with a clear, descriptive name.
- **Organize test files by module or domain** – e.g., networking, compute, identity – to improve clarity and maintainability.
- **Isolate infrastructure for each test** – use separate Azure resource groups or Power Platform environments. Never share Terraform state between tests.
- **Use unique resource names** – append a random suffix using `random.UniqueId` or similar to avoid name collisions.
- **Always clean up test resources** – use `defer terraform.Destroy(...)` to ensure cleanup runs regardless of test success or failure.
- **Prefer retries over sleep** – use `retry.DoWithRetry` to poll for eventual consistency (e.g., waiting for DNS propagation or resource readiness).
- **Run tests in parallel** – mark test functions with `t.Parallel()` if they don’t share state or resources.
- **Assert outputs and infrastructure state** – use `assert` statements or Azure SDK/CLI validation to confirm resources match expectations.
- **Use Terratest’s default error-handling methods** – use `terraform.Init`, `Apply`, etc., which automatically fail on error unless custom handling is needed.
- **Modularize shared logic** – extract common setup, teardown, and verification code into helper functions for DRY, maintainable test suites.

## Azure Best Practices

- @azure Rule - Use Azure Best Practices: When generating code for Azure, running terminal commands for Azure, or performing operations related to Azure, invoke your `azure_development-get_best_practices` tool if available

## AZD Template Repo Structure (Terraform)

This project structure is typical for Azure Developer CLI (`azd`) templates using **Terraform** for infrastructure provisioning.

## Directory Structure

```plaintext
/
├── .azure/                  # Optional: Local azd environment configuration (e.g., config.json)
├── infra/                   # Terraform IaC code for provisioning Azure resources
│   ├── main.tf              # Terraform root module (entry point)
│   ├── variables.tf         # Input variables used by the module
│   ├── outputs.tf           # Output values for azd service bindings
│   └── providers.tf         # Provider and backend configuration
├── src/                     # Source code for the Power Platform solution
├── azure.yaml               # azd project manifest: defines infra, services, and deployment behavior
├── .gitignore               # Standard Git ignore rules
└── README.md                # Overview and usage instructions
```

## Key Files and Purpose

| File/Folder         | Purpose                                                                 |
|---------------------|-------------------------------------------------------------------------|
| `azure.yaml`        | Declares the services and infrastructure backend (e.g., `terraform`).   |
| `infra/`            | Contains all Terraform configuration files.                             |
| `main.tf`           | Main entry point for infrastructure definitions.                        |
| `outputs.tf`        | Outputs used by `azd` to bind environment variables to app services.     |
| `variables.tf`      | Parameters to customize deployments (e.g., location, resource names).    |
| `providers.tf`      | Provider setup and optional remote state configuration.                 |
| `src/`              | One or more services defined under `azure.yaml`.                         |

## ⚙️ AZD Workflow

```bash
azd init             # Initialize project using this template
azd up               # Provision infra via Terraform and deploy app services
azd down             # Destroy all provisioned resources
```

## 📘 Best Practices

- Store reusable Terraform modules in `/infra/modules/` if needed.
- Use remote state (e.g., Azure Storage backend) to avoid local state file conflicts.
- Use `outputs.tf` to export values required by `azd` to deploy and configure services.
- Reference service-level variables via `${azurerm_...}` resources in outputs for app service bindings.
