FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies (incl. prerequisites for PowerShell, .NET, Azure CLI, Python 3.10)
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    software-properties-common \
    lsb-release \
    gnupg \
    curl \
    wget \
    unzip \
    git \
    jq \
    build-essential \
    libssl-dev \
    libffi-dev \
    ca-certificates \
    python3.10 \
    python3.10-distutils \
    python3.10-venv \
    python3-pip \
    nodejs \
    npm \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Make python3 point to python3.10
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# ----------------------------
# Install Microsoft package feed (PowerShell + .NET)
# ----------------------------
RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm -f /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y \
         powershell \
         dotnet-sdk-7.0 \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Install Azure CLI
# ----------------------------
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg \
    && install -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/ \
    && AZ_REPO=$(lsb_release -cs) \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" \
       | tee /etc/apt/sources.list.d/azure-cli.list \
    && rm -f /tmp/microsoft.gpg \
    && apt-get update \
    && apt-get install -y azure-cli \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for running GitHub Actions runner
RUN useradd -m -s /bin/bash runner

# Set working directory
WORKDIR /home/runner

# Download & extract GitHub Actions runner
ARG RUNNER_VERSION=2.311.0
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        RUNNER_ARCH="arm64"; \
    elif [ "$ARCH" = "x86_64" ]; then \
        RUNNER_ARCH="x64"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    curl -o actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz -L \
      https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz && \
    tar xzf actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz && \
    rm actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz

# Install any additional runner dependencies
RUN ./bin/installdependencies.sh

# Ensure runner owns its home directory
RUN chown -R runner:runner /home/runner

# Copy entrypoint script (assumed to be in the build context)
COPY --chown=runner:runner entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Healthcheck for Azure Container Apps (optional)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health 2>/dev/null || exit 1

# Switch to non-root user
USER runner

# Expose port if entrypoint serves HTTP
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
