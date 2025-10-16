# Decision Log 006: Azure OpenAI Soft-Delete Purge in CI/CD

**Date:** 2025-10-16  
**Status:** Approved

## Context

Azure OpenAI (Cognitive Services) resources implement a soft-delete feature for data protection. When resources are deleted via `azd down` or Terraform `destroy`, they enter a soft-deleted state and remain in the subscription's "recently deleted" list for a retention period (typically 48 hours). During this time, the resource name is reserved and cannot be reused.

This creates a problem for CI/CD workflows that:
1. Deploy infrastructure with deterministic resource names based on environment
2. Run automated tests
3. Clean up resources after testing
4. Attempt to redeploy with the same resource names

The second deployment fails because the soft-deleted resource with the same name still exists in the purge queue.

## Decision

We implement a post-destruction purge step in GitHub Actions workflows to immediately remove soft-deleted Azure OpenAI resources after `azd down` completes. This is implemented directly in workflow files rather than as an azd hook because:

1. **azd Hook Limitations**: Azure Developer CLI (azd) does not currently support `postdown` or `predestroy` hooks
2. **Workflow Control**: GitHub Actions workflows provide better visibility and control over the purge process
3. **Error Handling**: Workflow steps can gracefully handle cases where resources are not in soft-delete state

## Implementation

### Terraform Output Addition

Added `openai_resource_name` output to `infra/outputs.tf`:

```hcl
output "openai_resource_name" {
  description = "The name of the Azure OpenAI resource (for purging soft-deleted resources)"
  value       = module.azure_open_ai.resource.name
}
```

This exposes the resource name to azd environment values for use in the purge command.

### Workflow Step Addition

Added "Purge Soft-Deleted Azure OpenAI Resources" step to both:
- `.github/workflows/azure-dev.yml` (after "Destroy Infrastructure" step)
- `.github/workflows/azure-dev-down.yml` (after "Azd down" step)

The purge step:
1. Retrieves resource metadata from `azd env get-values` output
2. Executes `az cognitiveservices account purge` command
3. Continues gracefully if resource is not found or already purged
4. Only runs when infrastructure destruction occurs (PR builds or manual trigger with `run_azd_down`)

### Command Used

```bash
az cognitiveservices account purge \
  --location "$AZURE_REGION" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$OPENAI_RESOURCE_NAME"
```

## Rationale

1. **CI/CD Reliability**: Ensures subsequent deployments with the same resource names succeed without manual intervention
2. **Cost Optimization**: Immediately releases resources rather than waiting for the retention period to expire
3. **Clean State**: Prevents accumulation of soft-deleted resources in the subscription
4. **Automation**: No manual Azure Portal interaction required to purge resources
5. **Safety**: Error handling prevents workflow failure if resource is already purged or not in soft-delete state

## Alternative Approaches Considered

### 1. Dynamic Resource Naming
**Rejected**: Would require changing naming strategy and complicate resource tracking across deployments

### 2. Manual Purge Between Deployments
**Rejected**: Defeats the purpose of automated CI/CD and introduces human error

### 3. Terraform Custom Provisioner
**Rejected**: Terraform provisioners are a last resort and azd handles destroy operations outside direct Terraform control

### 4. Wait for Retention Period
**Rejected**: 48-hour wait between deployments is unacceptable for CI/CD velocity

## Consequences

### Positive
- Automated, reliable CI/CD deployments with consistent resource naming
- No manual intervention required for resource cleanup
- Clear audit trail of purge operations in workflow logs

### Negative
- Adds minor complexity to workflow files
- Requires Azure CLI authentication in workflows (already present)
- Purge operation is permanent and cannot be undone

### Neutral
- Purge step execution time is minimal (typically < 5 seconds)
- Requires `openai_resource_name` output to be maintained in Terraform

## References

- [Azure Cognitive Services soft-delete documentation](https://learn.microsoft.com/azure/cognitive-services/manage-resources-deletion-recovery)
- [Azure CLI cognitiveservices account purge command](https://learn.microsoft.com/cli/azure/cognitiveservices/account?view=azure-cli-latest#az-cognitiveservices-account-purge)
- [Azure Developer CLI hooks documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-extensibility)
- GitHub Issue #309: Azure OpenAI Resources Soft-Deleted
