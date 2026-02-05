ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install packages in a single layer to minimize image size
# Add retry logic for npm installation to handle network issues
RUN apk add --no-cache \
    nodejs \
    npm \
    bash \
    curl \
    nano \
    python3 \
    py3-pip \
    py3-requests \
    py3-aiohttp \
    py3-yaml \
    py3-beautifulsoup4 \
    jq \
    yq \
    git \
    vim \
    wget \
    tree \
    && (npm config set registry https://registry.npmjs.org/ || true) \
    && (npm config set fetch-retries 3 || true) \
    && (npm config set fetch-retry-mintimeout 20000 || true) \
    && (npm config set fetch-retry-maxtimeout 120000 || true) \
    && (npm config set fetch-timeout 300000 || true) \
    && for i in 1 2 3; do \
        echo "Attempt $i: Installing Claude Code CLI..." && \
        npm install -g @anthropic-ai/claude-code@latest && \
        echo "Successfully installed Claude Code CLI" && \
        break || \
        (echo "Attempt $i failed, retrying in 10 seconds..." && sleep 10); \
    done \
    && npm cache clean --force

# Install Home Assistant CLI (ha command)
# Download appropriate binary based on build architecture
# Automatically fetches the latest version from GitHub
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
        amd64)   HA_ARCH="amd64" ;; \
        arm64)   HA_ARCH="aarch64" ;; \
        arm/v7)  HA_ARCH="armv7" ;; \
        arm/v6)  HA_ARCH="armhf" ;; \
        386)     HA_ARCH="i386" ;; \
        *)       echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    echo "Fetching latest Home Assistant CLI version..." && \
    HA_VERSION=$(curl -fsSL https://api.github.com/repos/home-assistant/cli/releases/latest | jq -r '.tag_name') && \
    echo "Installing Home Assistant CLI ${HA_VERSION} for ${HA_ARCH}..." && \
    curl -fsSL -o /usr/bin/ha \
        "https://github.com/home-assistant/cli/releases/download/${HA_VERSION}/ha_${HA_ARCH}" && \
    chmod +x /usr/bin/ha && \
    echo "Home Assistant CLI ${HA_VERSION} installed successfully"

# Install GitHub CLI (gh command)
# Download appropriate binary based on build architecture
RUN case "${TARGETARCH}" in \
        amd64)   GH_ARCH="amd64" ;; \
        arm64)   GH_ARCH="arm64" ;; \
        arm/v7)  GH_ARCH="armv7" ;; \
        386)     GH_ARCH="386" ;; \
        *)       echo "Unsupported architecture for gh: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    echo "Fetching latest GitHub CLI version..." && \
    GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    echo "Installing GitHub CLI v${GH_VERSION} for ${GH_ARCH}..." && \
    curl -fsSL -o /tmp/gh.tar.gz \
        "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" && \
    tar -xzf /tmp/gh.tar.gz -C /tmp && \
    mv /tmp/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh /usr/bin/gh && \
    chmod +x /usr/bin/gh && \
    rm -rf /tmp/gh* && \
    echo "GitHub CLI v${GH_VERSION} installed successfully"

# Create directory for Claude configuration and set working directory
RUN mkdir -p /config/claude-config
WORKDIR /config

# Copy and install image service
COPY image-service/ /opt/image-service/
RUN cd /opt/image-service \
    && npm install --production --no-optional \
    && npm cache clean --force \
    && chmod +x server.js

# Copy and build HA MCP server
COPY ha-mcp-server/ /opt/ha-mcp-server/
RUN cd /opt/ha-mcp-server \
    && npm install \
    && npm run build \
    && npm prune --production \
    && npm cache clean --force

# Copy HA expert CLAUDE.md template
COPY CLAUDE.md /opt/CLAUDE.md

# Copy startup script and modular scripts
COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
COPY .claude/ /opt/.claude/
RUN chmod +x /run.sh \
    && chmod +x /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]