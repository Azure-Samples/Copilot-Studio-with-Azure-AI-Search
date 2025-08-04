# !/bin/bash

# GitHub Actions Runner Installation Script
# This script installs and configures a GitHub Actions self-hosted runner

set -e

# Variables passed from Terraform
RUNNER_NAME="${runner_name}"
REPO_NAME="${repo_name}"
REPO_OWNER="${repo_owner}"
GITHUB_TOKEN="${github_token}"

echo "Runner Name: '$RUNNER_NAME'"
echo "Repo Name: '$REPO_NAME'"
echo "Repo Owner: '$REPO_OWNER'"

# Get registration token
$registration_resp=$(curl --request POST \
    --url "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runners/registration-token" \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer $GITHUB_TOKEN" \
    --header "X-GitHub-Api-Version: 2022-11-28")

echo "Response: ${registration_resp}"

if [ $? -ne 0 ]; then
    echo "Failed to get registration token"
    exit 1
fi

# Extract the token from the response
$github_runner_token=$(echo "$registration_resp" | jq -r '.token')
echo "GitHub Runner Token: '$github_runner_token'"

# Create a folder
mkdir actions-runner && cd actions-runner # Download the latest runner package
curl -o actions-runner-linux-x64-2.327.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-x64-2.327.1.tar.gz # Optional: Validate the hash
echo "d68ac1f500b747d1271d9e52661c408d56cffd226974f68b7dc813e30b9e0575  actions-runner-linux-x64-2.327.1.tar.gz" | shasum -a 256 -c # Extract the installer
tar xzf ./actions-runner-linux-x64-2.327.1.tar.gz

exit 4
# sudo RUNNER_ALLOW_RUNASROOT=true ./config.sh --url $GITHUB_URL --token $GITHUB_RUNNER_TOKEN
# ./run.sh