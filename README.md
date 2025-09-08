# Copilot Studio with Azure AI Search

This repository offers a baseline architecture for integrating Copilot Studio and Power Platform
with Azure AI resources. The solution is designed with a strong focus on enterprise readiness and
network security.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
  - [Key Architecture Components](#key-architecture-components)
- [Account & License Requirements](#account--license-requirements)
  - [User Configuration](#user-configuration)
- [Getting Started](#getting-started)
  - [GitHub Codespaces](#github-codespaces)
  - [VS Code Dev Containers](#vs-code-dev-containers)
  - [Local Environment](#local-environment)
  - [Deploying](#deploying)
  - [Using the Bot](#using-the-bot)
  - [Clean Up](#clean-up)
- [Testing](#testing)
  - [Copilot Studio Agent Test](#copilot-studio-agent-test)
  - [AI Search Test (Optional)](#ai-search-test-optional)
- [Advanced Scenarios](#advanced-scenarios)
  - [GitHub Self-Hosted Runners](#github-self-hosted-runners)
  - [Bring Your Own Networking](#bring-your-own-networking)
  - [Custom Resource Group](#custom-resource-group)
- [Additional Considerations](#additional-considerations)
  - [Security Considerations](#security-considerations)
  - [Production Readiness](#production-readiness)
- [Resources](#resources)
- [Data Collection](#data-collection)
- [Responsible AI](#responsible-ai)
- [Getting Help](#getting-help)

## Features

- Seamless integration of Copilot Studio with Azure AI resources.
- Enterprise-grade network configuration for secure and scalable deployments.
- Observability tools for monitoring and troubleshooting.
- Secure authentication mechanisms aligned with enterprise standards.
- Modular Terraform code structure for easy customization and reuse.
- Support for remote state management using Azure Storage.
- Automated resource tagging for better organization and cost tracking.
- Validation of input variables to ensure robust deployments.
- Pre-configured backend setup for remote state storage.
- Documentation and examples for quick onboarding and usage.

## Architecture

This enterprise-ready architecture demonstrates how to securely connect Copilot Studio with Azure AI Search through a private virtual network infrastructure. The solution focuses on data security, network isolation, and compliance with enterprise governance policies.

### Key Architecture Components

**Power Platform Integration:**

- **Copilot Studio Bot**: Central conversational AI interface that processes user queries
- **AI Search Connector**: Secure connector that enables Copilot Studio to query Azure AI Search while respecting enterprise data boundaries

**Azure Infrastructure:**

- **Virtual Network (VNet)**: Provides network isolation and secure communication channels
- **Private Endpoints**: Ensures Azure AI Search and Storage Account traffic remains within the corporate network perimeter
- **Azure AI Search Service**: Indexes and searches through enterprise data with built-in AI capabilities
- **Storage Account**: Stores indexed documents and search artifacts securely

**Enterprise Security & Governance:**

- **Network Injection Policy**: Enforces that Power Platform resources communicate through designated virtual networks
- **Private Network Access**: All data flows through private endpoints, eliminating exposure to public internet

This architecture ensures that sensitive enterprise data never traverses public networks while enabling powerful AI-driven search capabilities through Copilot Studio. The network injection policy guarantees that Power Platform connectors respect corporate network boundaries, providing an additional layer of security for regulated industries.

## Account & License Requirements

**IMPORTANT:** In order to deploy and run this example, you'll need:

- **Azure subscription**. If you're new to Azure, [get an Azure account for free](https://azure.microsoft.com/free/cognitive-search/) and you'll get some free Azure credits to get started. See [guide to deploying with the free trial](docs/deploy_freetrial.md).
- **Azure EntraID App Registration**. To run the example you will have to create an App Registration and give it permissions inside Azure. Detailed configuration instructions are available in the [App Registration Setup Guide](/docs/app_registration_setup.md).

- **Power Platform**. If you are new to Power Platform and Copilot Studio, you can [get 30-day trial for free](https://www.microsoft.com/en-us/power-platform/try-free)
- **Power Platform settings**. To enable the required Copilot functionality, configure the following settings in your Power Platform tenant administration portal:
  - [**Copilot in Power Apps**](https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/ai-overview?WT.mc_id=ppac_inproduct_settings): Enable this setting to allow AI-powered assistance within Power Apps development
  - [**Publish Copilots with AI features**](https://learn.microsoft.com/en-us/microsoft-copilot-studio/security-and-governance): Allow Copilot authors to publish from Copilot Studio when AI features are enabled  
- **Power Platform licenses**. The designated user must have the following Power Platform licenses assigned:
  - **Microsoft Power Apps**
  - **Power Automate**
  - **Copilot Studio**

    To simplify license management, you can use an Azure subscription with a Billing Policy instead of assigning licenses directly. Configure this by using the following flag:

    ```shell
    azd env set USE_BILLING_POLICY "true"
    ```

    **Note:** After creating the Billing Policy, navigate to the [Power Platform Admin Center](https://aka.ms/ppac) and ensure that the *Copilot Studio* product is selected. This is a known issue that will be addressed in future updates.

### User Configuration

The following user configuration is required to interact with the Azure and Power Platform resources deployed by this solution:

**Required Roles:**

- **Contributor** or **Owner** role on the Azure subscription for managing Azure resources
- **Power Platform System Administrator** or appropriate environment-specific roles for managing Power Platform connections and Copilot Studio resources

**Access Permissions:**
Upon deployment, the configured user will be granted:

- Owner/Contributor access to the created Azure resources
- Administrative permissions for Power Platform connections
- Full access to the deployed Copilot Studio bot

**Note:** While Power Platform Administrator role provides comprehensive access, users with environment-specific administrative roles may also be sufficient depending on your organization's security requirements.

## Getting Started

You have a few options for setting up this project.
The easiest way to get started is GitHub Codespaces, since it will setup all the tools for you,
but you can also [set it up locally](#local-environment) if desired.

### GitHub Codespaces

You can run this repo virtually by using GitHub Codespaces, which will open a web-based VS Code in your browser:

[![Open in GitHub Codespaces](https://img.shields.io/static/v1?style=for-the-badge&label=GitHub+Codespaces&message=Open&color=brightgreen&logo=github)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=964739309&machine=standardLinux32gb&devcontainer_path=.devcontainer%2Fdevcontainer.json&location=WestUs2)

Once the codespace opens (this may take several minutes), open a terminal window.

### VS Code Dev Containers

A related option is VS Code Dev Containers, which will open the project in your local VS Code using the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers):

1. Start Docker Desktop (install it if not already installed)
2. Open the project:
    [![Open in Dev Containers](https://img.shields.io/static/v1?style=for-the-badge&label=Dev%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/Azure-Samples/Copilot-Studio-with-Azure-AI-Search)

3. In the VS Code window that opens, once the project files show up (this may take several minutes), open a terminal window.

### Local Environment

1. Install the required tools:

    - [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&pivots=winget) - Required for managing Azure resources and authentication
    - [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd) - Platform-specific installers available via package managers or direct download
    - [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.5) - Required for non-Windows systems; Windows users may use built-in PowerShell
    - [.NET 8.0 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0) - Includes .NET CLI, runtime, and development tools
    - [Terraform](https://developer.hashicorp.com/terraform) - HashiCorp official distribution via package manager or binary
    - [TFLint](https://github.com/terraform-linters/tflint) - Optional but recommended for infrastructure validation
    - [PAC CLI](https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction) - Microsoft Power Platform developer tooling
    - [Gitleaks](https://github.com/gitleaks/gitleaks) - Pre-commit hook integration recommended
    - [Python 3.9, 3.10, or 3.11](https://www.python.org/downloads/)
      - **Important**: Python and the pip package manager must be in the path in Windows for the setup scripts to work.
      - **Important**: Ensure you can run `python --version` from console. On Ubuntu, you might need to run `sudo apt install python-is-python3` to link `python` to `python3`.

2. Create a new folder and switch to it in the terminal.
3. Run this command to download the project code:

    ```shell
    azd init -t https://github.com/Azure-Samples/Copilot-Studio-with-Azure-AI-Search
    ```

    Note that this command will initialize a git repository, so you do not need to clone this repository.

### Deploying

The steps below will provision Azure and Power Platform resources and will deploy Copilot Studio bot.

1. Login to your Azure account and config azd to use Az CLI authentication:

    ```shell
    az login --service-principal --username <SP_CLIENT_ID> --password <SP_SECRET> --tenant <TENANT_ID>
    azd config set auth.useAzCliAuth "true"
    ```

1. Login to your Power Platform:

    ```shell
    pac auth create --name az-cli-auth --applicationId <SP_CLIENT_ID> --clientSecret <SP_SECRET> --tenant <TENANT_ID> --accept-cleartext-caching
    ```

    *Note: the `pac auth create` command may return a warning about being unable to connect to a Dataverse organization. This is expected, and will not impact the deployment.*

1. Create a new azd environment:

    ```shell
    azd env new
    ```

    This will create a new folder in the `.azure` folder, and set it as the active environment for any calls to `azd` going forward.

1. Set you internative testing user.
  
    ```shell
    azd env set RESOURCE_SHARE_USER '["entraid_user_object_id"]'
    ```

    Set this value to the Azure Entra ID object ID of the primary administrator or developer who will manage and modify the deployed solution resources in the future. This user will be granted administrative access to the Power Platform resources (such as bot ownership and environment management) and will have visibility into the Azure resources provisioned by this deployment. Replace `entraid_user_object_id` with the actual object ID of the intended admin or developer.

1. Deploy your infrastructure

    ```shell
    azd up
    ```

    This will provision all the resources including building a search index based on the .pdf files found in `data` folder.
      - You will be prompted to select a location. One of the resources is Azure OpenAI resource, which is currently available in a limited amount of regions. `East US` may be the best option for you. Check the [OpenAI model availability table](https://learn.microsoft.com/azure/cognitive-services/openai/concepts/models#model-summary-table-and-region-availability)
      - In Codespaces environments, ensure that the postCreateCommand in devcontainer.json has completed (including PAC CLI installation) before running `azd up` to avoid PAC-related errors.
      - If you encounter a 403 Unauthorized error when initializing the Terraform backend, verify that the storage account's network access settings allow traffic from your IP address. You may need to whitelist your IP or temporarily enable public access, depending on your organization's policy.

### Using the Bot

- Go to [Copilot Studio webpage](https://copilotstudio.microsoft.com/)
- In the top right corner select environment with name starting `Copilot Studio + Azure AI`
- Open the `AI Search Connection Example` agent.

### Clean Up

To clean up all the resources created by this sample:

1. Run `azd down`
2. When asked if you are sure you want to continue, enter `yes`

All the Azure and Power Platform resources will be deleted.

## Testing

This solution includes tests that validate both Copilot Studio and Azure AI Search components after deployment.

### Copilot Studio Agent Test

Located in `tests/Copilot/`, this test validates:

- **Conversation Flow**: End-to-end conversation test with the deployed agent
- **Integration**: Validation that Copilot Studio can successfully query Azure AI Search

Currently, [the Copilot Studio Client in the Agent SDK does not support the use of Service Principals for authentication](https://github.com/microsoft/Agents/blob/main/samples/basic/copilotstudio-client/dotnet/README.md#create-an-application-registration-in-entra-id---service-principal-login), and testing requires a cloud-native app registration as well as a test account with MFA turned off. The test user account must have access to the Power Platform environment containing the agent as well as access to the agent itself.

#### Running Tests After Local Deployment Execution

After a successful local deployment execution, the local .env file contains most of the information needed to run the end-to-end Copilot Studio test. Alternatively, any test input can be set directly through environment variables.

Run the commands below to execute the test after a deployment.

```bash
# Navigate to the test directory
cd tests/Copilot

export POWER_PLATFORM_USERNAME="test@username.here"
export POWER_PLATFORM_PASSWORD="passhere"
export TEST_CLIENT_ID="native-app-guid-here"

# Run tests using azd environment outputs (recommended)
dotnet test --logger "console;verbosity=detailed"
```

#### Running Tests with Manual Environment Variable Configuration

If you prefer to set environment variables manually or need to override specific values, you can configure all required variables explicitly:

```bash
# Navigate to the test directory
cd tests/Copilot

# Power Platform authentication
export POWER_PLATFORM_USERNAME="your-test-user@domain.com"
export POWER_PLATFORM_PASSWORD="your-test-password"
export POWER_PLATFORM_TENANT_ID="your-tenant-id"
export POWER_PLATFORM_ENVIRONMENT_ID="your-environment-id"

# Native client application ID
export TEST_CLIENT_ID="your-native-app-client-id"

# Copilot Studio configuration
export COPILOT_STUDIO_ENDPOINT="https://api.copilotstudio.microsoft.com"
export COPILOT_STUDIO_AGENT_ID="crfXX_agentName"

# Run the test
dotnet test --logger "console;verbosity=detailed"
```

**Important Notes:**
- The test account must have **MFA disabled** for automated authentication
- The user must have access to the Power Platform environment and the Copilot Studio agent
- Environment variables take precedence over values from azd .env files

### AI Search Test (Optional)

Located in `tests/AISearch/`, this test validates:

- **Resource Existence**: Verify all search resources (index, datasource, skillset, indexer) exist
- **Configuration Validation**: Check resource configurations match expected settings
- **Content Verification**: Validate index contains expected documents and supports search
- **Pipeline Integration**: End-to-end validation of the complete search pipeline

Because the Copilot agent end-to-end test includes indirect validation of the AI Search functionality, this test does not need to be run unless direct validation and troubleshooting of the AI Search resources is required.

#### Prerequisites for AI Search Tests

Before running AI Search tests, you must complete the following configuration:

1. **Make AI Search Endpoint Public**: Unless the test is run on the same virtual network as the AI Search resource, the AI Search service must be updated to be accessible to the test script. Configure network access in the Azure portal:
   - Navigate to your AI Search service
   - Go to **Networking** → **Firewalls and virtual networks**
   - Select **All networks** or add the test runner's IP to **Selected IP addresses**

2. **Assign RBAC Roles**: The user or service principal running the tests must have the following roles:
  - Navigate to your AI Search service in the Azure portal
  - Go to **Access control (IAM)** → **Add role assignment**
  - Select **Search Index Data Contributor** role and assign to the user or service principal that will execute the tests
  - Add another role assignment for **Search Service Contributor** role to the same user or service principal

#### Running AI Search Tests Locally

```bash
# Ensure you're authenticated and have an azd environment deployed
az login

# Run the test script
cd tests/AISearch
./run-tests.sh
```

The tests automatically discover configuration from your azd environment outputs.

## Advanced Scenarios

### GitHub Self-Hosted Runners

For organizations requiring deployment through CI/CD pipelines, this solution supports secure GitHub self-hosted runners and includes a turnkey bootstrap that provisions private Terraform remote state and a runner in Azure. The configuration emphasizes private networking (private endpoints, no public IP) and least‑privilege access for enterprise environments.

For step‑by‑step setup—including OIDC authentication, running the bootstrap workflow, capturing backend outputs, and targeting jobs to the runner—see the [CI/CD guide](/docs/cicd.md).

### Bring Your Own Networking

If your organization needs to deploy into existing virtual networks and enforce corporate routing, egress, and inspection controls, this template supports bring‑your‑own networking. You can wire services to your VNet/subnets, use private endpoints and private DNS, and keep public exposure disabled while meeting enterprise policies.

For supported topologies, prerequisites, and step‑by‑step wiring (subnet requirements, private endpoints for Azure AI Search and Storage, DNS zones, NAT/firewall egress), see the [Bring Your Own Networking guide](/docs/custom_networking.md).

### Custom Resource Group

If you need to deploy into a pre-created or centrally managed Azure resource group (to align with enterprise naming, policy, or billing), the template can target an existing resource group rather than creating a new one. This is especially useful when developers don’t have subscription-level permissions—allowing deployments to proceed with resource group–scoped access.

For prerequisites and configuration flags, see the [Custom Resource Group guide](/docs/custom_resource_group.md).

## Additional Considerations

### Security Considerations

See the [Security Considerations](./docs/security_considerations.md) guide for a concise overview of baseline controls, mitigated risks, and recommended hardening steps for production.

### Production Readiness

To avoid cost issues when validating the architecture, the default setting of the AI Search resource
is to use one partition and one replica, which is not a production-caliber configuration. If you use
this architecture in a production scenario, update the `ai_search_config` Terraform variable to configure
at least 3 partitions and replicas.

## Resources

- [Power Platform environment basics](https://learn.microsoft.com/en-us/power-platform/admin/environments-overview)
- [Copilot Studio getting started](https://learn.microsoft.com/en-us/microsoft-copilot-studio/fundamentals-get-started?tabs=web)
- [Azure AI Search resources](https://learn.microsoft.com/en-us/azure/search/)
- [Azure Developer CLI Hooks](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/azd-extensibility)

## Data Collection

The software may collect information about you and your use of the software and send it to
Microsoft. Microsoft may use this information to provide services and improve our products
and services. You may turn off the telemetry as described below. There are also some features
in the software that may enable you and Microsoft to collect data from users of your applications.
If you use these features, you must comply with applicable law, including providing appropriate
notices to users of your applications together with a copy of Microsoft’s privacy statement. Our
privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more
about data collection and use in the help documentation and our privacy statement. Your use of the
software operates as your consent to these practices.

The `partner_id` configuration in [infra/providers.tf](./infra/provider.tf) enables anonymous
telemetry that helps us justify ongoing investment in maintaining and improving this template.
Keeping this enabled supports the project and future feature development. To opt out of this
telemetry, simply remove `partner_id`. When enabled, the `partner_id` is appended to the
`User-Agent` on requests made by the configured terraform providers.

## Responsible AI

Microsoft encourages customers to review its Responsible AI Standard when developing AI-enabled
systems to ensure ethical, safe, and inclusive AI practices. Learn more at <https://www.microsoft.com/en-us/ai/responsible-ai>.

## Getting Help

This is a sample built to demonstrate the capabilities of modern Generative AI apps and how they can be built in Azure.
For help with deploying this sample, please post in [GitHub Issues](/issues).
