# Continuous Integration and Delivery (CI/CD)

This guide shows how to bootstrap secure, enterprise-ready CI/CD for this template using GitHub Actions, Terraform remote state on Azure Storage, and an optional self-hosted GitHub runner. It builds on the same tone and security posture as the main README: private networking by default, least-privilege access, and repeatable automation.

## What you’ll set up

- Remote Terraform state in a private Azure Storage account (no public endpoints)
- A dedicated virtual network and private endpoint for the state account
- A GitHub Actions self-hosted runner on Azure (VM-based by default)
- GitHub repository variables that your workflows can consume

All infrastructure for CI/CD lives under `cicd/` and can be customized to meet your organization’s policies.

## Prerequisites

- Working local environment of this template. If you do not have one, Follow the step by step instructions for setting up your [**Local Environment**](../README.md#local-environment).
- An Azure subscription with either User Access Administrator or Owner permissions to create workload identity resources like service principal, and OIDC to be used by the GitHub Actions.
- GitHub CLI (`gh`) installed and authenticated to trigger the bootstrap workflow from your terminal.

## Step 1 — Create your GitHub repo

This is the GitHub repo where your code will be hosted and actions executed. Use the following commands to create a GitHub repo using gh cli.

```shell
# To create a public repo, You can set --private if you wish to make you repo private.
gh repo create YOUR_REPO_OWNER/YOUR_REPO_NAME --public

```

Alternatively you can create the GitHub Repo manually by following [Github Documentation steps here]( https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)

## Step 2 — Get a GitHub runner token

You’ll register a self-hosted runner to your repository. Generate a short-lived registration token:

```shell
# Capture short-lived registration token (expires in ~60 minutes)
RUNNER_TOKEN=$(gh api -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  repos/:YOUR_REPO_OWNER/:YOUR_REPO_NAME/actions/runners/registration-token \
  --jq '.token')

# Optional: confirm you received a token (prints first 8 chars)
echo "Token acquired: ${RUNNER_TOKEN:0:8}********"

# Pass the token to Terraform via environment variable (preferred; never write to files)
export TF_VAR_github_runner_registration_token="$RUNNER_TOKEN"

```

Alternatively you can get it manually by:

1. Go to your repo in GitHub
2. Settings > Actions > Runners > New self-hosted runner
3. Copy the runner “registration token” (you’ll pass it to the workflow below)

## Step 3 — Create the Terraform backend configuration resources and GitHub private runner

This repo includes Terraform code in `cicd/` to create the resources needed for remote state and a private runner for GitHub. [Follow the step by step instructions](../cicd/README.md) to create and configure the needed resources.

- Files at: `.\cicd`
- Inputs: `location` (Azure region, default `westus2`), `github_runner_registration_token` (from Step 1)

What this terraform code does:

- Creates a resource group, a private Storage account, a private endpoint, and a `tfstate` container
- Creates a dedicated subnet and NAT gateway for a self-hosted runner
- Provisions a Linux VM and installs a GitHub Actions runner using your token
- Registers the runner at repo scope with labels including `self-hosted`
- Prints useful Terraform outputs (remote state details) at the end of the run
  
## Step 5 — Configure your GitHub repo

In this step your github repo gets updated with all the needed variables, configurations, workflows, and the code is pushed for you initial commit using azd.

```shell
azd pipeline config  --auth-type federated --provider github
```

The command will walk you through setup steps and prompt you for needed values, such as the following:
  How would you like to configure your git remote to GitHub?
    Choose an existing GitHub repository, Select the newly created GitHub repo.
  
  Select how to authenticate the pipeline to Azure
    Federated Service Principal (SP + OIDC)

## Step 6 — Validate the runner and networking

- In GitHub:
  - Settings > Actions > Runners — verify the runner is “Online”
  - Settings > Secrets and variables > Actions — verify the variables section contains the following [ACTIONS_RUNNER_NAME, AZURE_CLIENT_ID, AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID, RESOURCE_SHARE_USER, RS_CONTAINER_NAME, RS_RESOURCE_GROUP, RS_STORAGE_ACCOUNT]
- In Azure: Confirm the CI/CD resource group exists and contains:
  - Storage account with public network access disabled and a private endpoint
  - Virtual network, subnets, and NAT gateway for controlled egress
  - Linux VM for the runner (no public IP)
  
Now you have completed the needed steps for your own repo. Now start your collaboration and expand your repo.

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
- In GitHub:
  - Settings > Actions > Runners — remove the self-hosted runner entry.
  - Settings > Secrets and variables > Actions — Clear the value of ACTIONS_RUNNER_NAME variable to let runners use default runners.

This returns your repo to using GitHub-hosted runners unless you keep other self-hosted runners configured.

## Customization

- Review your organization’s policies for OIDC trust, private DNS, and egress controls and adjust the `cicd/` Terraform accordingly
