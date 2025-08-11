# Automate custom scripts execution during VNET deployment

## Document Structure

This document provides a technical comparison of multiple approaches for executing custom scripts during or immediately after secure infrastructure deployment. Public resources often lack detailed explanations of these methods, and the optimal choice may depend on your specific requirements and experience. Instead of presenting a simple decision table, we offer an in-depth overview of each option, highlighting their technical details, advantages, and disadvantages. Recommendations are summarized in the final section to help guide your selection.

## Introduction

Using a Virtual Network (VNET) in the cloud is essential for establishing a secure and scalable network environment. When infrastructure deployment scripts, such as those written in Terraform or Bicep, are used, all components can be configured to operate within the VNET and remain inaccessible from unauthorised public computers, regardless of user permissions for collaborating with deployed services. If deployment scripts create the VNET during deployment, the compute initiating the process may lack access to VNET resources since it isn't part of the newly created VNET.

For example, if we deploy a VNET and a virtual machine that is a part of the VNET it’s possible to initiate deployment process in a GitHub workflow using a GitHub-hosted runner, but the runner will not have access to the VM after the deployment. This behaviour is anticipated; however, it may present challenges when executing custom scripts within newly created infrastructure as part of the deployment process.

As an illustration, consider the Azure AI Search service, which can be deployed without exposure to public networks. However, it may be necessary to execute a Python script on top of the infrastructure to create artifacts such as an index, indexer, or skillset. This document outlines several approaches for accomplishing this task, assuming Terraform is used for deployment and GitHub runners are employed to initiate the process. We are going to illustrate three methods here:

- The Azure Deployment Script enables the execution of CLI, PowerShell, or Python code during the deployment process and can be initiated from any location.
- The Azure VM Custom Script Extension provides the capability to start a bash script on a selected VM within a VNET during deployment. This script may perform various commands or configure the VM as a GitHub private runner, supporting the execution of additional steps in a GitHub workflow with access to VNET resources.
- An Azure Container Application can also be deployed within a VNET and set up as a GitHub private runner. Azure Kubernetes Service (AKS) can be used as an alternative to Azure Container Apps (ACA), but it typically involves greater knowledge and ongoing maintenance. Therefore, the AKS option is not being evaluated in this context.

The following sections will review these options individually and provide a comparative analysis at the conclusion of the document.

## Option 1. Using Azure Deployment Scripts

Azure Deployment Scripts are a powerful feature within Azure Resource Manager (ARM) templates that enable users to execute custom scripts such as PowerShell, Bash or Python code during the deployment of Azure resources. This can be utilized with Bicep or Terraform for basic configuration tasks, and it is also capable of running complex Python workloads if all dependencies are installed via pip.

Azure Deployment Scripts are built upon the Azure Container Instance service, enabling automated deployment of a service instance, execution of specified code, and subsequent deletion of the instance to ensure resource cleanup. For Virtual Networks (VNET), users can specify a subnet ID for the instance as well as a storage account needed by the deployment script to store its state. This configuration allows code execution within a VNET environment, providing access to all associated resources. Users are unable to specify a custom image when creating the ACI instance, which limits compatibility with some technologies. However, with Python, it is possible to run `pip install` before executing code, allowing all necessary dependencies to be installed for successful operation.

