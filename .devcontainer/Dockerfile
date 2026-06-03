FROM mcr.microsoft.com/devcontainers/go:1.4.1-bullseye

# Work around stale/unsigned Yarn APT source present in some base layers.
# Devcontainer features run apt-get update during install; removing this source
# prevents docker-in-docker/azure-cli feature setup from failing with NO_PUBKEY.
RUN rm -f /etc/apt/sources.list.d/yarn.list \
    /etc/apt/sources.list.d/yarn*.list
