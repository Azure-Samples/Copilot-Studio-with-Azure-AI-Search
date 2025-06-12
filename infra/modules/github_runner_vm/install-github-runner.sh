# !/bin/bash

# GitHub Actions Runner Installation Script
# This script installs and configures a GitHub Actions self-hosted runner

set -e

# Variables passed from Terraform
GITHUB_URL="${github_url}"
GITHUB_TOKEN="${github_token}"
RUNNER_NAME="${runner_name}"
RUNNER_WORK_FOLDER="${runner_work_folder}"
RUNNER_GROUP="${runner_group}"
RUNNER_LABELS="${runner_labels}" 

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/github-runner-install.log
}

# Network diagnostics function
run_network_diagnostics() {
    log "Running network diagnostics..."
    
    # Check basic network configuration
    log "Network interfaces:"
    ip addr show | tee -a /var/log/github-runner-install.log
    
    log "Routing table:"
    ip route show | tee -a /var/log/github-runner-install.log
    
    log "DNS configuration:"
    cat /etc/resolv.conf | tee -a /var/log/github-runner-install.log
    
    # Test DNS resolution
    log "Testing DNS resolution..."
    nslookup google.com | tee -a /var/log/github-runner-install.log || log "DNS resolution failed"
    
    # Test internet connectivity
    log "Testing internet connectivity..."
    ping -c 3 8.8.8.8 | tee -a /var/log/github-runner-install.log || log "Ping to 8.8.8.8 failed"
    
    # Test HTTPS connectivity
    log "Testing HTTPS connectivity..."
    curl -I https://google.com --connect-timeout 10 | tee -a /var/log/github-runner-install.log || log "HTTPS test failed"
    
    # Test specific GitHub connectivity
    log "Testing GitHub connectivity..."
    curl -I https://github.com --connect-timeout 10 | tee -a /var/log/github-runner-install.log || log "GitHub connectivity test failed"
    curl -I https://api.github.com --connect-timeout 10 | tee -a /var/log/github-runner-install.log || log "GitHub API connectivity test failed"
    
    # Test package repository connectivity
    log "Testing package repository connectivity..."
    curl -I https://packages.microsoft.com --connect-timeout 10 | tee -a /var/log/github-runner-install.log || log "Microsoft packages connectivity test failed"
    curl -I https://deb.nodesource.com --connect-timeout 10 | tee -a /var/log/github-runner-install.log || log "NodeSource connectivity test failed"
}

log "Starting GitHub Actions Runner installation..."

# Run initial network diagnostics
run_network_diagnostics

# Wait for network to be fully ready
log "Waiting for network to be ready..."
sleep 30

# Configure DNS to use reliable DNS servers
log "Configuring DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Update system packages with retries
log "Updating system packages..."
for i in {1..3}; do
    if apt-get update -y; then
        log "Package list update successful on attempt $i"
        break
    else
        log "Package list update failed on attempt $i, retrying in 30 seconds..."
        sleep 30
    fi
done

for i in {1..3}; do
    if apt-get upgrade -y; then
        log "Package upgrade successful on attempt $i"
        break
    else
        log "Package upgrade failed on attempt $i, retrying in 30 seconds..."
        sleep 30
    fi
done

# Install required packages with retries
log "Installing required packages..."
PACKAGES="curl wget unzip git jq build-essential libssl-dev libffi-dev python3 python3-pip docker.io nodejs npm"

for i in {1..3}; do
    if apt-get install -y $PACKAGES; then
        log "Package installation successful on attempt $i"
        break
    else
        log "Package installation failed on attempt $i, retrying in 30 seconds..."
        sleep 30
        # Run diagnostics again to see what changed
        run_network_diagnostics
    fi
done

# Verify critical packages are installed
log "Verifying package installations..."
for package in curl wget git jq docker.io; do
    if dpkg -l | grep -q "^ii  $package "; then
        log "$package is installed successfully"
    else
        log "WARNING: $package installation may have failed"
    fi
done

# Start and enable Docker
log "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Add azureuser to docker group
usermod -aG docker azureuser

