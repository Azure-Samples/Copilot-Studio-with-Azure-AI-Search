#!/bin/sh
set -eux

echo "Running post-create setup for interactive operations..."

# Setup tflint plugins directory and initialize
echo "Setting up tflint configuration..."
mkdir -p ~/.tflint.d/plugins
tflint --init

# Install PowerApps CLI (Microsoft.PowerApps.CLI.Tool)
echo "Installing PowerApps CLI..."
dotnet tool install --global Microsoft.PowerApps.CLI.Tool --version 1.43.6

# Restore .NET packages including Microsoft.Agents.CopilotStudio.Client
echo "Restoring .NET packages..."
if [ -f "Directory.Build.props" ]; then
    dotnet restore
    echo ".NET packages restored successfully!"
else
    # Fallback to individual project restore
    if [ -f "tests/Copilot/CopilotTests.csproj" ]; then
        dotnet restore tests/Copilot/CopilotTests.csproj
        echo "Copilot project packages restored successfully!"
    else
        echo "No .NET projects found, skipping package restore"
    fi
fi

echo "Post-create setup completed successfully!"