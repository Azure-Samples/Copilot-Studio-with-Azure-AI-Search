# !/bin/bash

# GitHub Actions Runner Installation Script
# This script installs and configures a GitHub Actions self-hosted runner

set -e

# Variables passed from Terraform
RUNNER_NAME="${runner_name}"
GITHUB_URL="${github_url}"
GITHUB_RUNNER_TOKEN="${github_runner_token}"
REPO_NAME="${repo_name}"
REPO_OWNER="${repo_owner}"

echo "Runner Name: '$RUNNER_NAME'"
echo "Github URL: '$GITHUB_URL'"
echo "Github Runner Token: '$GITHUB_RUNNER_TOKEN'"
echo "Repo Name: '$REPO_NAME'"
echo "Repo Owner: '$REPO_OWNER'"


echo "GITHUB_TOKEN1 environment variable: '${GITHUB_TOKEN}'"

# Create a folder
mkdir actions-runner && cd actions-runner # Download the latest runner package
curl -o actions-runner-linux-x64-2.327.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-x64-2.327.1.tar.gz # Optional: Validate the hash
echo "d68ac1f500b747d1271d9e52661c408d56cffd226974f68b7dc813e30b9e0575  actions-runner-linux-x64-2.327.1.tar.gz" | shasum -a 256 -c # Extract the installer
tar xzf ./actions-runner-linux-x64-2.327.1.tar.gz

sudo RUNNER_ALLOW_RUNASROOT=true ./config.sh --url $GITHUB_URL --token $GITHUB_RUNNER_TOKEN
./run.sh