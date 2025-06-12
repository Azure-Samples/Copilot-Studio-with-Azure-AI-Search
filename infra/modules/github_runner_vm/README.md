# GitHub Self-Hosted Runner on Azure

This Terraform configuration deploys a self-hosted GitHub Actions runner on Azure Virtual Machine within the existing VNET.



Before deploying GitHub runners, you'll need:

1. **GitHub Personal Access Token (PAT)**: Token with repository and runner permissions

### GitHub Personal Access Token Requirements

Create a GitHub Personal Access Token with the following permissions:
- **Repository permissions**:
  - `repo` (Full control of private repositories)
  - `workflow` (Update GitHub Action workflows)

### Configuring Environment Variables and Deploying Runners

**The GitHub runner is disabled by default.** To enable it, you must set `enable_vm_github_runner = true` along 
with the required GitHub configuration.

Set these environment variables for the GitHub runner deployment"

```bash
azd env set ENABLE_VM_GITHUB_RUNNER "true"
azd env set GITHUB_RUNNER_URL <your-github-repo-url>
azd env set GITHUB_RUNNER_NAME <your-github-runner-name>
azd env set GITHUB_RUNNER_TOKEN"<your-github-personal-access-token>"
azd env set GITHUB_REPO_OWNER "<your-github-username-or-org>"
azd env set GITHUB_REPO_NAME "<your-repository-name>"
azd env set GITHUB_RUNNER_GROUP "default"  # optional, defaults to "default"
```

After configuring all environment variables, the GitHub runners will be automatically deployed
using the `azd up` command. They will then be registered with your repository and appear under
*Settings > Actions > Runners* in your repository