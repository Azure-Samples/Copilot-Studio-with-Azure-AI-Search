# Development Environment

This document describes the development environment configuration for the project. The environment supports both containerized (dev container) and local development workflows.

## Environment Options

### Dev Container or GitHub Codespaces (Recommended)

Pre-configured container with all required dependencies and tools. No manual installation required.

### Local Development

Manual installation of tools listed in the Required Tools section below.

#### Required Tools

The following tools are essential for project development. Dev container users can skip installation as these are pre-provisioned.

| Tool | Installation Guide |
|------|-------------------|
| [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd) | Platform-specific installers available via package managers or direct download |
| [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.5) | Required for non-Windows systems; Windows users may use built-in PowerShell |
| [.NET 8.0 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0) | Includes .NET CLI, runtime, and development tools |
| [Terraform](https://developer.hashicorp.com/terraform) | HashiCorp official distribution via package manager or binary |
| [TFLint](https://github.com/terraform-linters/tflint) | Optional but recommended for infrastructure validation |
| [PAC CLI](https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction) | Microsoft Power Platform developer tooling |
| [Gitleaks](https://github.com/gitleaks/gitleaks) | Pre-commit hook integration recommended |
