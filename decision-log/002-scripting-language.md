# Decision Log 002: PowerShell as the Standard Scripting Language for AZD Hooks

**Date:** 2025-07-17  
**Status:** Approved

## Context

Our infrastructure deployment pipeline uses Azure Developer CLI (azd) to orchestrate infrastructure provisioning and application deployment. The azd tool supports multiple scripting languages for lifecycle hooks, including PowerShell (`pwsh`) and bash (`sh`). We needed to choose a consistent scripting language for implementing all azd hook scripts to ensure maintainability, cross-platform compatibility, and operational consistency.

The azd hooks in our solution include:
- **preprovision**: Security scanning (Gitleaks, Checkov, TFLint) and configuration setup
- **postprovision**: Power Platform solution deployment
- **predeploy/postdeploy**: Application deployment lifecycle management
- **prepackage/postpackage**: Solution packaging and preparation

Our solution requires integration with Azure services, Power Platform CLI (PAC CLI), and enterprise environments that demand robust error handling, logging, and parameter validation capabilities.

## Decision

We will use **PowerShell Core (`pwsh`)** as the standard scripting language for implementing all Azure Developer CLI hook scripts in this repository.

## Rationale

1. **Cross-Platform Compatibility**: PowerShell Core runs natively on Windows, Linux, and macOS, ensuring our deployment scripts work consistently across all development and deployment environments without modification.

2. **Single Script Maintenance**: Using PowerShell exclusively eliminates the need to maintain duplicate scripts in both PowerShell and bash, reducing maintenance overhead and preventing functional divergence between platform-specific implementations.

3. **Superior Azure Integration**: PowerShell provides native cmdlets and the Azure PowerShell module with object-oriented output, offering better integration than bash with Azure CLI's JSON parsing requirements.

4. **Native Power Platform CLI Integration**: The Power Platform CLI (PAC CLI) provides first-class PowerShell cmdlets, eliminating the need for complex JSON parsing and error handling required when using bash.

5. **Enhanced Error Handling**: PowerShell's structured exception handling and built-in error objects provide more robust error management compared to bash's exit codes and string-based error handling.

6. **Developer Experience**: Using a single scripting language reduces the cognitive overhead for developers who need to understand, modify, or troubleshoot deployment scripts.

## Implementation Details

- All azd hooks in `azure.yaml` are configured with `shell: pwsh`
- Hook scripts are located in `azd-hooks/scripts/hooks/` with appropriate subdirectories
- Scripts include comprehensive error handling and parameter validation
- All scripts follow PowerShell best practices including proper parameter binding and verbose logging
- If bash compatibility is required for specific use cases, GitHub Copilot or other LLMs can easily translate our PowerShell scripts to bash

## Alternatives Considered

- **Bash + PowerShell**: Maintaining both bash and PowerShell versions would require duplicate effort and risk functional inconsistencies
- **Bash Only**: Would not provide optimal integration with Azure services and Power Platform CLI, and would require additional tooling on Windows environments

## References

- [PowerShell Cross-Platform Documentation](https://docs.microsoft.com/en-us/powershell/scripting/overview)
- [Azure Developer CLI Documentation](https://docs.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [Power Platform CLI with PowerShell](https://docs.microsoft.com/en-us/power-platform/developer/cli/introduction)

---