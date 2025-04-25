# Copilot Studio + Azure AI Search

This repository provides a baseline architecture for integrating Copilot Studio and Power Platform with Azure AI resources. It addresses challenges in initializing and managing these connections while prioritizing enterprise readiness.

## Features

* Seamless integration of Copilot Studio with Azure AI resources.
* Enterprise-grade network configuration for secure and scalable deployments.
* Observability tools for monitoring and troubleshooting.
* Secure authentication mechanisms aligned with enterprise standards.
* Modular Terraform code structure for easy customization and reuse.
* Support for remote state management using Azure Storage.
* Automated resource tagging for better organization and cost tracking.
* Validation of input variables to ensure robust deployments.
* Pre-configured backend setup for remote state storage.
* Documentation and examples for quick onboarding and usage.

## Getting Started

### Prerequisites

To use this example, you must complete the following prerequisites:
- Set up a service principal with the permissions outlined in the [Power Platform Terraform Provider's documentation](https://microsoft.github.io/terraform-provider-power-platform/guides/app_registration/)
- Assign the Service Principal a 'Contributor' role in the Azure subscription where the resources will be created.
- Set up an interactive user to interact with the resources managed by this module.
- Ensure that the shell you use to access the example has azd installed, and if not, follow the [instructions to install azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-windows). 

### Quickstart

1. Clone this repository and open the root directory in your terminal.
1. Run the azd init command below. Pick a meaningful name for your azd environment as you will be working with it for this example.
    ```bash
    azd init
    ```
1. Set the terraform variable values needed to run the example. You can do this by editing [variables.tf](infra\variables.tf) directly, or by setting azd environment variables. Below is an example of how to set the environment variables in bash. Note that these lines are setting values in the azd .env configuration rather than the local environment variables. This is due to how Terraform searches for Terraform variables versus environment variables from within an azd container.
    ```bash
    azd env set TF_VAR_principal_secret "<your service principal secret here>"
    azd env set TF_VAR_resource_share_user "<your interactive user's object ID here>"
    ```
1. Set the azd environment to enable CLI authentication pass-through for the Azure CLI. This is required for Terraform to be able to read configured environment variables.
    ```bash
    azd config set auth.useAzCliAuth "true"
    ```
1. Run the azd login command below. Note that the solution does not currently use the azd auth context, but an auth context is required by azd.
    ```bash
    azd auth login
    ```
1. Set the values needed to run the example. You can do this by editing [variables.tf](infra\variables.tf) directly, or by setting environment variables. Below is an example of how to set the environment variables in bash.
    ```bash
    export ARM_TENANT_ID="<your tenant ID here>"
    export ARM_CLIENT_ID="<your service principal's client ID here>"
    export ARM_CLIENT_SECRET="<your service principal's client secret here>"
    export ARM_SUBSCRIPTION_ID="<your subscription ID here>"
    
    
    export POWER_PLATFORM_CLIENT_ID="<your service principal's client ID here>"
    export POWER_PLATFORM_CLIENT_SECRET="<your service principal's client secret here>"
    export POWER_PLATFORM_TENANT_ID="<your tenant ID here>"
    ```

## Demo (TBD)

A demo app is included to show how to use the project.

To run the demo, follow these steps:

(Add steps to start up the demo)

1.
2.
3.

## Resources (TBD)

(Any additional resources or related projects)

- Link to supporting information
- Link to similar sample
- ...
