#!/usr/bin/env bash
set -e

# Default values
RUNNER_SCOPE=${RUNNER_SCOPE:-repo}
RUNNER_GROUP=${RUNNER_GROUP:-default}
LABELS=${LABELS:-self-hosted,azure,container-apps}
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}

# Validate required environment variables
if [ -z "$REPO_URL" ]; then
    echo "Error: REPO_URL environment variable is required"
    exit 1
fi

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: ACCESS_TOKEN environment variable is required"
    exit 1
fi

# Parse owner/repo or org from REPO_URL
if [ "$RUNNER_SCOPE" = "repo" ]; then
    REPO_OWNER=$(echo "$REPO_URL" | sed -n 's#.*/\([^/]*\)/\([^/]*\)$#\1#p')
    REPO_NAME=$(echo "$REPO_URL" | sed -n 's#.*/\([^/]*\)/\([^/]*\)$#\2#p')
else
    ORG_NAME=$(echo "$REPO_URL" | sed -n 's#.*/\([^/]*\)$#\1#p')
fi

# Function: get a registration token
get_registration_token() {
    if [ "$RUNNER_SCOPE" = "repo" ]; then
        curl -s -X POST \
            -H "Authorization: token $ACCESS_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runners/registration-token" \
            | jq -r .token
    else
        curl -s -X POST \
            -H "Authorization: token $ACCESS_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/orgs/$ORG_NAME/actions/runners/registration-token" \
            | jq -r .token
    fi
}

# Function: get a removal token
get_removal_token() {
    if [ "$RUNNER_SCOPE" = "repo" ]; then
        curl -s -X POST \
            -H "Authorization: token $ACCESS_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runners/remove-token" \
            | jq -r .token
    else
        curl -s -X POST \
            -H "Authorization: token $ACCESS_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/orgs/$ORG_NAME/actions/runners/remove-token" \
            | jq -r .token
    fi
}

# Cleanup function: runs on SIGTERM/SIGINT
cleanup() {
    echo "====> Deregistering runner $RUNNER_NAME from GitHub…"
    REMOVE_TOKEN=$(get_removal_token)
    if [ -n "$REMOVE_TOKEN" ] && [ "$REMOVE_TOKEN" != "null" ]; then
        ./config.sh remove --unattended --token "$REMOVE_TOKEN"
        echo "Runner $RUNNER_NAME deregistered."
    else
        echo "ERROR: could not fetch removal token; skipping deregistration."
    fi
    exit 0
}

# Trap termination signals
trap cleanup SIGTERM SIGINT

# 1) Get a registration token and configure the runner
echo "Getting registration token..."
REGISTRATION_TOKEN=$(get_registration_token)
if [ -z "$REGISTRATION_TOKEN" ] || [ "$REGISTRATION_TOKEN" = "null" ]; then
    echo "Error: Failed to fetch registration token"
    exit 1
fi

echo "Configuring runner..."
./config.sh \
    --url "$REPO_URL" \
    --token "$REGISTRATION_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --unattended \
    --work "_work" \
    --replace

# 2) Start the runner process in background
echo "Starting runner..."
./run.sh &

# 3) Keep a simple health‐check loop so the container stays alive
while true; do
    echo -e "HTTP/1.1 200 OK\n\nRunner is healthy" | nc -l -p 8080 -q 1
done