# Create a dedicated user for the runner
log "Creating GitHub runner user..."
useradd -m -d /home/github-runner -s /bin/bash github-runner
usermod -aG docker github-runner

# Create runner directory
RUNNER_DIR="/home/github-runner/actions-runner"
mkdir -p "$RUNNER_DIR"
chown -R github-runner:github-runner /home/github-runner

# Download and extract the GitHub Actions runner
log "Downloading GitHub Actions runner..."
cd "$RUNNER_DIR"

# Get the latest runner version from GitHub API with retries
log "Fetching latest GitHub Actions runner version..."
for i in {1..3}; do
    if RUNNER_VERSION=$(curl -s --connect-timeout 30 https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//'); then
        log "Successfully retrieved runner version: $RUNNER_VERSION on attempt $i"
        break
    else
        log "Failed to retrieve runner version on attempt $i, retrying in 30 seconds..."
        sleep 30
    fi
done

if [ -z "$RUNNER_VERSION" ] || [ "$RUNNER_VERSION" == "null" ]; then
    log "ERROR: Could not retrieve GitHub Actions runner version. Using fallback version 2.311.0"
    RUNNER_VERSION="2.325.0"
fi

RUNNER_TARBALL="actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/$${RUNNER_TARBALL}"

# Download the runner with retries
log "Downloading runner from: $RUNNER_URL"
for i in {1..3}; do
    if wget --timeout=60 --tries=3 "$RUNNER_URL"; then
        log "Runner download successful on attempt $i"
        break
    else
        log "Runner download failed on attempt $i, retrying in 30 seconds..."
        sleep 30
        # Test connectivity again
        curl -I https://github.com --connect-timeout 10 | tee -a /var/log/github-runner-install.log || log "GitHub connectivity still failing"
    fi
done

# Verify download
if [ ! -f "$RUNNER_TARBALL" ]; then
    log "ERROR: Runner tarball not found after download attempts"
    exit 1
fi

# Extract the runner
log "Extracting GitHub Actions runner..."
tar -xzf "$${RUNNER_TARBALL}"
rm "$${RUNNER_TARBALL}"

# Set ownership
chown -R github-runner:github-runner "$RUNNER_DIR"

# Configure the runner
log "Generating runner registration token..."

API_REGISTRATION_URL="https://api.github.com/repos/phongcao/Copilot-Studio-with-Azure-AI-Search/actions/runners/registration-token"

# Get registration token with error handling
log "Requesting registration token from GitHub API..."
API_RESPONSE=$(curl -s \
  -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "$API_REGISTRATION_URL")

if [ $? -ne 0 ]; then
    log "ERROR: Failed to call GitHub API"
    exit 1
fi

REG_TOKEN=$(echo "$API_RESPONSE" | jq -r '.token // empty')

if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" == "null" ]; then
log "ERROR: Could not obtain runner registration token."
exit 1
fi

log "Successfully obtained runner registration token."

log "Configuring GitHub Actions runner..."
sudo -u github-runner bash -c "cd '$RUNNER_DIR' && ./config.sh --url '$GITHUB_URL' --token '$REG_TOKEN' --name '$RUNNER_NAME' --work '$RUNNER_WORK_FOLDER' --labels '$RUNNER_LABELS' --unattended --replace"

# Install the runner as a service
log "Installing runner as a service..."
cd "$RUNNER_DIR"
./svc.sh install github-runner

# Start the runner service
log "Starting runner service..."
./svc.sh start

# Get the actual service name that was created
SERVICE_NAME=$(systemctl list-units --type=service | grep "actions.runner" | awk '{print $1}' | head -1)

if [ -n "$SERVICE_NAME" ]; then
    log "Found service: $SERVICE_NAME"
    # Enable the service to start on boot
    systemctl enable "$SERVICE_NAME"
    log "Service $SERVICE_NAME enabled for startup"
else
    log "WARNING: Could not find actions.runner service to enable"
fi

# Create a simple health check script
log "Creating health check script..."
cat > /usr/local/bin/github-runner-health.sh << 'EOF'
#!/bin/bash
# Find the actual service name
SERVICE_NAME=$(systemctl list-units --type=service | grep "actions.runner" | awk '{print $1}' | head -1)

if [ -n "$SERVICE_NAME" ] && systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "GitHub Runner is running (service: $SERVICE_NAME)"
    exit 0
else
    echo "GitHub Runner is not running"
    exit 1
fi
EOF

chmod +x /usr/local/bin/github-runner-health.sh

# Setup log rotation for runner logs
log "Setting up log rotation..."
cat > /etc/logrotate.d/github-runner << 'EOF'
/home/github-runner/actions-runner/_diag/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 github-runner github-runner
}
EOF

