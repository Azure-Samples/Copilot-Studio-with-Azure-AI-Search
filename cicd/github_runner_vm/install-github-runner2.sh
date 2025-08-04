# !/bin/bash

# GitHub Actions Runner Installation Script
# This script installs and configures a GitHub Actions self-hosted runner

set -e

# Variables passed from Terraform
RUNNER_NAME="${runner_name}"
RUNNER_GROUP="${runner_group}"
RUNNER_WORK_FOLDER="${runner_work_folder}"
REPO_NAME="${repo_name}"
REPO_OWNER="${repo_owner}"
RUNNER_TOKEN="${runner_token}"

echo "Runner Name: '$RUNNER_NAME'"
echo "Repo Name: '$REPO_NAME'"
echo "Repo Owner: '$REPO_OWNER'"
echo "Runner Group: '$RUNNER_GROUP'"
echo "Runner Work Folder: '$RUNNER_WORK_FOLDER'"
echo "GitHub Runner Token: '$RUNNER_TOKEN'"

# Create a folder
mkdir actions-runner && cd actions-runner # Download the latest runner package
curl -o actions-runner-linux-x64-2.327.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-x64-2.327.1.tar.gz # Optional: Validate the hash
echo "d68ac1f500b747d1271d9e52661c408d56cffd226974f68b7dc813e30b9e0575  actions-runner-linux-x64-2.327.1.tar.gz" | shasum -a 256 -c # Extract the installer
tar xzf ./actions-runner-linux-x64-2.327.1.tar.gz

export RUNNER_ALLOW_RUNASROOT=1
./config.sh --url $GITHUB_URL --token $RUNNER_TOKEN --runnergroup $RUNNER_GROUP --name $RUNNER_NAME --labels $RUNNER_NAME --work $RUNNER_WORK_FOLDER

#register ./run.sh as a systemd service
# echo "[Unit]
# Description=GitHub Actions Runner
# After=network.target

# [Service]
# ExecStart=$(pwd)/run.sh
# User=azureuser
# WorkingDirectory=$(pwd)
# Restart=always
# RestartSec=5

# [Install]
# WantedBy=multi-user.target
# " | sudo tee /etc/systemd/system/github-runner.service

# sudo systemctl enable github-runner.service

# Start the runner
#echo "Starting the runner"
./run.sh


