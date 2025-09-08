# Configure a Federated Identity Credential for GitHub Actions in Microsoft Entra ID

Use Microsoft Entra workload identity federation to let GitHub Actions exchange an OpenID Connect (OIDC) token for a Microsoft Entra access token—no long‑lived secrets required. This is done by creating a federated identity credential on your app registration (service principal).

For background, see the official guide: [Workload identity federation in Microsoft Entra](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation).

To configure it in the Microsoft Entra admin center, follow these steps:

1. In the Microsoft Entra admin center (Azure Portal): go to **Microsoft Entra ID** → **App registrations** → select your app registration.
1. Open **Certificates & secrets** → **Federated credentials** → **Add credential**.
1. In "Add a credential":
   - If available, choose the template: **GitHub Actions deploying to Azure**. This sets the correct Issuer and Audience and guides Subject selection.
   - **Issuer**: `https://token.actions.githubusercontent.com`
   - **Audience**: `api://AzureADTokenExchange`
   - **Subject identifier**: pick the least-privilege option for your scenario. Common patterns:
     - `repo:<org>/<repo>:environment:<environment-name>` — restricts to runs that target a specific GitHub environment (benefits from environment approvals/secrets).
     - `repo:<org>/<repo>:ref:refs/heads/<branch-name>` — allows runs on a specific branch (simple but broader within that branch).
     - `repo:<org>/<repo>:pull_request` — enables PR workflows (good for ephemeral validation; be mindful of fork settings).
     - `repo:<org>/<repo>:ref:refs/tags/<tag-name>` — for tag-triggered releases.
     - `repository_id:<numeric-id>:environment:<environment-name>` — resilient to repo rename/transfer (uses repository ID).
   - Click **Add**.

## Next steps

- In your GitHub repository, save these values as repository-level Actions Variables (Settings → Secrets and variables → Actions → Variables). The workflows in this repo read them as `${{ vars.* }}`:
  - `AZURE_CLIENT_ID` — Application (client) ID of your app registration.
  - `AZURE_TENANT_ID` — Microsoft Entra tenant ID.
  - `AZURE_SUBSCRIPTION_ID` — Azure subscription ID used for deployments.

## Additional considerations

- GitHub workflows must set the following permissions to use OIDC authentication `id-token: write` and `contents: read`.
- Workflows use `azure/login` (v2+) with your app registration's `client-id`, `tenant-id`, and `subscription-id` to obtain tokens via OIDC.
- Assign least-privileged RBAC to the app registration's service principal at the target scope (resource group or resource), granting only the roles it needs.
- By default this repo assumes a single cicd credential that can create any environment, you may want to adapt the workflows to use multiple federated credentials to separately scope branches, environments, and release tags.

## References

- [Microsoft Entra: Workload identity federation overview](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [Microsoft Entra: Create a federated identity credential (portal)](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust-portal)
- [GitHub: About security hardening with OpenID Connect](https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Azure Login action](https://github.com/Azure/login)

