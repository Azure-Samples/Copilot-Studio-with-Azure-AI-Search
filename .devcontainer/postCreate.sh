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

echo "Post-create setup completed successfully!"
