# ADR 003: Resource Configuration within VNET

**Date:** 2025-08-11  
**Status:** Approved

## Context
When deploying Azure infrastructure that includes a Virtual Network (VNET), we need to execute custom scripts to configure resources that are isolated from public networks. For example, Azure AI Search deployed without public access requires Python scripts to create indexes, indexers, and skillsets. The deployment orchestration (GitHub Actions) runs outside the created VNET and cannot directly access these private resources.

Key requirements:

- Execute Python scripts for Azure AI Search configuration within VNET
- Maintain security by keeping resources within VNET boundaries
- Support both local testing and CI/CD deployment scenarios
- Minimize infrastructure complexity while maintaining flexibility

## Decision

We will use **Azure Deployment Scripts** as the primary method for executing custom code within VNET during infrastructure deployment.

## Rationale

Azure Deployment Scripts provide the optimal balance of simplicity, security, and functionality for our use case:

**Advantages:**

- Simple implementation requiring minimal infrastructure components
- Compatible with local testing and CI/CD workflows
- No need for GitHub private runners or complex networking between GitHub and Azure
- Automatic cleanup of temporary resources after execution
- Built-in support for Python 3, PowerShell and Azure CLI
- Fits within standard organizational security policies

**Trade-offs Accepted:**

- No custom images are supported, but required components can be installed using bash scripts
- Requires git clone for multi-file Python projects or access to a storage with pre-uploaded code
- Less suitable for complex operational processes requiring persistent infrastructure
- End-to-end testing leverages the Copilot Studio public endpoint; however, for scenarios requiring direct access to the data plane or private network, this approach can be complemented by using GitHub self-hosted runners within the VNET.

**Alternatives Considered:**

- VM Custom Script Extensions: More complex infrastructure, requires ongoing VM management
- Azure Container Applications as a GitHub selh-hosted runner: Higher complexity, better for scalable/persistent scenarios

## Implementation Details

The following actions should be taken to implement the selected approach:

- Use AzAPI provider (~>2.0) for latest Azure Deployment Script features
- Configure Azure Deployment Script to use Azure Container Instance (ACI) within dedicated subnet with proper delegation
- Utilize storage account with network rules for deployment script state management
- Implement user-assigned managed identity with minimal required permissions
- Use git clone approach or a dedicated storage account for retrieving Python scripts from repository

## Related Decisions

- [ADR 004: GitHub Runner Strategy](004-github-runner-strategy.md) - GitHub runner approach for broader automation needs