A sample of using Azure Deployment Script to run Python for creating Azure AI Search artifacts is in the [following repository](https://github.com/Azure-Samples/Copilot-Studio-with-Azure-AI-Search/blob/main/infra/main.search_configuration.tf); here, we focus on Terraform implementation steps.

In order to have access to all latest features in Azure Deployment Script we would recommend to use AzAPI provider:

```hcl
azapi = {
    source = "Azure/azapi"
    version = "~>2.0"
}
```

After defining the provider, configure the required infrastructure components, beginning with the subnet:

```hcl
resource "azurerm_subnet" "main" {
 name                 = "main-subnet"
 resource_group_name  = azurerm_resource_group.example.name
 virtual_network_name = azurerm_virtual_network.main.name
 address_prefixes     = ["10.10.1.0/24"]
 service_endpoints    = ["Microsoft.Storage"]
 delegation {
  name = "aci-delegation"
  service_delegation {
   name = "Microsoft.ContainerInstance/containerGroups"
   actions = [
    "Microsoft.Network/virtualNetworks/subnets/action"
   ]
  }
 }
}
```

Please ensure that the subnet is configured to delegate permissions to Azure Container Instances (ACI), which is necessary for successfully creating and integrating an ACI instance into the virtual network (VNET).

Next, create a storage account for the Azure Deployment Script. The easiest way is to create an account that blocks all traffic, not just from a specific VNET:

```hcl
resource "azurerm_storage_account" "example" {
    name                     = var.storage_account_name
    resource_group_name      = azurerm_resource_group.example.name
    location                 = azurerm_resource_group.example.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_storage_account_network_rules" "example" {
    storage_account_id = azurerm_storage_account.example.id
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.main.id]
}
```

Finally, it’s possible to use the Azure Deployment Script component itself to execute the desired code:

```hcl
resource "azapi_resource" "run_python_from_github" {
    type = "Microsoft.Resources/deploymentScripts@2023-08-01"
    name                = "run-python-from-github"
    location            = azurerm_resource_group.example.location
    parent_id           = azurerm_resource_group.example.id

    identity {
        type         = "UserAssigned"
        identity_ids = [
            azurerm_user_assigned_identity.script_identity.id
        ]
    }

    body = {
        kind = "AzureCLI"
        properties = {
            azCliVersion = "2.45.0"
            retentionInterval  = "P1D"
            cleanupPreference = "OnSuccess"
            timeout            = "PT15M"
            storageAccountSettings = {
                storageAccountName = azurerm_storage_account.example.name
            }
            containerSettings = {
                subnetIds = [
                {
                    id = "${azurerm_subnet.main.id}"
                }
                ]
            }
            scriptContent = <<EOF
            echo "Hello..."
            EOF
        }
    }
}
```

You can set the subnet ID, storage, and script type (AzureCLI for Linux, PowerShell for Windows). Python 3 and Azure CLI come pre-installed; simply run pip install for dependencies, then execute your Python script.

A key point from the code above is the use of an identity block. This should be a user-assigned identity with permissions to run code from ACI. At minimum, it needs Storage Blob Data Contributor and Storage File Data Privileged roles for ACI storage access:

```hcl
resource "azurerm_user_assigned_identity" "script_identity" {
    name                = "deployment-script-identity"
    resource_group_name = azurerm_resource_group.example.name
    location            = azurerm_resource_group.example.location
}

resource "azurerm_role_assignment" "blob_data_contributor" {
    scope                = azurerm_storage_account.example.id
    role_definition_name = "Storage Blob Data Contributor"
    principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}

resource "azurerm_role_assignment" "file_data_privileged_contributor" {
    scope                = azurerm_storage_account.example.id
    role_definition_name = "Storage File Data Privileged Contributor"
    principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}
```

One important consideration is how to obtain the required Python code within ACI if an image cannot be supplied. The most straightforward approach is to use a `git clone` command in your script to retrieve the necessary code; for private repositories, a personal access token can be securely provided as an environment variable. Alternatively, you may upload the code to a storage account during deployment and then utilize the Azure CLI within your script to download the files to the ACI instance for execution. The second approach is suitable for local execution when there is no commit, while the first approach is more appropriate when deployment is managed through CI/CD workflows.

**Advantages:** This approach is simple and allows testing from a local computer. It does not require GitHub private runners or a connection between GitHub and Azure VNET, making it compatible with most organizational policies.

**Disadvantages:** Managing scripts can be difficult if your Python project spans multiple files. Cloning is effective, but all code changes must be in a published branch and correctly named when cloning. If you publish code into a storage account, ensure deployments overwrite existing code each time. For complex operational processes with multiple developers tuning versions post-deployment, this method may be inadequate; a GitHub private runner might be required. Finally, a limited set of technologies is supported, and if Python is not your preferred language other options will work better.

## Option 2. Using Virtual Machines during deployment or as a private runner

This option utilises the Virtual Machine Extension, which enables the execution of custom scripts on newly created Virtual Machines, including those created within a VNET. As a result, these scripts can access required resources under the VM's identity.

```hcl
resource "azurerm_virtual_machine_extension" "github_runner" {
    name                 = "install-github-runner"
    virtual_machine_id   = azurerm_linux_virtual_machine.github_runner[0].id
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.1"

    settings = jsonencode({
        script = base64encode(templatefile("install-github-runner.sh"))
    })

    tags = var.tags

    depends_on = [azurerm_linux_virtual_machine.github_runner]
}
```

This option is suitable for local testing and closely resembles the previous approach. The key distinction is that the deployed VM is retained as part of the infrastructure rather than being deleted after deployment. This makes it an excellent choice for use as a GitHub self-hosted runner, capable of utilising custom images and handling complex workloads beyond just Python applications. Accordingly, our focus will be on this topic.

Let us look at the process of manual enabling of the GitHub self-hosted runner and map these steps to automated process later.

To initiate manual creation, the Actions->Runners tab within the repository settings provides essential preliminary information regarding the process. There are three steps: runner package download, runner configuration with the provided runner token, and execution of the runner. Automating the process, we will need to execute all these steps as a part of our CI/CD in GitHub.

**Step 1.** Generate the runner token. The token can be created using the GitHub REST API according to [this documentation](https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#create-a-registration-token-for-a-repository). For example, use GitHub CLI for this task:

```shell
# GitHub CLI api
# https://cli.github.com/manual/gh_api

gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/OWNER/REPO/actions/runners/registration-token
```

The simplest way to log into the API is a personal access token according to [the documentation](https://cli.github.com/manual/gh_auth_login).

**Step 2.** Create a VM as a part of infrastructure. Utilise Terraform to provision all necessary infrastructure components, including the virtual network (VNET) and the virtual machine. Additionally, incorporate a Virtual Machine Extension block to execute the designated custom script.

**Step 3.** Configure VM to be a self-hosted runner. The next step involves creating a script to configure the runner on the virtual machine (VM), utilizing the token obtained in step 1 as a parameter. This script should download the GitHub runner code, configure the runner with the provided token, and perform any necessary preparatory tasks on the VM. For instance, it may set up Docker if it is required for future GitHub Actions, or install additional components such as PowerShell for Linux. A key distinction from the manual setup process lies in how the runner is started; ideally, it should operate as a service rather than being executed directly from the console. Additionally, the runner must be capable of restarting automatically following a VM reboot. The GitHub runner code facilitates these requirements through the built-in .svc utility. More details about this utility can be found [here](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/configuring-the-self-hosted-runner-application-as-a-service). Only two commands need to be executed:

```shell
sudo ./svc.sh install
sudo ./svc.sh start
```

That’s all. Now all jobs that are using self-hosted as a runner will pick the runner automatically to execute:

```yaml
runs-on: self-hosted
```

To delete the runner, you can delete the VM and remove the record from the GitHub [using REST API](https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#delete-a-self-hosted-runner-from-a-repository).

Example of a similar implementation can be found [here](https://github.com/microsoft/symphony/blob/main/scripts/install/providers/github/github.sh).

**Advantages:** This method offers a straightforward approach for deploying a private runner while allowing custom configurations to persist across workflow runs. The runner effectively supports operational processes, including the execution of scripts written in various programming languages. If your organization doesn't permit or configure private runners, this option quickly clarifies the issue.

**Disadvantages:** The scalability of this approach is constrained, and manual intervention may be necessary to start or stop the virtual machine when it is not in use. Additionally, deploying Docker containers on top of the VM is recommended to prevent dependency conflicts between runs. In this context, the VM serves primarily as a host, requiring you to manage a collection of container images to support various stages of the workflow. Certain organization policies may restrict automation for private runners, including at the per-repository level.

## Option 3. Using Azure Container Applications as a GitHub self-hosted runner

This approach presumes the use of Azure Container Application (ACA) as a GitHub self-hosted runner for executing code within GitHub workflows and does not support local execution. It offers significant flexibility by enabling the deployment of multiple containers concurrently with the number of workflows, thereby minimising delays that can impact complex projects involving large engineering teams. Additionally, workflow execution time is reduced because container images can be pre-configured with all necessary dependencies.

To enable ACA, several key components must be in place: an Azure Container Registry integrated with your Virtual Network; a process for creating and deploying the initial image to the Azure Container Registry; ACA itself, together with related services such as Log Analytics Workspace, Azure Container Environment, and the necessary managed identities. Among these, the component responsible for building and pushing images to the registry within a VNET is less commonly encountered. In Terraform, the AzureRM Container Registry Task can facilitate this process as part of your deployment workflow:

```hcl
resource "azurerm_container_registry_task" "github_runner_build" {
    name                  = "build-github-runner"
    container_registry_id = azurerm_container_registry.github_runners.id

    platform {
        os           = "Linux"
        architecture = "amd64"
    }

    docker_step {
        ...
        # Docker step parameters are here
    }

    identity {
        type = "SystemAssigned"
    }

    tags = var.tags

    depends_on = [
        ...
        # Dependencies are here
    ]
}
```

During this task execution a new image is pushed to ACR and the docker file should contain all the commands to download GitHub Runner code and initialize it.

To update an image in Azure Container Registry, you may utilize a dedicated GitHub workflow operating on ACA self-hosted GitHub runner with the previous image. It is important to note that, in this configuration, the docker tool cannot be used as part of the runner. However, the acr tool functions effectively and can be employed within the workflow to perform the image update.

See a detailed implementation example [here](https://github.com/Azure-Samples/Copilot-Studio-with-Azure-AI-Search/tree/main/infra/modules/github_runner_aca).

**Advantages:** This approach is scalable, using resources only when required for workflows. Most tasks can run on these instances, and while Docker has limitations, workflows needing image builds can use the acr tool instead.

**Disadvantages:** Updating the image for ACA involves an extra workflow. The infrastructure may appear complex to users with less experience. Organizational policies may restrict automation of this process.

## Which option is better?

Selecting an appropriate option depends on several factors, including repository complexity, team experience, and organizational policies. The following table provides a summary of our recommendations:

| Conditions | Approach to start |
| --- | --- |
| PowerShell, Bash, or Python scripts are executed exclusively during the deployment process. The operationalization process enables repeated execution of the infrastructure deployment workflow if modifications occur. | Azure Deployment Script |
| Current organizational policies neither mandate nor facilitate the activation of GitHub self-hosted runners, and script execution is restricted to PowerShell, Bash, or Python. | Azure Deployment Script |
| The operationalization process involves executing code outside the infrastructure deployment workflow or running code that is not written in Python. | Azure Container Application |
| The GitHub self-hosted runner approach can be evaluated as an initial method for executing the required code directly on the host. | Virtual Machine as a self-hosted runner |
| Some scripts should be executed during the infrastructure deployment and manual intervention to start/stop a VM is possible. Additional operationalization workflows are not required. | Virtual Machine Extension only |
| You need a scalable solution that will allow us to execute code outside of the infrastructure deployment process. | Azure Container Application |

We recommend using VMs only for testing or simple cases where tasks can run directly on the host and manual intervention is fine.
Additionally, please note that proceeding with either the ACA or VM approach can be integrated with the Azure Deployment Script within the same repository, as these options are not mutually exclusive.