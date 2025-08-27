# ADR 004: GitHub Runner Strategy

**Date:** 2025-08-11  
**Status:** Approved

## Context

Our project requires GitHub Actions automation for CI/CD workflows that need access to Azure VNET resources for testing, validation, and operational tasks beyond initial deployment. Additionally, it is important to keep Terraform state files secure by avoiding the use of public endpoints for state storage and access. Since GitHub-hosted runners cannot access private VNET resources, a self-hosted runner solution is required.

Key requirements:

- Execute GitHub workflows with access to VNET resources
- Keep Terraform state files secure by restricting access to state files
- Support multiple concurrent workflows for team collaboration
- Minimize operational overhead and infrastructure costs
- Provide flexibility for various programming languages and tools
- Align with organizational security and automation policies

## Decision

We will use GitHub-hosted runners and Azure Deployment Scripts as the default for standard operations, recognizing that not all users of the template can set up a self-hosted runner. However, we strongly recommend self-hosted runners as the preferred approach. Self-hosted runners are required for scenarios that need VNET access or specialized environments. When self-hosted runners are necessary, we recommend Azure Container Apps (ACA) as the primary option.

## Rationale

Azure Container Applications provide the best balance of scalability, cost-efficiency, and operational simplicity:

**Advantages:**

- **Scalability**: Automatically scales based on workflow demand, supporting concurrent executions
- **Cost Efficiency**: Resources consumed only during workflow execution
- **Technology Flexibility**: Supports various programming languages and tools through custom container images
- **Reduced Maintenance**: Serverless model eliminates VM management overhead
- **Team Collaboration**: Multiple developers can execute workflows simultaneously without conflicts

**Trade-offs Accepted:**

- **Initial Complexity**: More complex initial setup compared to VM-based approach
- **Image Management**: Requires workflow for updating container images
- **Docker Limitations**: Cannot use Docker-in-Docker, must use ACR tools for container builds

**Alternatives Considered:**

- **VM-based runners**: Simpler setup but poor scalability, manual VM management required
- **Azure Kubernetes Service (AKS)**: Enterprise-grade scalability, advanced orchestration capabilities. At the same time it has high complexity, significant operational overhead, requires Kubernetes expertise

## Self-Hosted Runner Comparison

| Aspect | ACA | VM | AKS |
|--------|-----|----|----|
| Scalability | Excellent | Limited | Excellent |
| Setup Complexity | Medium | Low | High |
| Resource Efficiency | Excellent | Poor | Good |
| Maintenance Overhead | Low | Medium | High |
| Technology Support | Container-based | Full | Container-based |
| Cost Model | Pay-per-use | Always-on | Pay-per-use |

## Implementation Details

The following actions should be taken to implement the selected approach:

- Teams start with GitHub-hosted runners for standard workflows
- Self-hosted runner infrastructure deployed only when VNET access is required
- ACA-based runners require container image management workflows
- VM-based runners suitable for testing and simple use cases with manual intervention
- Teams must evaluate organizational policies regarding self-hosted runners

Implementation Plan:

- Deploy ACR and basic ACA infrastructure within VNET
- Create initial GitHub runner container image with essential tools
- Implement ACR Task for automated image building and deployment
- Configure GitHub repository to use self-hosted runners
- Create image update workflow using ACA runners

## Related Decisions

- [ADR 003: VNET Resource Configuration Strategy](003-vnet-resource-configuration-strategy.md) - Azure Deployment Scripts for deployment tasks