# Security Considerations for Copilot Studio with Azure AI Search AZD Template

## Table of Contents

- [Executive Summary](#executive-summary)
- [Template Security Architecture](#template-security-architecture)
- [Built-in Security Controls](#built-in-security-controls)
- [Threat Model and Risk Assessment](#threat-model-and-risk-assessment)
- [Trust Boundaries](#trust-boundaries)
- [Security Hardening Recommendations](#security-hardening-recommendations)
- [Summary](#summary)

## Executive Summary

This document explains the security controls implemented in the **Copilot Studio with Azure AI Search** template and provides guidance on additional hardening measures that users should consider for production deployments. The template implements foundational security best practices while providing flexibility for organizations to enhance security based on their specific requirements.

### Built-in Security Controls

✅ **Network Isolation**: Private endpoints for Azure AI Search with VNet segmentation  
✅ **Identity Security**: System-assigned managed identities for service-to-service authentication  
✅ **Infrastructure as Code**: Automated security scanning with Checkov, TFLint, and Gitleaks  
✅ **Multi-Region Support**: Primary and failover region deployment capability  
✅ **Secure Deployment**: GitHub Actions with OIDC federation support  

### User Responsibilities

The template provides a secure foundation, but users are responsible for:

⚠️ **Enhanced Network Security**: Basic Network Security Groups are provided, but they should be updated for your organization's specific security requirements
⚠️ **Secrets Management**: Implementing Azure Key Vault for centralized secret storage  
⚠️ **Advanced Monitoring**: Configuring security-focused logging and alerting  
⚠️ **AI-Specific Protections**: Implementing prompt validation and content filtering  
⚠️ **Compliance Configuration**: Adding controls for specific regulatory requirements  

### Security Baseline

The template establishes a **security baseline** suitable for development and testing environments. For production deployments, users should implement the hardening recommendations outlined in this document to achieve enterprise-grade security posture.

### Quick Start Security Checklist

Before deploying to production:
1. ✅ Review and implement network hardening recommendations
2. ✅ Configure Azure Key Vault for secrets management  
3. ✅ Set up enhanced monitoring and alerting
4. ✅ Enable additional security scanning and compliance checks
5. ✅ Establish incident response procedures

## Template Security Architecture

### Overview

The Copilot Studio with Azure AI Search template implements a **secure-by-design** approach with multiple layers of protection. The architecture follows Azure Well-Architected Framework security principles and implements defense-in-depth strategies suitable for enterprise environments.

### Architecture Diagram

```mermaid
graph TB
    subgraph "Internet"
        User[End User]
        DevOps[DevOps Engineer]
        Maker[Copilot Developer]
    end
    
    subgraph "GitHub"
        GH_Repo[Repository]
        GH_Actions[GitHub Actions]
        GH_Runner[Self-Hosted Runner<br/>Optional]
    end
    
    subgraph AZS[Azure Subscription]
        subgraph "Resource Group"
            subgraph PVNET[Primary VNet]
                PP_Subnet[Power Platform<br/>Subnet]
                AIS_Subnet[AI Search<br/>Subnet] 
                PE_Subnet[Private Endpoint<br/>Subnet]
                GHR_Subnet[GitHub Runner<br/>Subnet<br/>Optional]
            end
            
            subgraph FVNET[Failover VNet]
                PP_Subnet_F[Power Platform<br/>Subnet]
                AIS_Subnet_F[AI Search<br/>Subnet]
                PE_Subnet_F[Private Endpoint<br/>Subnet]
                GHR_Subnet_F[GitHub Runner<br/>Subnet<br/>Optional]
            end
            
            AOAI[Azure OpenAI<br/>System Assigned MI]
            AIS[Azure AI Search<br/>System Assigned MI]
            Storage[Storage Account<br/>System Assigned MI]
            PE1[Private Endpoint<br/>Primary]
            PE2[Private Endpoint<br/>Failover]
            DNS[Private DNS Zone]
            ACR[Container Registry<br/>Optional]
        end
    end
    
    subgraph PP[Power Platform Tenant]
        subgraph PP_Env[Power Platform Environment]
            CS_Agent[Copilot Studio<br/>Agent]
            PP_Conn[AI Search<br/>Connection]
        end
        Channel[Channel]
        MCS[Copilot Studio]
        subgraph PPEP[Power Platform Enterprise Policy]
            NIP[Network Injection Policy]
        end
    end
    
    subgraph "Microsoft Entra Tenant"
        ENTRA_SP[Service Principal]
    end
    
    Maker --> MCS
    MCS --> PP_Env
    User --> Channel
    Channel --> CS_Agent
    CS_Agent --> PP_Conn
    PP_Conn --> PE1
    PP_Conn --> PE2
    PE1 --> AIS
    PE2 --> AIS
    AIS --> AOAI
    AIS --> Storage
    
    DevOps --> GH_Repo
    GH_Actions --> AZS
    GH_Actions --> ENTRA_SP
    GH_Actions --> PP
    GH_Runner --> GH_Actions

    NIP --> PVNET
    NIP --> FVNET
    PP_Env --> NIP
    
```

## Threat Model and Risk Assessment

The template addresses **infrastructure-level risks** effectively but requires user configuration for **application-level** and **advanced operational** security controls.

### Threat Categories Addressed by Template

| Threat ID | Category | Template Mitigation | Status | Suggested Hardening |
|-----------|----------|-------------------|--------|---------------------|
| **T1.1** | Network Attacks | Private endpoints for AI Search, VNet isolation | ✅ Implemented | Add NSGs, expand private endpoints |
| **T1.2** | Identity Compromise | System-assigned managed identities, RBAC | ✅ Implemented | Enable PIM, conditional access |
| **T1.3** | Data Exfiltration | Private endpoints, network restrictions | ✅ Partially | DLP controls |
| **T2.1** | Platform Compromise | Environment isolation, network injection | ✅ Implemented | Configure governance policies |
| **T2.2** | AI Model Abuse | [Copilot Studio Runtime Protection](https://learn.microsoft.com/en-us/microsoft-copilot-studio/security-agent-runtime-view) | ⚠️ Limited | Implement advanced filtering, AI red teaming |
| **T3.1** | Supply Chain | Security scanning (GitHub Advanced security & Gitleaks), AVM usage, Dependabot | ✅ Implemented | Monitor dependency updates |
| **T3.2** | Credential Exposure | OIDC support, managed identities | ⚠️ Limited | Migrate API keys to managed identities when supported by AI Search connector |

**Legend**: ✅ Fully Implemented | ⚠️ Basic Implementation | ❌ User Responsibility

## Trust Boundaries

**Trust boundaries** are security checkpoints where data or execution changes its level of trust. The template implements two distinct security contexts with different trust boundaries and authentication flows.

### User/Runtime Security Context

This is the flow when end users interact with your copilot:

```mermaid
graph LR
    User[End User] --> Channel[Channel<br/>Teams/Web/etc]
    Channel --> |Power Platform Auth| Agent[Copilot Studio Agent]
    Agent --> |API Key via Connector| AISearch[Azure AI Search]
    AISearch --> |Managed Identity| OpenAI[Azure OpenAI]
    AISearch --> |Managed Identity| Storage[Storage Account]
    
    classDef userFlow fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    class User,Channel,Agent,AISearch,OpenAI,Storage userFlow
```

| Trust Boundary | Authentication Method | Security Controls | What You Need to Know |
|-----------------|----------------------|-------------------|----------------------|
| **User to Copilot Studio Agent** | Channel-specific authentication (Teams, Web, etc.) | Channel security policies, user authentication | Users authenticate through their chosen channel (Teams, web chat, etc.) |
| **Copilot Agent to AI Search** | API key authentication via AI Search Connector | DLP policies, private endpoints, network restrictions, query validation | Connection uses API keys stored securely in Power Platform |
| **AI Search to Azure OpenAI** | Managed identity authentication | Content filtering, token validation, private endpoints, VNet restrictions | AI Search uses its managed identity to access OpenAI models |
| **AI Search to Storage Account** | Managed identity authentication | Private endpoints, blob permissions, audit logging | AI Search accesses documents using managed identity |

### Deployment Security Context

This is the flow when developers deploy and manage the infrastructure:

```mermaid
graph LR
    Developer[Developer] --> |GitHub Auth| GitHub[GitHub Repository]
    GitHub --> |OIDC Federation| SP[Service Principal]
    SP --> |Azure RBAC| AzureCP[Azure Control Plane]
    SP --> |PP Service Auth| PPAPI[Power Platform APIs]
    
    AzureCP --> |Deploys| AzureResources[Azure Resources]
    AzureCP --> |Creates| DeployScript[Deployment Scripts]
    DeployScript --> |Managed Identity| AISearch[Azure AI Search]
    DeployScript --> |Managed Identity| Storage[Storage Account]
    
    PPAPI --> |Deploys| PPSolution[Power Platform Solution]
    
    classDef deployFlow fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    class Developer,GitHub,SP,AzureCP,PPAPI,AzureResources,DeployScript,AISearch,Storage,PPSolution deployFlow
```

| Trust Boundary | Authentication Method | Security Controls | What You Need to Know |
|-----------------|----------------------|-------------------|----------------------|
| **Developer to GitHub** | GitHub authentication (SSO, MFA) | Repository permissions, branch protection, commit signing | Developers authenticate to GitHub with their credentials |
| **GitHub Workflow to Entra** | Federated identity (OIDC) | Workload identity federation, no long-lived secrets | GitHub Actions uses OIDC to get short-lived tokens |
| **GitHub Workflow to Azure Control Plane** | Azure AD authentication | Azure RBAC, subscription policies, resource governance | Service principal deploys Azure infrastructure resources |
| **Deployment Scripts to AI Search** | Managed identity authentication | RBAC permissions, private endpoints, audit logging, script isolation | Deployment Scripts use managed identity to configure AI Search indexes |
| **Deployment Scripts to Storage Account** | Managed identity authentication | RBAC permissions, private endpoints, audit logging, blob access | Deployment Scripts use managed identity to upload initial documents |
| **GitHub Workflow to Power Platform APIs** | Power Platform service authentication | Power Platform Admin Application permissions, Environment permissions | Service principal deploys Power Platform policies, environment, solutions and configurations |

### Network Security Context

**VNet Isolation**: AI Search connections from Power Platform use either:
- **Primary VNet**: Main region private endpoint for normal operations
- **Failover VNet**: Secondary region private endpoint for high availability

Both VNets provide network-level isolation with private endpoints, ensuring AI Search traffic never traverses the public internet.

## Security Hardening Recommendations

The template provides a secure foundation, but users must implement additional controls for production environments. These recommendations are organized by priority and impact.

### Critical Actions (Required for Production)

**Network Security**:
- Deploy Network Security Groups (NSGs) with explicit allow/deny rules for each subnet
- Add private endpoints for Azure OpenAI and Storage Account to eliminate all public access
- Configure Azure DDoS Protection Standard for production workloads
- Implement proper DNS resolution for all private endpoints

**Identity and Access Management**:
- Enable OIDC federation for GitHub Actions to eliminate long-lived secrets
- Implement Privileged Identity Management (PIM) for administrative access
- Configure conditional access policies for enhanced authentication
- Review and minimize service principal permissions

**Secrets and Key Management**:
- Implement automated rotation for Azure AI Search admin keys
- Monitor and audit all API key usage patterns
- Plan migration path from API keys to managed identities when platform supports it
- Configure centralized secret management policies

### Important Actions (Recommended)

**AI-Specific Security**:
- Configure advanced content filtering policies in Copilot Studio
- Implement input validation and prompt injection protection
- Set up rate limiting for AI Search queries
- Monitor AI model usage and detect anomalous patterns

**Monitoring and Response**:
- Deploy Log Analytics workspace for security event correlation
- Configure Microsoft Defender for Cloud for threat detection
- Set up automated security alerts and response playbooks
- Establish security incident response procedures

**Governance and Compliance**:
- Implement Azure Policy assignments for security baselines
- Configure data classification and sensitivity labeling
- Set up compliance monitoring for regulatory requirements
- Establish regular security assessments and penetration testing

### Optional Enhancements

**Advanced Security**:
- Deploy Microsoft Sentinel for comprehensive SIEM capabilities
- Implement Azure Purview for data governance
- Configure advanced threat protection across all services
- Set up zero trust network architecture principles

### Assumptions and Prerequisites

The template assumes users have:

- **Microsoft Entra ID**: Properly configured tenant with security baselines
- **Power Platform Governance**: Tenant-level policies and controls enabled  
- **Azure Subscription**: Appropriate compliance and security baselines applied
- **Operational Readiness**: Teams trained on Azure and Power Platform security

For detailed implementation guidance, refer to the Azure Well-Architected Framework Security Pillar and Power Platform security best practices documentation.

## Summary

This document explains the security controls implemented in the Copilot Studio with Azure AI Search template and outlines the additional hardening measures that users must implement for production deployments.

### What the Template Provides

The template establishes a **secure foundation** with:
- Network isolation through private endpoints and VNet segmentation
- Identity security using system-assigned managed identities
- Automated security scanning in deployment pipelines
- Multi-region deployment support for high availability

### What Users Must Implement

For production deployments, users are responsible for:
- **Network Security**: Adding Network Security Groups and expanding private endpoints
- **Secrets Management**: Implementing Azure Key Vault integration
- **Enhanced Monitoring**: Configuring security-focused logging and alerting
- **AI Security**: Adding prompt validation and advanced content filtering
- **Compliance**: Configuring controls for specific regulatory requirements

### Security-First Approach

1. **Start Secure**: Deploy the template to understand baseline security controls
2. **Assess Requirements**: Review hardening recommendations based on your threat model
3. **Implement Gradually**: Prioritize critical security enhancements before production
4. **Monitor Continuously**: Establish ongoing security validation procedures
