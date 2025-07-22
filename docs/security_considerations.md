# Security Considerations

This document outlines the security considerations for the Copilot Studio with Azure AI Search template, including current security posture, identified risks, and hardening guidance for production deployments.

## Overview

This template is designed as an **evaluation and demonstration platform** with a balance between security and ease of deployment. While security best practices are implemented where possible, some configurations are optimized for simplicity and cost-effectiveness rather than maximum security posture.

**⚠️ Important:** This template should not be used as-is in production environments without additional security hardening as outlined in this document.

## Security Suppressions and Rationale

The following Checkov security checks are suppressed in this template with specific justifications:

### Azure AI Search Service

**Suppressed Checks:**
- `CKV_AZURE_208`: "Ensure that Azure Cognitive Search maintains SLA for index updates"
- `CKV_AZURE_209`: "Ensure that Azure Cognitive Search maintains SLA for search index queries"

**Rationale:** This template uses minimal infrastructure configuration (default partition_count and replica_count) for evaluation purposes and cost optimization.

**Production Hardening:**
```hcl
resource "azurerm_search_service" "ai_search" {
  partition_count = 2    # Increase for production SLA
  replica_count   = 2    # Increase for production SLA and high availability
  # ... other configurations
}
```

**References:**
- [Azure Cognitive Search SLA](https://azure.microsoft.com/en-us/support/legal/sla/search/v1_0/)
- [Azure Cognitive Search capacity planning](https://docs.microsoft.com/en-us/azure/search/search-capacity-planning)

### Azure Storage Accounts

#### Main Storage Account (via AVM Module)

**Suppressed Checks:**
- `CKV_AZURE_244`: Storage account configuration check not supported in Azure Verified Module (AVM)
- `CKV_TF_1`: Module version pinning - using published module version for maintainability
- `CKV_AZURE_33`: Logging configuration - logging is enabled through the module
- `CKV2_AZURE_38`: Soft delete configuration - soft delete is enabled through the module

**Rationale:** These suppressions are due to the Azure Verified Module (AVM) implementation which handles security configurations internally.

**Production Hardening:** The AVM module already implements security best practices. Review the module documentation for additional security options.

#### Deployment Scripts Storage Account

**Suppressed Checks:**
- `CKV_AZURE_59`: "Ensure that storage account public access is disallowed"
- `CKV_AZURE_44`: "Ensure Storage Account is using the latest version of TLS encryption"
- `CKV_AZURE_206`: "Ensure that Storage Account is not configured with Locally Redundant Storage"
- `CKV_AZURE_190`: "Ensure that Storage blobs are not publicly accessible"
- `CKV_AZURE_35`: "Ensure default network access rule for Storage Accounts is set to deny"
- `CKV_AZURE_33`: "Ensure Storage logging is enabled for Queue service for read, write and delete requests"
- `CKV2_AZURE_41`: "Ensure that storage account is not configured with shared access key policy"
- `CKV2_AZURE_40`: "Ensure Storage Account is using the latest version of TLS encryption and not allowing HTTP"
- `CKV2_AZURE_33`: "Ensure storage account is configured with private endpoint"
- `CKV2_AZURE_38`: "Ensure soft-delete is enabled on Azure storage account"
- `CKV2_AZURE_47`: "Ensure storage account is configured to allow access from trusted Microsoft services"
- `CKV2_AZURE_1`: "Ensure storage account is configured with private endpoint and that network access is restricted"
- `CKV_AZURE_34`: "Ensure that 'Public access level' is set to Private for blob containers"
- `CKV2_AZURE_21`: "Ensure Storage Account is configured with logging for read, write and delete operations"

**Rationale:** The deployment scripts storage account requires specific configurations to work with Azure Deployment Scripts service, which has requirements that conflict with some security best practices:
- Public network access is required for the Azure Deployment Scripts service to access the storage account
- TLS 1.2 is the minimum supported by Azure Deployment Scripts (newer versions not yet supported)
- LRS replication is sufficient for temporary deployment container storage (cost optimization)
- Shared key access is required by the Azure Deployment Scripts service
- Private endpoints are not compatible with Azure Deployment Scripts service requirements

**Production Hardening:**
1. **Use a separate storage account** for deployment scripts that is deleted after deployment
2. **Implement Azure Policy** to ensure deployment scripts storage is only created when needed
3. **Use managed identity** where possible, but note that shared key access is still required for some operations
4. **Monitor access logs** for the deployment scripts storage account
5. **Consider using Azure Container Instances** instead of Azure Deployment Scripts for more granular control

### Azure AI/Cognitive Services

**Suppressed Checks:**
- `CKV2_AZURE_22`: "Ensure that Cognitive Services enables customer-managed key for encryption"
- `CKV_AZURE_236`: "Ensure that Cognitive Services accounts enable local authentication"
- `CKV_TF_1`: Module version pinning - using published module version for maintainability

**Rationale:**
- Customer-managed keys add complexity and cost for evaluation scenarios
- Power Platform AI Search connector requires specific authentication methods (service principal, API key, or interactive auth)
- Using published module versions for maintainability (see decision-log/001-avm-usage-and-version.md)

**Production Hardening:**
```hcl
# Enable customer-managed encryption
customer_managed_key = {
  key_vault_resource_id = azurerm_key_vault.main.id
  key_name             = "cognitive-services-key"
}

# Review authentication requirements for your specific use case
local_authentication_enabled = false  # Disable if not required by integrations
```

### Container Registry (GitHub Runner Module)

**Suppressed Checks:**
- `CKV_AZURE_139`: "Ensure ACR admin account is disabled"
- `CKV_AZURE_164`: "Ensure ACR retention policy is enabled"
- `CKV_AZURE_165`: "Ensure container image scan results are available"
- `CKV_AZURE_166`: "Ensure that ACR images are built with automated CI/CD pipelines"
- `CKV_AZURE_233`: "Ensure ACR has enabled zone redundancy"
- `CKV_AZURE_237`: "Ensure ACR public network access is disabled"

**Rationale:** The GitHub runner module requires specific configurations for cost optimization and functional requirements in evaluation scenarios.

**Production Hardening:**
1. **Enable admin account only when necessary** and disable after use
2. **Implement retention policies** for container images
3. **Enable vulnerability scanning** and automated scanning policies
4. **Use private endpoints** for ACR access
5. **Enable zone redundancy** for production workloads
6. **Implement proper RBAC** for ACR access

## Network Security

### Current Security Posture

✅ **Implemented Security Measures:**
- Network Security Groups (NSGs) are properly configured and associated with all subnets
- Private endpoints are implemented for Azure AI Search and Storage services
- Virtual network service endpoints are configured for storage and cognitive services
- NAT gateways provide controlled outbound internet access
- Network rules restrict storage account access to specific subnets

### Production Hardening Recommendations

1. **Implement Azure Firewall** or Network Virtual Appliances for centralized traffic filtering
2. **Enable DDoS Protection Standard** for production virtual networks
3. **Implement Network Watcher** for monitoring and diagnostics
4. **Use Azure Private DNS** for all private endpoint resolutions
5. **Implement hub-and-spoke network topology** for larger deployments
6. **Enable NSG flow logs** for security monitoring and analysis

## Identity and Access Management

### Current Security Posture

✅ **Implemented Security Measures:**
- Managed identities are used where possible
- Role-based access control (RBAC) is implemented
- Service principals are used for Power Platform integration

### Production Hardening Recommendations

1. **Implement Conditional Access policies** for administrative access
2. **Enable Azure AD Privileged Identity Management (PIM)** for elevated access
3. **Use Azure AD Application Proxy** for secure remote access
4. **Implement just-in-time (JIT) access** for virtual machines
5. **Regular access reviews** for service principals and managed identities

## Data Protection

### Current Security Posture

✅ **Implemented Security Measures:**
- Encryption at rest is enabled for all storage services
- TLS encryption is enforced for data in transit
- Soft delete is enabled for blob storage
- Private endpoints ensure data doesn't traverse public internet

### Production Hardening Recommendations

1. **Implement customer-managed encryption keys (CMK)** for all services
2. **Enable Azure Information Protection** for data classification
3. **Implement data loss prevention (DLP) policies**
4. **Enable auditing and threat detection** for all data services
5. **Implement backup and disaster recovery** strategies

## Monitoring and Logging

### Current Security Posture

✅ **Implemented Security Measures:**
- Basic logging is enabled for storage services
- Diagnostic settings are configured where possible

### Production Hardening Recommendations

1. **Implement Azure Security Center** for centralized security monitoring
2. **Enable Azure Sentinel** for security information and event management (SIEM)
3. **Configure diagnostic settings** for all Azure services
4. **Implement log analytics workspaces** for centralized logging
5. **Set up security alerts and automated responses**
6. **Enable vulnerability assessments** for all applicable services

## Compliance and Governance

### Recommendations

1. **Implement Azure Policy** for governance and compliance
2. **Use Azure Blueprints** for consistent deployments
3. **Enable Azure Cost Management** for cost governance
4. **Implement tagging strategies** for resource management
5. **Regular security assessments** and penetration testing

## Deployment Security

### Recommendations

1. **Use secure CI/CD pipelines** with proper secret management
2. **Implement infrastructure as code (IaC) scanning** in CI/CD
3. **Use Azure DevOps or GitHub Actions** with proper security configurations
4. **Implement proper branch protection** and code review processes
5. **Use Azure Key Vault** for all secrets and certificates

## Incident Response

### Recommendations

1. **Develop incident response procedures** for security events
2. **Implement automated incident response** where possible
3. **Regular incident response drills** and testing
4. **Establish communication procedures** for security incidents
5. **Implement forensic capabilities** for incident investigation

## Regular Maintenance

### Recommendations

1. **Regular security updates** for all components
2. **Quarterly security reviews** of configurations
3. **Annual penetration testing** and vulnerability assessments
4. **Regular review of access permissions** and roles
5. **Keep security documentation** up to date

## Contact and Support

For questions about security considerations or to report security vulnerabilities, please refer to the [SECURITY.md](../SECURITY.md) file in the repository root.

## References

- [Azure Security Baseline](https://docs.microsoft.com/en-us/security/benchmark/azure/)
- [Azure Well-Architected Framework - Security](https://docs.microsoft.com/en-us/azure/architecture/framework/security/)
- [Azure Security Center](https://docs.microsoft.com/en-us/azure/security-center/)
- [Azure Sentinel](https://docs.microsoft.com/en-us/azure/sentinel/)
- [Microsoft Cloud Adoption Framework - Security](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/secure/)