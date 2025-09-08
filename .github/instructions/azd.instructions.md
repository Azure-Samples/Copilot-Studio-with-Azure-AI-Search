applyTo: 'azure.yaml,azd-hooks/**'
description: 'Azure Developer CLI (azd) project and hook conventions'
---

# Azure Developer CLI (azd) Conventions

## Project Structure
- Root `azure.yaml` declares services and Terraform infra under `infra/`.
- Terraform root module uses `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`.
- Reusable Terraform modules live in `infra/modules/` with README and documented inputs/outputs.

## azd Workflow
- `azd init` to bootstrap environment and templates.
- `azd up` to provision infrastructure (Terraform) and deploy services.
- `azd down` to destroy all provisioned resources for the environment.

## Hooks and Security Scans
- Use pre-provision hooks to run repo security gates:
  - Gitleaks for secret scanning
  - Checkov for IaC security
  - TFLint for Terraform linting
- Ensure hooks run in CI and locally; fail on critical findings.

## Auth and Identity
- Prefer Microsoft Entra federated credentials (OIDC) for CI/CD auth to Azure.
- Use Service Principal authentication only where automation requires it and OIDC is not available.

## State and Tags
- Use Azure Storage remote backend for Terraform state; never store state locally in CI.
- Tag all Azure resources with `azd-env-name` and relevant metadata for org and cost tracking.

## Outputs and Bindings
- Expose required values via `outputs.tf` for downstream service bindings.
- Avoid exposing secrets in outputs; mark sensitive outputs appropriately.

## Networking and Security
- Prefer private endpoints for Azure services and VNet integration where applicable.
- Apply enterprise policies and RBAC following least privilege.

