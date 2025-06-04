#!/bin/bash

# GitHub Actions Self-Hosted Runner - Container Build Script
# This script builds and pushes the GitHub runner container image to Azure Container Registry

set -e

# Configuration
REGISTRY_NAME="${ACR_LOGIN_SERVER}"
IMAGE_NAME="${GITHUB_RUNNER_IMAGE_NAME:-github-runner}"
VERSION="${GITHUB_RUNNER_IMAGE_TAG:-latest}"
DOCKERFILE_PATH="./infra/containers/github-runner"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fail early if registry isn’t specified
if [[ -z "$REGISTRY_NAME" ]]; then
    print_error "Azure Container Registry login server not specified. Please set the ACR_LOGIN_SERVER environment variable."
    exit 1
fi

# Check if required tools are installed
check_requirements() {
    print_status "Checking requirements..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install Azure CLI first."
        exit 1
    fi

    print_status "All requirements satisfied."
}

# Login to Azure Container Registry
login_to_acr() {
    print_status "Logging in to Azure Container Registry..."

    if [ -n "$ACR_USERNAME" ] && [ -n "$ACR_PASSWORD" ]; then
        # Use username/password authentication
        echo "$ACR_PASSWORD" | docker login "$REGISTRY_NAME" --username "$ACR_USERNAME" --password-stdin
    else
        # Use Azure CLI authentication
        az acr login --name "${REGISTRY_NAME%%.azurecr.io}"
    fi

    print_status "Successfully logged in to ACR."
}

build_image_amd64() {
    print_status "Building amd64 container image..."

    # Create (or reuse) a builder called "amd64-builder"
    if ! docker buildx ls | grep -q "amd64-builder"; then
        print_status "Creating amd64-only builder..."
        docker buildx create --name amd64-builder --use
    else
        docker buildx use amd64-builder
    fi

    print_status "Running buildx for linux/amd64..."

    docker buildx build \
        --platform linux/amd64 \
        --file "$DOCKERFILE_PATH/Dockerfile" \
        --tag "$REGISTRY_NAME/$IMAGE_NAME:$VERSION" \
        --tag "$REGISTRY_NAME/${IMAGE_NAME}-amd64:$VERSION" \
        --push \
        "$DOCKERFILE_PATH"

    print_status "amd64 image built and pushed successfully."
}

# Main execution
main() {
    print_status "Starting GitHub Runner container build process..."
    print_status "Registry: $REGISTRY_NAME"
    print_status "Image: $IMAGE_NAME:$VERSION"
    print_status "Dockerfile path: $DOCKERFILE_PATH"

    check_requirements
    login_to_acr
    build_image_amd64

    print_status "Build process completed successfully!"
    print_status "Image available at: $REGISTRY_NAME/$IMAGE_NAME:$VERSION  (all amd64)"
}

# Run main function
main "$@"
