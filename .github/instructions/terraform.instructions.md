---
description: 'Terraform Conventions and Guidelines'
applyTo: '**/*.tf'
---

# Terraform Conventions

## General Instructions

- Use Terraform to provision and manage infrastructure.
- Use version control for your Terraform configurations.

## Repository-Specific Conventions

- Naming and style
  - Use snake_case for all variables, resources, modules, files, and locals.
  - Use double quotes for strings.
  - Use `#` for comments. For multi-line notes, prefer consecutive `#` lines.
  - Place one argument per line for readability.
  - Keep each resource block under 100 lines.
  - Group related resources in logical files (e.g., `main.network.tf`, `main.search.tf`).
- Structure
  - Root module should contain: `main.tf` (entry), `variables.tf`, `outputs.tf`, `providers.tf`.
  - Reusable modules live under `infra/modules/` with their own README and documented inputs/outputs.
- Dependencies and iteration
  - Prefer `for_each` over `count` when managing unique resources.
  - Use `depends_on` only when the dependency is not implied.
- Providers and versions
  - Pin provider versions using `~>` or exact versions.
  - Avoid legacy interpolation like "${var.foo}"; use `var.foo` directly.
- State and backend
  - Use Azure Storage remote backend for Terraform state. Never commit state or `.tfvars` files.
- Tagging and governance
  - Tag all Azure resources with `azd-env-name` and other cost/ownership metadata.
- Security and networking
  - Never hardcode secrets. Use Azure Key Vault references and mark variables/outputs containing secrets as `sensitive`.
  - Prefer private endpoints for Azure services and deploy resources in private subnets where possible.
  - Implement virtual network injection patterns and enterprise policies where applicable (e.g., for Power Platform connectivity).
- Azure AI Search and Power Platform
  - Use Azure AI Search with vector search and OpenAI embeddings as required by the solution architecture.
  - Use the `powerplatform` Terraform provider for environment and connection management when automating Power Platform configuration.

## Security

- Always use the latest stable version of Terraform and its providers.
  - Regularly update your Terraform configurations to incorporate security patches and improvements.
- Store sensitive information in a secure manner, such as using Azure Key Vault for secrets and Azure App Configuration for non-secret settings.
  - Regularly rotate credentials and secrets.
  - Automate the rotation of secrets, where possible.
- Use Azure Key Vault for secrets (and Azure App Configuration for non-secret settings); prefer Key Vault references and managed identities instead of embedding secret values in Terraform variables.
  - If a variable must be provided, pass it via TF_VAR_ environment variables and mark it sensitive; otherwise reference Key Vault secret IDs/URIs so values do not enter Terraform plan or state.
- Never commit sensitive information such as Azure credentials (e.g., service principal secrets), API keys, passwords, certificates, or Terraform state to version control.
  - Use `.gitignore` to exclude files containing sensitive information from version control.
- Always mark sensitive variables as `sensitive = true` in your Terraform configurations.
  - This prevents sensitive values from being displayed in the Terraform plan or apply output.
- Use Azure RBAC roles and role assignments to control access to resources.
  - Follow the principle of least privilege when assigning permissions.
- Use Network Security Groups (NSGs), Azure Firewall, and route tables to control network access to resources.
- Deploy resources in private subnets within virtual networks whenever possible.
  - Use public subnets only for resources that require inbound internet access (e.g., Application Gateway or Public Load Balancer) and prefer Azure NAT Gateway for outbound-only traffic.
- Use encryption for sensitive data at rest and in transit.
  - Enable encryption for managed disks, Azure Storage (Blob/Files), and Azure database services (e.g., Azure SQL, PostgreSQL, MySQL, Cosmos DB) as applicable.
  - Use TLS for communication between services.
- Regularly review and audit your Terraform configurations for security vulnerabilities.
  - Use tools like `trivy`, `tfsec`, or `checkov` to scan your Terraform configurations for security issues.
  - Integrate linting and policy checks (e.g., `tflint`, `checkov`) into CI and local pre-commit hooks.

## Modularity

- Use separate projects for each major component of the infrastructure; this:
  - Reduces complexity
  - Makes it easier to manage and maintain configurations
  - Speeds up `plan` and `apply` operations
  - Allows for independent development and deployment of components
  - Reduces the risk of accidental changes to unrelated resources
