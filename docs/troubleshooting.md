# Troubleshooting tips

## Quota error during deployment

If you see an InsufficientQuota error mentioning "Tokens Per Minute", the requested `scale.capacity` (thousands of TPM) exceeds your subscription's available quota — lower `scale.capacity` in TFVARS or request a quota increase in the Azure portal.

## Private endpoint fails with AccountProvisioningStateInvalid

This occurs when Terraform tries to create the private endpoint before the Azure OpenAI (Cognitive Services) account leaves the `Accepted` state; wait until the resource shows `Succeeded` (portal or `az resource show`) and re-run the provisioning (`azd provision`).

## Azure OpenAI resource name already exists error

If you encounter an error like `Code="ResourceNameAlreadyExists" Message="The resource name 'oai-copilot-studio-xyz' is already in use"` during deployment, this typically indicates that an Azure OpenAI resource with the same name exists in a soft-deleted state.

**Symptoms:**
- Deployment fails with `ResourceNameAlreadyExists` error
- The resource was previously deleted via `azd down` or Terraform destroy
- Error occurs within 48 hours of the previous deletion

**Cause:**
Azure OpenAI (Cognitive Services) resources are soft-deleted by default and remain in a "recently deleted" state for 48 hours. During this retention period, the resource name is reserved and cannot be reused.

**Solution:**
In CI/CD workflows, soft-deleted resources are automatically purged after `azd down`. For local development, you can manually purge the resource by following the instructions in the [Clean Up section of the README](../README.md#clean-up).

## Use GitHub Copilot to help troubleshoot

If you're unsure how to fix a deployment error, open the relevant files in VS Code and use GitHub Copilot for suggestions. Copilot can propose TFVARS overrides, sample values, terraform plan snippets, or concise support-request wording; always review and test generated suggestions before applying them.
