# Ubuntu latest (Noble Numbat 24.04) base image for the Dev Container
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG UV_VERSION=0.11.6
ARG OLLAMA_VERSION=0.20.7
ARG CLAUDE_CODE_VERSION=2.1.109

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV TZ=Etc/UTC

# Packages required for native module builds, locale generation, timezone setup, and Ollama extraction
RUN if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
         sed -i 's|http://archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g; s|http://security.ubuntu.com/ubuntu|https://security.ubuntu.com/ubuntu|g' /etc/apt/sources.list.d/ubuntu.sources; \
      fi \
      && if [ -f /etc/apt/sources.list ]; then \
         sed -i 's|http://archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g; s|http://security.ubuntu.com/ubuntu|https://security.ubuntu.com/ubuntu|g' /etc/apt/sources.list; \
      fi \
         && apt-get update && apt-get install -y --no-install-recommends \
             build-essential \
             locales \
             ripgrep \
             tzdata \
             zstd \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && echo "${TZ}" >/etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI and Compose plugin only (no daemon).
# The devcontainer connects to docker-socket-proxy via DOCKER_HOST (TCP),
# so no Unix socket mount or docker group membership is required.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
       | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable\n' \
       "$(dpkg --print-architecture)" >/etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       docker-ce-cli \
       docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install uv system-wide
# Reference: https://docs.astral.sh/uv/getting-started/installation/
RUN curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" | env CARGO_HOME=/usr/local UV_INSTALL_DIR=/usr/local/bin sh

# Install Ollama
# Reference: https://ollama.com/download
RUN curl -fsSL https://ollama.com/install.sh | env OLLAMA_VERSION="${OLLAMA_VERSION}" sh

# Install Claude Code with the native installer
# Reference: https://docs.anthropic.com/en/docs/claude-code
# npm (@anthropic-ai/claude-code) is intentionally not used here
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- "${CLAUDE_CODE_VERSION}"
