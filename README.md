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

## Architecture

This architecture deploys the 40+ Azure and Power Platform resources required to set up a basic AI Search endpoint and query the resource through a Copilot Studio agent. The most novel parts of this architecture are included in the diagram below.

```mermaid
---
config:
  theme: dark
  look: handDrawn
  width: 1000
  height: 600
---
graph
  subgraph CopilotStudio["Copilot Studio"]
      H[Copilot Studio agent]
  end

  subgraph PowerPlatform["Power Platform"]
    B[Environment]
    D[OpenAI Connection]
    W[AI Search Connection]
  end

  subgraph Azure["Azure"]
    L[Enterprise Policy: Network Injection]
    subgraph VirtualNetwork["Virtual Network"]
        direction TB
        U[OpenAI Resource]
        T[AI Search Resource]
    end
  end

  H --> B
  H --> D
  H --> W
  D --> U
  W --> T
  B --> L
  L --> VirtualNetwork
```

## Getting Started

### Prerequisites

To use this example, you must complete the following prerequisites:
- Set up a service principal with the permissions outlined in the [Power Platform Terraform Provider's documentation](https://microsoft.github.io/terraform-provider-power-platform/guides/app_registration/)
- Ensure that 'Grant Admin Consent' has been performed on all delegated permissions for the Service Principal.
- Assign the Service Principal a 'Contributor' role in the Azure subscription where the resources will be created.
- Set up an interactive user to interact with the resources managed by this module.
- Both the Service Principal and the interactive user must have the Power Platform Admin role assigned to them in the M365 Admin Center.
- The interactive user needs licenses assigned for Microsoft Power Apps, Power Automate, and Copilot Studio in the M365 Admin Center.
- Ensure that the shell you use to access the example has azd installed, and if not, follow the [instructions to install azd](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-windows). 

### Quickstart

This solution can be executed using a service principal or a user account. Guidance for both options is provided below.

#### Service Principal

1. Clone this repository and open the root directory in your terminal.
1. Run the azd init command below. Pick a meaningful name for your azd environment as you will be working with it throughout this example.
    ```bash
    azd init
    ```
1. Set the terraform variable values needed to run the example. You can do this by editing [variables.tf](infra\variables.tf) directly, or by setting azd environment variables. Below is an example of how to set the environment variables in bash. Note that these lines are setting values in the azd .env configuration rather than the local environment variables. This is due to how Terraform searches for Terraform variables versus environment variables from within an azd container.
    ```bash
    azd env set TF_VAR_principal_secret "<your service principal secret here>"
    azd env set TF_VAR_resource_share_user "<your interactive user's object ID here>"
    ```
1. Run the azd login command below. Note that an auth context is required by azd, but is not used in the default solution configuration. If prompted to select an azure region, consider using East US, as other regions may have compatibility issues.
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
1. Disable CLI authentication for the Power Platform provider in the dev container.
    ```bash
    export "POWER_PLATFORM_USE_CLI"="false"
    ```
1. Run the azd up command below to deploy the example. This will create a new resource group in your Azure subscription and deploy the resources defined throughout the infra directory. Note that region constraints may apply to the resources you are deploying. The example is set to deploy in the East US region by default due to these constraints, but you can experiment with other regions by changing the value of the `location` variable in [variables.tf](infra\variables.tf).
    ```bash
    azd up
    ```

#### User Account

1. Clone this repository and open the root directory in your terminal.
1. Run the az login command below and sign in with your user account.
    ```bash
    az login
    ```
1. Run the azd init command below. Pick a meaningful name for your azd environment as you will be working with it throughout this example.
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
1. Run the azd login command below. Note that the solution does not currently use the azd auth context, but an auth context is required by azd. If prompted to select an azure region, consider using East US, as other regions may have compatibility issues.
    ```bash
    azd auth login
    ```
1. Run the azd up command below to deploy the example. This will create a new resource group in your Azure subscription and deploy the resources defined throughout the infra directory. Note that region constraints may apply to the resources you are deploying. The example is set to deploy in the East US region by default due to these constraints, but you can experiment with other regions by changing the value of the `location` variable in [variables.tf](infra\variables.tf).
    ```bash
    azd up
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