- Use modules to avoid duplication of configurations.
  - Use modules to encapsulate related resources and configurations.
  - Use modules to simplify complex configurations and improve readability.
  - Avoid circular dependencies between modules.
  - Avoid unnecessary layers of abstraction; use modules only when they add value.
    - Avoid using modules for single resources; only use them for groups of related resources.
    - Avoid excessive nesting of modules; keep the module hierarchy shallow.
- Use `output` blocks to expose important information about your infrastructure.
  - Use outputs to provide information that is useful for other modules or for users of the configuration.
  - Avoid exposing sensitive information in outputs; mark outputs as `sensitive = true` if they contain sensitive data.
  - Include descriptions for all variables and outputs.

## Maintainability

- Prioritize readability, clarity, and maintainability.
- Use comments to explain complex configurations and why certain design decisions were made.
- Write concise, efficient, and idiomatic configs that are easy to understand.
- Avoid using hard-coded values; use variables for configuration instead.
  - Set default values for variables, where appropriate.
- Use data sources to retrieve information about existing resources instead of requiring manual configuration.
  - This reduces the risk of errors, ensures that configurations are always up-to-date, and allows configurations to adapt to different environments.
  - Avoid using data sources for resources that are created within the same configuration; use outputs instead.
  - Avoid, or remove, unnecessary data sources; they slow down `plan` and `apply` operations.
- Use `locals` for values that are used multiple times to ensure consistency.
  - Avoid null/default anti-patterns; set explicit defaults where appropriate.

## Style and Formatting

- Follow Terraform best practices for resource naming and organization.
  - Use descriptive names for resources, variables, and outputs.
  - Use consistent naming conventions across all configurations.
- Follow the **Terraform Style Guide** for formatting.
  - Use consistent indentation (2 spaces for each level).
  - Run `terraform fmt` consistently as part of CI and local workflows.
- Group related resources together in the same file.
  - Use a consistent naming convention for resource groups (e.g., `providers.tf`, `variables.tf`, `network.tf`, `app_service.tf`, `postgresql.tf`).
- Place `depends_on` blocks at the very beginning of resource definitions to make dependency relationships clear.
  - Use `depends_on` only when necessary to avoid circular dependencies.
- Place `for_each` and `count` blocks at the beginning of resource definitions to clarify the resource's instantiation logic.
  - Use `for_each` for collections and `count` for numeric iterations.
  - Place them after `depends_on` blocks, if they are present.
- Place `lifecycle` blocks at the end of resource definitions.
- Alphabetize providers, variables, data sources, resources, and outputs within each file for easier navigation.
- Group related attributes together within blocks.
  - Place required attributes before optional ones, and comment each section accordingly.
  - Separate attribute sections with blank lines to improve readability.
  - Alphabetize attributes within each section for easier navigation.
- Use blank lines to separate logical sections of your configurations.
- Use `terraform fmt` to format your configurations automatically.
- Use `terraform validate` to check for syntax errors and ensure configurations are valid.
- Use `tflint` to check for style violations and ensure configurations follow best practices.
  - Run `tflint` regularly to catch style issues early in the development process.

## Documentation

- Always include `description` and `type` attributes for variables and outputs.
  - Use clear and concise descriptions to explain the purpose of each variable and output.
  - Use appropriate types for variables (e.g., `string`, `number`, `bool`, `list`, `map`).
- Document your Terraform configurations using comments, where appropriate.
  - Use comments to explain the purpose of resources and variables.
  - Use comments to explain complex configurations or decisions.
  - Avoid redundant comments; comments should add value and clarity.
- Include a `README.md` file in each project to provide an overview of the project and its structure.
  - Include instructions for setting up and using the configurations.
- Use `terraform-docs` to generate documentation for your configurations automatically.
  - Root and module READMEs should document required tags (including `azd-env-name`) and any network/security assumptions (private endpoints, VNet requirements).

## Testing

- Write tests to validate the functionality of your Terraform configurations.
  - Use the `.tftest.hcl` extension for test files.
  - Write tests to cover both positive and negative scenarios.
  - Ensure tests are idempotent and can be run multiple times without side effects.