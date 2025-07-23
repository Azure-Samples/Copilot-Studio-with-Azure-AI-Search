# Bring Your Own Network

This module allows you to use a predefined network infrastructure. You can review the `\infra\main.network.tf` file to understand the resources that will be created if the network is automatically provisioned alongside other resources.

## Required Variables

To use your own network, set the following environment variables:

```shell
# Primary region network configuration
azd env set PRIMARY_VNET_ID "<your-primary-virtual-network-id>"
azd env set PRIMARY_SUBNET_ID "<your-primary-subnet-id>"
azd env set PE_PRIMARY_SUBNET_ID "<your-primary-private-endpoint-subnet-id>"
azd env set DEPLOYMENT_SCRIPT_CONTAINER_SUBNET_ID "<your-deployment-script-container-subnet-id>"

# Use this value only if you plan to use GitHub runners
azd env set GITHUB_RUNNER_PRIMARY_SUBNET_ID "<your-github-runner-primary-subnet-id>"

# Failover region network configuration
azd env set FAILOVER_VNET_ID "<your-failover-virtual-network-id>"
azd env set FAILOVER_SUBNET_ID "<your-failover-subnet-id>"
azd env set PE_FAILOVER_SUBNET_ID "<your-failover-private-endpoint-subnet-id>"

# Use this value only if you plan to use GitHub runners
azd env set GITHUB_RUNNER_FAILOVER_SUBNET_ID "<your-github-runner-failover-subnet-id>"
```
