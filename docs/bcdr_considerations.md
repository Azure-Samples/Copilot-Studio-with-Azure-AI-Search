# Business Continuity and Disaster Recovery Considerations

This document explains the disaster recovery (DR) and regional resilience capabilities provided by this template, and highlights areas where additional user action is required for full business continuity.

## Overview

This template is designed to deploy an enterprise-grade integration between Microsoft Copilot Studio and Azure AI Search, following Azure Well-Architected Framework best practices for security and reliability. It provisions a complete primary-region footprint and—where the selected Power Platform geography is backed by two Azure regions—provisions required dual-region networking scaffolding (virtual networks, subnets, private DNS integration) in both regions. This dual-networking is a compliance prerequisite for Enterprise Policy / virtual network delegation in multi-region geographies and is **not optional**, even if you have not yet implemented active regional failover. The template does **not** stand up duplicate workload resources or automate failover; those tasks remain with the adopter.

## Scenarios

This document discusses the considerations for deploying the template in three resilience scenarios: **Basic**, **Zone-redundant**, and **Regional failover ready**.

### Basic (default)

**Basic** targets the lowest-cost setup for non-critical experimentation where downtime and data loss are acceptable. Deploys Azure AI Search, Azure Storage, Azure OpenAI, Networking and supporting resources in a single primary region using Terraform. Often suitable for development and test environments, this scenario intentionally uses single-instance resources and therefore does **not** satisfy production SLA commitments for Azure AI Search or other services.

#### Basic Recommendations

**Azure Storage:**

- Set `cps_storage_replication_type = "Standard_LRS"` to use the lowest-cost locally redundant storage tier suitable for development workloads.

**Azure AI Search:**

- The template defaults to `sku = "basic"`, `replica_count = 1`, and `partition_count = 1` to minimize cost while meeting development needs.

**Azure OpenAI:**

- The default `S0` SKU and `Standard` deployment type are sufficient for development and testing.
- For very basic experimentation or learning, the `F0` free tier is available but has severe quota limitations (typically 1 concurrent request) and is not recommended for active development work.

**Power Platform:**

- The template defaults to a `Sandbox` environment type, which is suitable for non-production workloads.

**Networking:**

