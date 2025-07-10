#!/bin/sh
set -eux

echo "Installing development tools for Copilot Studio with Azure AI Search..."

# Update pip and install checkov
echo "Installing checkov..."
pip install --upgrade pip
pip install checkov

# Install tflint
echo "Installing tflint..."
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Install gitleaks
echo "Installing gitleaks..."
GITLEAKS_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
curl -L "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION#v}_linux_x64.tar.gz" -o gitleaks.tar.gz
mkdir -p /tmp/gitleaks
tar -xzf gitleaks.tar.gz -C /tmp/gitleaks gitleaks
mv /tmp/gitleaks/gitleaks /usr/local/bin/
rm -rf /tmp/gitleaks gitleaks.tar.gz

# Install PowerApps CLI (Microsoft.PowerApps.CLI.Tool)
echo "Installing PowerApps CLI..."
dotnet tool install --global Microsoft.PowerApps.CLI.Tool

echo "Development tools installation completed successfully!"