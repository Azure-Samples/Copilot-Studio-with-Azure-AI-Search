# Troubleshooting tips

## Quota error during deployment

If you see an InsufficientQuota error mentioning "Tokens Per Minute", the requested `scale.capacity` (thousands of TPM) exceeds your subscription's available quota — lower `scale.capacity` in TFVARS or request a quota increase in the Azure portal.

## Private endpoint fails with AccountProvisioningStateInvalid

This occurs when Terraform tries to create the private endpoint before the Azure OpenAI (Cognitive Services) account leaves the `Accepted` state; wait until the resource shows `Succeeded` (portal or `az resource show`) and re-run the provisioning (`azd provision`).

## Use GitHub Copilot to help troubleshoot

If you're unsure how to fix a deployment error, open the relevant files in VS Code and use GitHub Copilot for suggestions. Copilot can propose TFVARS overrides, sample values, terraform plan snippets, or concise support-request wording; always review and test generated suggestions before applying them.
