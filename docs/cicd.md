# Configuring CICD

To use this template with github workflows, you need to configure remote state 
we recommend that for security the terraform state is not exposed on a public endpoint
to make it easy to setup, there is a prebuilt github workflow to deploy the cicd infrastructure

This assumes that you've already followed the getting started instructions and are working in your own repo

Next steps:

* configure OIDC so that service principal has a workload identity and claims for this repo (recommended)
* generate a new runner registration token at your repo's settings > Actions > Runners > New Runner
* `gh workflow run .github/workflows/setup-remote-state.yml --repo Azure-Samples/Copilot-Studio-with-Azure-AI-Search -f runner_token=XXX`
* run `azd pipeline config`

Implementation Details:

The terraform configuration for the remote state storage account, cicd networking, and github runners is located at /cicd.  Those configurations can be further customized for your own enterprise requirements.  They are a reasonable starting point for many enterprise scenarios, but like everything in this template please customize to meet your own requirements.

The terraform state for the CICD infrastructure is not preserved.  To destroy the runner that you provision, you will need to manually delete the resource group in Azure and remove the runner in GitHub repo settings. 