- In multi-region Power Platform geographies (for example: United States, Europe, Canada, Australia) dual-region virtual networks are **required** to create the Enterprise Policy virtual network delegation, even if the secondary region is not needed. Do not remove secondary-region networking in these geographies. In a geography that is truly single-region (verify with [current Microsoft documentation](https://learn.microsoft.com/power-platform/admin/vnet-support-setup-configure)), a single VNet footprint would be sufficient.

**Application Insights (optional):**

- The template defaults to disabling Application Insights (`include_app_insights = false`) to minimize costs.
- Consider enabling via `include_app_insights = true` for debugging and telemetry during active development.
- Can be disabled if not needed or if costs are a concern.

### Zone-redundant

**Zone-redundant** is suitable for production workloads that must stay available during a single datacenter or availability-zone outage inside one Azure region. This scenario keeps the primary-region footprint from the Basic tier while adding zone-aware configuration so the workload remains healthy during intraregional failures and meets Azure AI Search SLA minimums and higher performance expectations typical of production environments.

#### Zone-redundant Recommendations

**Azure Storage:**

- Set `cps_storage_replication_type = "Standard_ZRS"` to achieve synchronous zone redundancy within a single region.
- Select an Azure region that supports ZRS for storage accounts.

**Azure AI Search:**

- Configure with a zone-capable SKU: `standard`, `standard2`, `standard3`, `storage_optimized_l1`, or `storage_optimized_l2`.
- Set `replica_count = 2` (minimum) for read-only query SLA, or `replica_count = 3` (recommended) for read-write workload SLA covering indexing operations.
- Zone redundancy is automatically enabled by Azure when using Basic tier or higher with 2+ replicas in supported regions; no additional configuration is required.

**Azure OpenAI:**

- Configure the Azure OpenAI resource using SKU `S0` (Standard), which is the production-grade tier (avoid using the `F0` free tier in production environments).
- Select a deployment type via the `cognitive_deployments` variable's `scale.type` property based on your workload requirements:
  - Use `Standard` (default) for pay-per-token consumption pricing with automatic scaling.
  - Use `ProvisionedManaged` for workloads requiring guaranteed capacity and predictable latency (billed by Provisioned Throughput Units).
  - Use `GlobalProvisionedManaged` for global routing with provisioned capacity across multiple regions.
  - Use `DataZoneProvisionedManaged` for data residency requirements with provisioned capacity.
- No additional configuration is required for zone redundancy; availability zone resilience is handled transparently by Microsoft-managed infrastructure within the region.

**Power Platform:**

- Set `power_platform_environment.environment_type = "Production"` (changing from the default `Sandbox` value) to automatically benefit from Azure availability zone replication (synchronous across 2-3 zones) with zero additional configuration required.
- Expect near-zero data loss (RPO) and sub-5-minute failover (RTO) for intra-region zone failures with production environments.
- Defer enabling Power Platform self-service disaster recovery to the Regional failover ready tier (it is a cross-region capability, not zone-level).

- In multi-region Power Platform geographies (for example: United States, Europe, Canada, Australia) dual-region virtual networks are **required** to create the Enterprise Policy virtual network delegation; even if secondary region is not needed. Do not remove secondary-region networking in these geographies. In a geography that is truly single-region (verify with [current Microsoft documentation](https://learn.microsoft.com/power-platform/admin/vnet-support-setup-configure)), a single VNet footprint would be sufficient;

**Application Insights:**

- Enable Application Insights via `include_app_insights = true` for production monitoring and telemetry (zone redundancy is automatic by default in supported regions).

### Regional failover ready

**Regional failover ready** is for mission-critical workloads that need a backup environment in a paired Azure region to recover from regional incidents. This scenario builds on the Zone-redundant tier by adding cross-region data replication and networking scaffolding to support manual failover to a secondary region.  

> [!IMPORTANT]
> The template does NOT implement automated cross‑region failover (secondary AI Search/OpenAI/Storage resources, data replication, DNS or traffic management, or orchestration). Use the provided dual-region networking plus the guidance below as the foundation for your own secondary provisioning, replication, runbooks, and traffic failover automation.

#### Regional Failover Ready Recommendations

**Azure Storage:**

- Set `cps_storage_replication_type = "Standard_RA_GZRS"` (or `Standard_GZRS` if secondary read access is unnecessary) to combine zone redundancy with cross-region replication.
- Select paired Azure regions that support geo-redundant storage.

**Azure AI Search:**

- Configure the primary region with zone-capable settings: `sku = "standard"` (or higher), `replica_count = 3`, and `partition_count` based on data volume.
- **GAP:** Manually provision a secondary Azure AI Search service in the paired region when failover is required.
- **GAP:** Re-ingest or replicate AI Search data, storage blobs, and custom indexes before the secondary environment can serve traffic.

**Azure OpenAI:**

- Use the same configuration as Zone-redundant tier: `S0` SKU with your chosen deployment type (`Standard`, `ProvisionedManaged`, etc.).
- **GAP:** Manually create a secondary Azure OpenAI resource in the paired region when executing a failover plan.
- **GAP:** Configure private endpoints in the secondary region to enable secure connectivity.

**Power Platform:**

- Set `power_platform_environment.environment_type = "Production"` to enable zone redundancy in the primary region.
- **GAP:** Configure the Azure AI Search connector to use service principal authentication instead of API keys (required for regional failover since API keys differ between primary and secondary AI Search instances).
  - Set `AZURE_AI_SEARCH_SERVICE_PRINCIPAL_CLIENT_ID`, `AZURE_AI_SEARCH_ENTERPRISE_APPLICATION_OBJECT_ID`, and `AZURE_AI_SEARCH_SERVICE_PRINCIPAL_CLIENT_SECRET` environment variables per the [AI Search connection documentation](ai_search_connection.md).
  - The service principal will be assigned `Search Index Data Reader` and `Reader` roles on both primary and secondary AI Search instances.
- **GAP:** Update the Power Platform AI Search connection endpoint to point to an Azure Traffic Manager endpoint (instead of the direct AI Search service endpoint) to enable automatic failover routing between primary and secondary regions.
  - Modify `infra/main.connections.tf` to replace `local.search_endpoint_url` with your Traffic Manager FQDN.
  - Ensure Traffic Manager is configured with health probes monitoring both AI Search instances and priority-based routing.
- **GAP:** Enable Power Platform self-service disaster recovery for production environments so managed backups live in the secondary region and solution packages fail over with no redeployment.

**Networking:**

- The template automatically provisions secondary-region networking scaffolding (VNets, subnets, NAT gateways, private-endpoint subnets) to host failover resources.
- **GAP:** Configure DNS-based failover using Azure Traffic Manager, Front Door, or scripted DNS updates to complete the failover automation.
- **GAP:** Ensure private endpoints are created in both primary and secondary VNets for seamless network path switching.

**Application Insights:**

- Enable Application Insights via `include_app_insights = true` for production monitoring and telemetry.
- **GAP:** For multi-region monitoring, manually deploy additional Application Insights instances in the secondary region or configure cross-region telemetry collection.

## Disaster Recovery Testing and Rehearsal

This template does not provide automated disaster recovery testing or failover orchestration. For production environments implementing zone-redundant or regional failover configurations, we strongly recommend establishing a regular DR testing practice.

### Recommended Testing Practices

**Failover Planning and Documentation:**

- Document complete failover runbooks with step-by-step procedures for declaring a disaster, activating secondary resources, and switching traffic.
- Identify roles and responsibilities for executing failover, including on-call contacts and escalation paths.
- Define clear success criteria and rollback procedures for each failover scenario.

**Infrastructure Preparation:**

- Pre-build Infrastructure-as-Code overlays, Terraform modules, or deployment scripts that can quickly instantiate secondary-region workload resources (AI Search, Storage, OpenAI) when failover is declared.
- Automate data replication and synchronization processes to ensure secondary resources have current data.
- Configure DNS failover automation using Azure Traffic Manager, Front Door, or scripted DNS updates.

**Regular Failover Drills:**

- Schedule and execute regular failover drills (quarterly or semi-annually for production environments) to validate your disaster recovery plan.
- Test the complete failover workflow: flip traffic, rehydrate data, validate application functionality, and verify monitoring/alerting.
- Validate connectivity, data freshness, authentication flows, and end-to-end application behavior during simulated regional or zone-level outages.
- Document lessons learned and update runbooks based on drill findings.

**Post-Failover Validation:**

- Develop automated smoke tests that verify critical functionality after failover (AI Search queries, Power Platform agent responses, data retrieval).
- Configure monitoring and alerting in both primary and secondary regions to detect performance degradation or service unavailability.
- Establish metrics for Recovery Time Objective (RTO) and Recovery Point Objective (RPO) and measure actual performance during drills.

**Note:** Disaster recovery testing is a critical operational practice that extends beyond infrastructure provisioning. Organizations should invest in regular rehearsal to ensure confidence in their ability to recover from incidents.

## CI/CD Infrastructure Considerations

The CI/CD infrastructure (GitHub runners and supporting resources) deployed by the `cicd/` Terraform configuration is independent of the main workload infrastructure and can be deployed in any Azure region.

### Regional Flexibility

**Runners are region-independent:**

- GitHub runners (both VM-based and Container Apps-based) do not need to be deployed in the same region as your primary or secondary workload infrastructure.
- You can deploy runners in a separate region for cost optimization, compliance requirements, or operational preferences.
- Runner region selection does not impact the ability to deploy infrastructure to any target region.

**Multi-environment deployment:**

- The `cicd/` Terraform configuration can be executed multiple times with different region settings to create runners in multiple Azure regions.
- This supports scenarios where you want geographically distributed build infrastructure or region-specific compliance requirements.
- Each runner deployment is independent and can target different subscription, resource group, or region configurations.

**Deployment flexibility:**

- Runners communicate with GitHub over HTTPS and can deploy to any Azure region regardless of where the runner itself is hosted.
- No network adjacency or regional affinity is required between the runner infrastructure and the deployed workload.
- You can deploy CI/CD infrastructure once in a preferred region and use it to provision workloads across multiple primary and secondary regions.

**Recommendation:** For simplicity, deploy CI/CD runners in a single, cost-effective region unless you have specific requirements for multi-region build infrastructure. The runner region does not impact disaster recovery capabilities of the workload itself.

## Known Issues

### Regional Failover Requires Manual Resource Provisioning

**Impact:** The template provisions only the primary-region resources and secondary networking scaffolding. Users implementing regional failover must manually provision and configure multiple critical components.

**Current Behavior:** The following items require manual action for regional failover:

- **Secondary workload resources**: You must manually provision Azure AI Search, Storage, and Azure OpenAI resources in the secondary region when executing a failover plan.
- **Data replication**: AI Search data, Storage blobs (beyond GZRS), and custom indexes must be manually re-ingested or replicated.
- **DNS and traffic management**: Automated failover requires manual configuration of Traffic Manager, Front Door, or DNS automation scripts.
- **Monitoring and validation**: Post-failover smoke tests, monitoring configuration, and runbook maintenance are entirely user-owned.

**Workaround:** Pre-build Infrastructure-as-Code overlays or scripts that instantiate secondary-region workload resources, configure data replication, and automate DNS failover when needed.

**Status:** Work towards full regional failover support depends on user feedback and customer needs.

## References

- [Azure Well-Architected Framework: Reliability](https://learn.microsoft.com/azure/architecture/framework/resiliency/overview)
- [Power Platform Disaster Recovery](https://learn.microsoft.com/power-platform/admin/business-continuity-disaster-recovery)
- [Power Platform Virtual Network Setup (Enterprise Policy dual-VNet requirement)](https://learn.microsoft.com/power-platform/admin/vnet-support-setup-configure)
- [Power Platform Virtual Network Overview & FAQ (Failover requires delegation in both regions)](https://learn.microsoft.com/power-platform/admin/vnet-support-overview#frequently-asked-questions)
- [Azure AI Search Geo-Redundancy](https://learn.microsoft.com/azure/reliability/reliability-ai-search)

---

**Last updated:** October 15, 2025
