# Decision Log 001: Usage of Azure Verified Modules and Version Management

**Date:** 2025-05-22  
**Status:** Approved

## Context

Our infrastructure-as-code (IaC) solution uses Terraform to provision Azure resources. We leverage **Azure Verified Modules (AVM)** from the official [Azure Terraform Registry](https://registry.terraform.io/namespaces/Azure) to ensure reliability, support, and alignment with Microsoft best practices.

## Decision

- **Module Source**: All Terraform modules are referenced using versioned releases from the official Azure registry (e.g., `Azure/avm-res-keyvault/azurerm`), not Git URLs or commit hashes.
- **Version Pinning**: We use explicit version constraints (e.g., `~> 1.0.0`) in module blocks to allow compatible updates while preventing breaking changes.
- **Security Scanning**: We use [Checkov](https://www.checkov.io/) for static code analysis and policy enforcement.
- **Automated Updates**: We use [Dependabot](https://docs.github.com/code-security/dependabot/working-with-dependabot/keeping-your-actions-up-to-date-with-dependabot) to automatically monitor and update module versions, ensuring we maintain security patches while preserving compatibility.

## Rationale

1. **Maintainability**: Version constraints (`~> x.y.z`) enable safe upgrades and patching, reducing maintenance overhead compared to managing commit hashes.
2. **Official Sources**: Using only Azure Verified Modules ensures modules are maintained, tested, and supported by Microsoft.
3. **CI/CD Compatibility**: Versioned modules integrate seamlessly with the Azure Developer CLI (`azd`) and our automated pipelines.
4. **Managed Updates**: Utilizing Dependabot for version monitoring enables our team to maintain currency with module updates while retaining control over the update process. This approach allows for proper testing of proposed updates rather than implicit acceptance, which is particularly valuable given that Azure Verified Modules may occasionally deviate from strict semantic versioning practices. [Dependabot's selective upgrade approval system](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/controlling-dependencies-updated) provides essential safeguards in our module management strategy.

## Exception: CKV_TF_1 Policy

- **Checkov Policy**: `CKV_TF_1` enforces the use of commit hashes in module sources to mitigate supply chain risks.
- **Our Approach**: We intentionally bypass `CKV_TF_1` in AI, Network, and Storage modules using the following comment:

    ```hcl
    # checkov:skip=CKV_TF_1: Using published module version for maintainability. See decision-log/001-avm-usage-and-version.md for details.
    ```

- **Justification**: Published, versioned modules from the Azure registry are trusted and maintained. This approach balances security with maintainability and aligns with our architectural standards. Additionally,`CKV_TF_1` is not compatible with Dependabot to update the versions of the AVM modules that we use.

## Security Considerations

- We monitor module updates and security advisories from the Azure registry.
- We review module changelogs before upgrading versions.
- We document all policy exceptions and review them periodically.

## References

- [Azure Verified Modules Registry](https://github.com/Azure/terraform-azure-modules)
- [Checkov terraform resource scans](https://www.checkov.io/5.Policy%20Index/terraform.html)

---