# Create a maintenance script
log "Creating maintenance script..."
cat > /usr/local/bin/github-runner-maintenance.sh << 'EOF'
#!/bin/bash
# GitHub Runner Maintenance Script

# Clean old Docker images
docker system prune -af --filter "until=24h"

# Clean runner temporary files
find /home/github-runner/actions-runner/_work -name "*.tmp" -mtime +1 -delete 2>/dev/null || true

# Restart runner if it's been running for more than 7 days
RUNNER_PID=$(pgrep -f "Runner.Listener")
if [ ! -z "$RUNNER_PID" ]; then
    RUNNER_START=$(ps -o lstart= -p $RUNNER_PID | sed 's/^ *//')
    RUNNER_START_SEC=$(date -d "$RUNNER_START" +%s)
    CURRENT_SEC=$(date +%s)
    DIFF_DAYS=$(( ($CURRENT_SEC - $RUNNER_START_SEC) / 86400 ))
    
    if [ $DIFF_DAYS -gt 7 ]; then
        echo "Restarting runner after 7 days of uptime"
        # Find the actual service name
        SERVICE_NAME=$(systemctl list-units --type=service | grep "actions.runner" | awk '{print $1}' | head -1)
        if [ -n "$SERVICE_NAME" ]; then
            systemctl restart "$SERVICE_NAME"
        fi
    fi
fi
EOF

chmod +x /usr/local/bin/github-runner-maintenance.sh

# Add maintenance script to cron (run daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/github-runner-maintenance.sh") | crontab -

# Install Azure CLI for potential Azure integrations
log "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install additional useful tools for CI/CD
log "Installing additional CI/CD tools..."
# Install .NET SDK
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get update
apt-get install -y dotnet-sdk-8.0

# Install PowerShell
apt-get install -y powershell

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

# Install GitHub CLI
type -p curl >/dev/null || (apt update && apt install curl -y)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt update
apt install -y gh

# Create status file
log "Creating status file..."
echo "GitHub Actions Runner installed successfully on $(date)" > /home/github-runner/installation-status.txt
echo "Runner Name: $RUNNER_NAME" >> /home/github-runner/installation-status.txt
echo "GitHub URL: $GITHUB_URL" >> /home/github-runner/installation-status.txt
chown github-runner:github-runner /home/github-runner/installation-status.txt

log "GitHub Actions Runner installation completed successfully!"
log "Runner Name: $RUNNER_NAME"
log "GitHub URL: $GITHUB_URL"

# Get the actual service name for status check
SERVICE_NAME=$(systemctl list-units --type=service | grep "actions.runner" | awk '{print $1}' | head -1)
if [ -n "$SERVICE_NAME" ]; then
    SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo 'Not running')
    log "Service Status: $SERVICE_STATUS (service: $SERVICE_NAME)"
else
    log "Service Status: Not found"
fi

# Final system optimization
log "Performing final system optimization..."
# Increase file descriptor limits for the runner
echo "github-runner soft nofile 65536" >> /etc/security/limits.conf
echo "github-runner hard nofile 65536" >> /etc/security/limits.conf

# Optimize kernel parameters for CI/CD workloads
echo "fs.file-max = 2097152" >> /etc/sysctl.conf
echo "vm.max_map_count = 262144" >> /etc/sysctl.conf
sysctl -p

log "Installation and configuration completed!"
