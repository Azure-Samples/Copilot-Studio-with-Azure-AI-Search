# Continuous Integration and Delivery (CI/CD)

This guide shows how to bootstrap secure, enterprise-ready CI/CD for this template using GitHub Actions, Terraform remote state on Azure Storage, and an optional self-hosted GitHub runner. It builds on the same tone and security posture as the main README: private networking by default, least-privilege access, and repeatable automation.

## What you’ll set up

- Remote Terraform state in a private Azure Storage account (no public endpoints)
- A dedicated virtual network and private endpoint for the state account
- A GitHub Actions self-hosted runner on Azure (VM-based by default)
- GitHub repository variables that your workflows can consume

All infrastructure for CI/CD lives under `cicd/` and can be customized to meet your organization’s policies.

## Prerequisites

- A fork or copy of this repo where you’ll enable CI/CD
- An Azure subscription and permissions to create resource groups, VNet, Storage, and compute
- GitHub OIDC (workload identity) configured to authenticate to Azure (recommended)
  - Create or use an Azure Entra app registration
  - Add a federated credential for your GitHub repository
    - Expose the following repository variables so workflows can log in with OIDC:
      - `AZURE_CLIENT_ID`
      - `AZURE_TENANT_ID`
      - `AZURE_SUBSCRIPTION_ID`
    - See Microsoft docs: “Authenticate to Azure in GitHub Actions using OpenID Connect”
- Optional: GitHub CLI (`gh`) to trigger the bootstrap workflow from your terminal

## Step 1 — Get a GitHub runner token

You’ll register a self-hosted runner to your repository. Generate a short-lived registration token:

```bash
gh api -X POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" repos/:owner/:repo/actions/runners/registration-token --jq '.token'
```

Alternatively you can get it manually by:

1. Go to your repo in GitHub
2. Settings > Actions > Runners > New self-hosted runner
3. Copy the runner “registration token” (you’ll pass it to the workflow below)

## Step 2 — Run the bootstrap workflow

This repo includes a workflow that provisions CI/CD infrastructure using Terraform in `cicd/`:

- File: `.github/workflows/setup-remote-state.yml`
- Inputs: `location` (Azure region, default `westus2`), `github_runner_registration_token` (from Step 1)

Trigger it with GitHub CLI (example uses the current repo):

```bash
gh workflow run .github/workflows/setup-remote-state.yml -f github_runner_registration_token=<YOUR_RUNNER_TOKEN>
```

What this workflow does:

- Logs into Azure using OIDC and your repository variables
- Runs `terraform init/plan/apply` in `cicd/`
- Creates a resource group, a private Storage account, a private endpoint, and a `tfstate` container
- Creates a dedicated subnet and NAT gateway for a self-hosted runner
- Provisions a Linux VM and installs a GitHub Actions runner using your token
- Registers the runner at repo scope with labels including `self-hosted`
- Prints useful Terraform outputs (remote state details) at the end of the run

## Step 3 — Capture Terraform outputs and set repo variables

From the workflow’s “Terraform Output” step, note these values and save them as repository variables for your workflows:

- `RS_STORAGE_ACCOUNT`: Storage account name for Terraform state
- `RS_RESOURCE_GROUP`: Name of the resource group that contains the Storage account
- `RS_CONTAINER_NAME`: Name of the Storage container (defaults to `tfstate`)

If your workflows are authored to use remote state variables, set them to the values that were just provisioned.

To direct jobs to the new runner, set a repo variable used by your workflows for `runs-on` selection, for example:

- `ACTIONS_RUNNER_NAME`: set to `['self-hosted']` (JSON array syntax) to target any self-hosted runner

Note: The runner VM registers with labels like `self-hosted,vm,<resource-group>,<location>,<unique-id>`. You can narrow job placement further by including those additional labels in your `runs-on` matrix if desired.

## Step 4 — Validate the runner and networking

- In GitHub: Settings > Actions > Runners — verify the runner is “Online”
- In Azure: Confirm the CI/CD resource group exists and contains:
  - Storage account with public network access disabled and a private endpoint
  - Virtual network, subnets, and NAT gateway for controlled egress
  - Linux VM for the runner (no public IP)

## Step 5 — Use azd with your pipelines

When your runner is online, you can configure application pipelines with Azure Developer CLI. For example, run `azd pipeline config` locally to scaffold pipeline settings for your repo and environment. Your workflows can then use your self-hosted runner by referencing the variable you set above for `runs-on`.

## Backend configuration (reference)

You can plug the Terraform backend outputs into other modules. A generic example:

```hcl
terraform {
 backend "azurerm" {
  storage_account_name = "sttfstate<random>"
  container_name       = "tfstate"
  key                  = "terraform.tfstate"
  resource_group_name  = "rg-tfstate-<random>"
  subscription_id      = "<your-subscription-id>"
  use_azuread_auth     = true
 }
}
```

## Customize the CI/CD infrastructure

The `cicd/` Terraform is modular and designed for enterprise networks:

- Private networking first: Storage uses private endpoint and private DNS
- Least-privilege RBAC for Storage operations (no shared keys)
- NAT gateway egress for the runner VM; no inbound public IP
- Diagnostic logging to Log Analytics

Runner options:

- VM-based runner (default): Opinionated install script with Docker, Azure CLI, .NET 8, PowerShell, Terraform, and GitHub CLI
- Azure Container Apps runner (advanced): A module exists under `cicd/github_runner_aca/` for containerized runners and KEDA-based autoscaling; wire-up is optional and can be enabled later if your policies require it

Adjust variables and modules in `cicd/` to match your network, tagging, and scaling needs.

## Cleanup

The CI/CD Terraform state is not persisted for day-two operations on these bootstrap resources. To remove the environment:

- Delete the CI/CD resource group in Azure that contains the runner, VNet, and Storage
- In GitHub: Settings > Actions > Runners — remove the self-hosted runner entry

This returns your repo to using GitHub-hosted runners unless you keep other self-hosted runners configured.

## Customization

- Review your organization’s policies for OIDC trust, private DNS, and egress controls and adjust the `cicd/` Terraform accordingly
