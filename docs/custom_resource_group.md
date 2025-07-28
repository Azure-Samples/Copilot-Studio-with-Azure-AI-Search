# Custom Resource Group Name

This template creates a resource group with a randomly generated name by default. You can override this behavior by specifying pre-created resource group during deployment.

## Required Variables

To use your own resource group, set the following environment variable:

```shell
azd env set RESOURCE_GROUP_NAME "<your-resource-group-name>"
```
