#!/bin/sh
set -eux

echo "Running post-create setup for interactive operations..."

# Setup tflint plugins directory and initialize
echo "Setting up tflint configuration..."
mkdir -p ~/.tflint.d/plugins
tflint --init



echo "Post-create setup completed successfully!"