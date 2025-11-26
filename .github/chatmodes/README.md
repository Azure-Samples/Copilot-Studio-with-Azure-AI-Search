# Chat Modes for Copilot Studio with Azure AI Search

This directory contains specialized chat modes that provide expert guidance for specific aspects of the Copilot Studio with Azure AI Search template.

## AI Usage Disclaimer

**Important Notice**: AI assistance is helpful but variable. Results depend on model selection, context quality, and evolving technology capabilities. Always validate AI-generated content with qualified professionals, especially for production environments.

_Copilot is powered by AI, so mistakes are possible. Review output carefully before use._

**When using these chatmodes, you must**:

- Review and test all AI-generated code, configurations, and recommendations
- Verify decisions against official documentation and best practices
- Follow your organization's security and compliance requirements
- Be cautious when sharing sensitive information in AI conversations

## Available Chat Modes

### 🚀 Azure Developer CLI Assistant (`azd-assistant.chatmode.md`)

**Intended Use:**

- Learning Azure Developer CLI workflows and best practices
- Deploying secure, observable Copilot Studio environments on Azure
- Setting up enterprise-grade CI/CD pipelines with GitHub Actions
- Making informed deployment and architecture decisions

**Usage Instructions:**

- Activate this chatmode when working with azd deployment or configuration questions
- Ask questions about `azd init`, `azd up`, `azd provision`, and environment management
- Request guidance on CI/CD pipeline setup with OIDC authentication
- Seek help with troubleshooting deployment issues or authentication errors

**Key Features:**

- Context-aware guidance for azd commands and workflows
- Automatic integration with repository-specific Terraform infrastructure
- Choice-based interaction for deployment strategies and security configurations
- Integration with Azure Well-Architected Framework security patterns

## How to Use Chat Modes

### Activation Methods

**Option 1: Direct Reference (Recommended)**

Reference the specific chat mode in your GitHub Copilot Chat interaction:

```text
@workspace Using the azd-assistant chat mode, help me set up CI/CD for this project
```

**Option 2: Context Attachment**

Attach the chat mode file to your conversation for specialized guidance:

```text
Help me configure azd pipeline with the repository-specific requirements
[Attach: .github/chatmodes/azd-assistant.chatmode.md]
```

## Example Interactions

### Getting Started with AZD

```text
@workspace I'm new to Azure Developer CLI. Using the azd-assistant chat mode, 
walk me through initializing this project and setting up my first environment.
```

### CI/CD Pipeline Setup

```text
@workspace Using azd-assistant mode, help me configure GitHub Actions CI/CD 
with the self-hosted runner infrastructure for this repository.
```

### Troubleshooting Deployment Issues

```text
@workspace My azd up is failing with authentication errors. Using azd-assistant 
mode, help me diagnose and fix the issue.
```

### Security Configuration

```text
@workspace Using azd-assistant mode, ensure my pipeline configuration follows 
the security best practices outlined in this repository.
```

## Benefits of Using Chat Modes

### ⚡ **Faster Problem Resolution**

Get targeted expert advice instead of generic responses, with repository-specific context and proven solutions.

### 📚 **Learning Acceleration**

Understand not just how to execute commands, but why specific patterns and configurations are recommended.

### 🎯 **Focused Expertise**

Each mode provides deep specialization rather than broad generalist knowledge, ensuring accurate and detailed guidance.

### 🔄 **Consistency**

All users get the same high-quality, security-focused guidance aligned with repository standards and enterprise best practices.

## Support and Feedback

For issues with chat modes or suggestions for improvements, please refer to the project's [contributing guidelines](./../../CONTRIBUTING.md) and create appropriate issues or pull requests.
