#!/usr/bin/with-contenv bashio

# Enable strict error handling
set -e
set -o pipefail

# Initialize environment for Claude Code CLI using /data (HA best practice)
init_environment() {
    # Use /data exclusively - guaranteed writable by HA Supervisor
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"
    local claude_config_dir="/data/.config/claude"
    local gh_config_dir="/data/.config/gh"
    local persist_root="/data/packages"
    local persist_bin="$persist_root/bin"
    local persist_lib="$persist_root/lib"
    local persist_python="$persist_root/python"

    bashio::log.info "Initializing Claude Code environment in /data..."

    # Create all required directories
    if ! mkdir -p "$data_home" "$config_dir/claude" "$config_dir/gh" "$cache_dir" "$state_dir" "/data/.local" \
                  "$persist_bin" "$persist_lib" "$persist_python"; then
        bashio::log.error "Failed to create directories in /data"
        exit 1
    fi

    # Set permissions
    chmod 755 "$data_home" "$config_dir" "$cache_dir" "$state_dir" "$claude_config_dir" "$gh_config_dir" \
              "$persist_root" "$persist_bin" "$persist_lib" "$persist_python"

    # Set XDG and application environment variables
    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"

    # Claude-specific environment variables
    export ANTHROPIC_CONFIG_DIR="$claude_config_dir"
    export ANTHROPIC_HOME="/data"

    # GitHub CLI persistent configuration
    export GH_CONFIG_DIR="$gh_config_dir"

    # Get dangerously-skip-permissions configuration
    local dangerously_skip_permissions
    dangerously_skip_permissions=$(bashio::config 'dangerously_skip_permissions' 'false')
    export CLAUDE_DANGEROUS_MODE="$dangerously_skip_permissions"

    # Set IS_SANDBOX=1 to allow --dangerously-skip-permissions when running as root
    if [ "$dangerously_skip_permissions" = "true" ]; then
        export IS_SANDBOX=1
    fi

    # Setup persistent package paths (HIGHEST PRIORITY)
    export PATH="$persist_bin:$persist_python/venv/bin:$PATH"
    export LD_LIBRARY_PATH="$persist_lib:${LD_LIBRARY_PATH:-}"
    export PKG_CONFIG_PATH="$persist_lib/pkgconfig:${PKG_CONFIG_PATH:-}"

    # Python virtual environment if it exists
    if [ -d "$persist_python/venv" ]; then
        export VIRTUAL_ENV="$persist_python/venv"
        bashio::log.info "  - Python venv: active"
    fi

    # Create profile script for persistent environment variables
    # This ensures ALL bash sessions (including ttyd shells) have correct PATH
    cat > /etc/profile.d/persistent-packages.sh << 'PROFILE_EOF'
# Persistent package environment - auto-loaded for all bash sessions
export HOME="/data/home"
export XDG_CONFIG_HOME="/data/.config"
export XDG_CACHE_HOME="/data/.cache"
export XDG_STATE_HOME="/data/.local/state"
export XDG_DATA_HOME="/data/.local/share"
export ANTHROPIC_CONFIG_DIR="/data/.config/claude"
export ANTHROPIC_HOME="/data"

# GitHub CLI persistent configuration
export GH_CONFIG_DIR="/data/.config/gh"

# Persistent package paths (HIGHEST PRIORITY)
export PATH="/data/packages/bin:/data/packages/python/venv/bin:$PATH"
export LD_LIBRARY_PATH="/data/packages/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="/data/packages/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Python virtual environment if it exists
if [ -d "/data/packages/python/venv" ]; then
    export VIRTUAL_ENV="/data/packages/python/venv"
fi

# Supervisor token for MCP server and HA API access
export SUPERVISOR_TOKEN="${SUPERVISOR_TOKEN}"

# Anthropic API key if configured
if [ -f "/data/.anthropic_api_key" ]; then
    export ANTHROPIC_API_KEY=$(cat /data/.anthropic_api_key)
fi

# Custom secrets if configured (KEY=VALUE pairs)
if [ -f "/data/.secrets_env" ]; then
    set -a
    . /data/.secrets_env
    set +a
fi

# Increase MCP output token limit for large entity lists
export MAX_MCP_OUTPUT_TOKENS=50000
PROFILE_EOF

    chmod 644 /etc/profile.d/persistent-packages.sh
    bashio::log.info "  - Profile script created: /etc/profile.d/persistent-packages.sh"

    # Setup Anthropic API key if provided
    local api_key
    api_key=$(bashio::config 'anthropic_api_key' '')
    if [ -n "$api_key" ] && [ "$api_key" != "null" ] && [ "$api_key" != "" ]; then
        export ANTHROPIC_API_KEY="$api_key"
        bashio::log.info "  - API key authentication: configured"
    else
        bashio::log.info "  - API key authentication: not set (using OAuth)"
    fi

    # Setup custom secrets (KEY=VALUE format, exported as env vars)
    local secrets
    secrets=$(bashio::config 'secrets' '[]')
    if [ "$secrets" != "[]" ] && [ "$secrets" != "" ] && [ "$secrets" != "null" ]; then
        bashio::log.info "  - Secrets:"
        echo "$secrets" | jq -r '.[]' | while IFS='=' read -r key value; do
            if [ -n "$key" ] && [ -n "$value" ]; then
                export "$key"="$value"
                bashio::log.info "    - ${key} = ****"
            fi
        done
    fi

    # Migrate any existing authentication files from legacy locations
    migrate_legacy_auth_files "$claude_config_dir"

    # Setup Claude Code skills and commands
    if [ -d "/opt/.claude" ]; then
        if [ ! -d "$data_home/.claude" ]; then
            cp -r /opt/.claude "$data_home/.claude"
            bashio::log.info "  - Claude Code skills & commands installed"
        else
            bashio::log.info "  - Claude Code skills & commands: already configured"
        fi
    fi

    bashio::log.info "Environment initialized:"
    bashio::log.info "  - Home: $HOME"
    bashio::log.info "  - Config: $XDG_CONFIG_HOME"
    bashio::log.info "  - Claude config: $ANTHROPIC_CONFIG_DIR"
    bashio::log.info "  - GitHub config: $GH_CONFIG_DIR"
    bashio::log.info "  - Cache: $XDG_CACHE_HOME"
    bashio::log.info "  - Persistent packages: $persist_root"
}

# One-time migration of existing authentication files
migrate_legacy_auth_files() {
    local target_dir="$1"
    local migrated=false

    bashio::log.info "Checking for existing authentication files to migrate..."

    # Check common legacy locations
    local legacy_locations=(
        "/root/.config/anthropic"
        "/root/.anthropic" 
        "/config/claude-config"
        "/tmp/claude-config"
    )

    for legacy_path in "${legacy_locations[@]}"; do
        if [ -d "$legacy_path" ] && [ "$(ls -A "$legacy_path" 2>/dev/null)" ]; then
            bashio::log.info "Migrating auth files from: $legacy_path"
            
            # Copy files to new location
            if cp -r "$legacy_path"/* "$target_dir/" 2>/dev/null; then
                # Set proper permissions
                find "$target_dir" -type f -exec chmod 600 {} \;
                
                # Create compatibility symlink if this is a standard location
                if [[ "$legacy_path" == "/root/.config/anthropic" ]] || [[ "$legacy_path" == "/root/.anthropic" ]]; then
                    rm -rf "$legacy_path"
                    ln -sf "$target_dir" "$legacy_path"
                    bashio::log.info "Created compatibility symlink: $legacy_path -> $target_dir"
                fi
                
                migrated=true
                bashio::log.info "Migration completed from: $legacy_path"
            else
                bashio::log.warning "Failed to migrate from: $legacy_path"
            fi
        fi
    done

    if [ "$migrated" = false ]; then
        bashio::log.info "No existing authentication files found to migrate"
    fi
}

# Install required tools
install_tools() {
    bashio::log.info "Installing additional tools..."
    if ! apk add --no-cache ttyd jq curl; then
        bashio::log.error "Failed to install required tools"
        exit 1
    fi
    bashio::log.info "Tools installed successfully"
}

# Setup session picker script
setup_session_picker() {
    # Copy session picker script from built-in location
    if [ -f "/opt/scripts/claude-session-picker.sh" ]; then
        if ! cp /opt/scripts/claude-session-picker.sh /usr/local/bin/claude-session-picker; then
            bashio::log.error "Failed to copy claude-session-picker script"
            exit 1
        fi
        chmod +x /usr/local/bin/claude-session-picker
        bashio::log.info "Session picker script installed successfully"
    else
        bashio::log.warning "Session picker script not found, using auto-launch mode only"
    fi

    # Setup authentication helper if it exists
    if [ -f "/opt/scripts/claude-auth-helper.sh" ]; then
        chmod +x /opt/scripts/claude-auth-helper.sh
        bashio::log.info "Authentication helper script ready"
    fi
}

# Setup persistent package manager
setup_persistent_packages() {
    # Install persist-install command globally
    if [ -f "/opt/scripts/persist-install" ]; then
        cp /opt/scripts/persist-install /usr/local/bin/persist-install
        chmod +x /usr/local/bin/persist-install
        bashio::log.info "Persistent package manager installed: 'persist-install'"
    fi

    # Auto-install packages from configuration
    auto_install_packages
}

# Auto-install packages from add-on configuration
auto_install_packages() {
    local apk_packages=$(bashio::config 'persistent_apk_packages' '[]')
    local pip_packages=$(bashio::config 'persistent_pip_packages' '[]')

    # Check if any packages are configured
    if [ "$apk_packages" != "[]" ] && [ "$apk_packages" != "" ]; then
        bashio::log.info "Auto-installing system packages from config..."

        # Parse JSON array and install
        echo "$apk_packages" | jq -r '.[]' | while read -r pkg; do
            if [ -n "$pkg" ]; then
                bashio::log.info "  Installing: $pkg"
                /usr/local/bin/persist-install "$pkg" || bashio::log.warning "Failed to install: $pkg"
            fi
        done
    fi

    # Check if any Python packages are configured
    if [ "$pip_packages" != "[]" ] && [ "$pip_packages" != "" ]; then
        bashio::log.info "Auto-installing Python packages from config..."

        # Collect all package names
        local all_packages=$(echo "$pip_packages" | jq -r '.[]' | tr '\n' ' ')

        if [ -n "$all_packages" ]; then
            bashio::log.info "  Installing: $all_packages"
            /usr/local/bin/persist-install --python $all_packages || bashio::log.warning "Failed to install Python packages"
        fi
    fi
}

# Legacy monitoring functions removed - using simplified /data approach

# Determine Claude launch command based on configuration
get_claude_launch_command() {
    local auto_launch_claude
    local dangerously_skip_permissions
    local claude_flags=""

    # Get configuration values
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')
    dangerously_skip_permissions=$(bashio::config 'dangerously_skip_permissions' 'false')

    # Build Claude flags
    if [ "$dangerously_skip_permissions" = "true" ]; then
        claude_flags="--dangerously-skip-permissions"
        bashio::log.warning "Claude will run with --dangerously-skip-permissions (unrestricted file access)"
    fi

    if [ "$auto_launch_claude" = "true" ]; then
        # Original behavior: auto-launch Claude directly
        echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && node \$(which claude) ${claude_flags}"
    else
        # New behavior: show interactive session picker
        if [ -f /usr/local/bin/claude-session-picker ]; then
            echo "clear && /usr/local/bin/claude-session-picker"
        else
            # Fallback if session picker is missing
            bashio::log.warning "Session picker not found, falling back to auto-launch"
            echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && node \$(which claude)"
        fi
    fi
}


# Start image upload service
start_image_service() {
    local image_port=7680
    local ttyd_port=7681
    local upload_dir="/data/images"
    local service_dir="/opt/image-service"
    local server_file="${service_dir}/server.js"

    bashio::log.info "Starting image upload service on port ${image_port}..."

    # Create upload directory if it doesn't exist
    mkdir -p "${upload_dir}"
    chmod 755 "${upload_dir}"

    # Export environment variables for the image service
    export IMAGE_SERVICE_PORT="${image_port}"
    export TTYD_PORT="${ttyd_port}"
    export UPLOAD_DIR="${upload_dir}"

    # Check if server.js exists
    if [ ! -f "${server_file}" ]; then
        bashio::log.error "server.js not found at ${server_file}"
        ls -la "${service_dir}"
        return 1
    fi

    # Check if node_modules exists
    if [ ! -d "${service_dir}/node_modules" ]; then
        bashio::log.error "node_modules not found in ${service_dir}"
        bashio::log.info "Attempting to install dependencies..."
        cd "${service_dir}" && npm install || bashio::log.error "npm install failed"
        cd - > /dev/null
    fi

    # Start with better error logging (run from current directory with absolute path)
    bashio::log.info "Starting Node.js service from ${server_file}..."
    node "${server_file}" 2>&1 | while IFS= read -r line; do
        bashio::log.info "[Image Service] $line"
    done &

    # Store the PID for potential cleanup
    local image_service_pid=$!
    bashio::log.info "Image service started (PID: ${image_service_pid})"

    # Give it a moment to start
    sleep 3

    # Check if it's running
    if kill -0 "${image_service_pid}" 2>/dev/null; then
        bashio::log.info "Image service is running successfully"
    else
        bashio::log.error "Image service failed to start! Check logs above for errors"
        return 1
    fi
}

# Start main web terminal
start_web_terminal() {
    local port=7681
    bashio::log.info "Starting web terminal on port ${port}..."

    # Log environment information for debugging
    bashio::log.info "Environment variables:"
    bashio::log.info "ANTHROPIC_CONFIG_DIR=${ANTHROPIC_CONFIG_DIR}"
    bashio::log.info "HOME=${HOME}"

    # Get the appropriate launch command based on configuration
    local launch_command
    launch_command=$(get_claude_launch_command)

    # Log the configuration being used
    local auto_launch_claude
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')
    bashio::log.info "Auto-launch Claude: ${auto_launch_claude}"

    # Start the image upload service first
    start_image_service

    # Run ttyd with improved configuration
    exec ttyd \
        --port "${port}" \
        --interface 0.0.0.0 \
        --writable \
        bash -c "$launch_command"
}

# Run health check
run_health_check() {
    if [ -f "/opt/scripts/health-check.sh" ]; then
        bashio::log.info "Running system health check..."
        chmod +x /opt/scripts/health-check.sh
        /opt/scripts/health-check.sh || bashio::log.warning "Some health checks failed but continuing..."
    fi
}

# Deploy CLAUDE.md to /config for Claude Code to auto-load
deploy_claude_md() {
    local src="/opt/CLAUDE.md"
    local dest="/config/CLAUDE.md"

    if [ -f "$src" ]; then
        cp "$src" "$dest"
        chmod 644 "$dest"
        bashio::log.info "CLAUDE.md deployed to /config/CLAUDE.md"
    fi
}

# Run HA auto-discovery to generate context file
run_auto_discovery() {
    local auto_discover
    auto_discover=$(bashio::config 'auto_discover' 'true')

    if [ "$auto_discover" = "true" ]; then
        bashio::log.info "Running HA auto-discovery..."
        if [ -f "/opt/scripts/ha-discovery.sh" ]; then
            chmod +x /opt/scripts/ha-discovery.sh
            /opt/scripts/ha-discovery.sh || bashio::log.warning "Auto-discovery had errors but continuing..."
        fi
    else
        bashio::log.info "Auto-discovery disabled in config"
    fi
}

# Persist secrets to /data so profile script can load them in all sessions
persist_secrets() {
    # Anthropic API key (dedicated field)
    local api_key
    api_key=$(bashio::config 'anthropic_api_key' '')
    if [ -n "$api_key" ] && [ "$api_key" != "null" ] && [ "$api_key" != "" ]; then
        echo -n "$api_key" > /data/.anthropic_api_key
        chmod 600 /data/.anthropic_api_key
    else
        rm -f /data/.anthropic_api_key
    fi

    # Generic secrets (KEY=VALUE format)
    local secrets
    secrets=$(bashio::config 'secrets' '[]')
    rm -f /data/.secrets_env
    if [ "$secrets" != "[]" ] && [ "$secrets" != "" ] && [ "$secrets" != "null" ]; then
        echo "$secrets" | jq -r '.[]' | while IFS= read -r line; do
            if echo "$line" | grep -q '='; then
                echo "$line" >> /data/.secrets_env

                # Auto-detect known tokens and set up integrations
                local key="${line%%=*}"
                local value="${line#*=}"
                case "$key" in
                    GITHUB_TOKEN|GH_TOKEN)
                        echo "$value" | gh auth login --with-token 2>/dev/null \
                            && bashio::log.info "GitHub CLI auto-authenticated from secrets" \
                            || true
                        # Ensure both vars are set
                        echo "GITHUB_TOKEN=${value}" >> /data/.secrets_env
                        echo "GH_TOKEN=${value}" >> /data/.secrets_env
                        ;;
                esac
            fi
        done
        if [ -f /data/.secrets_env ]; then
            chmod 600 /data/.secrets_env
            bashio::log.info "Secrets persisted to /data/.secrets_env"
        fi
    fi
}

# Register MCP server with Claude Code
setup_mcp_server() {
    bashio::log.info "Configuring Home Assistant MCP server..."

    local mcp_server_path="/opt/ha-mcp-server/build/index.js"
    if [ ! -f "$mcp_server_path" ]; then
        bashio::log.error "MCP server not found at ${mcp_server_path}"
        return 1
    fi

    local claude_json="${HOME}/.claude.json"

    # Build the MCP config using jq
    if [ -f "$claude_json" ]; then
        local tmp_file
        tmp_file=$(mktemp)
        jq --arg token "$SUPERVISOR_TOKEN" '
          .mcpServers["home-assistant"] = {
            "type": "stdio",
            "command": "node",
            "args": ["/opt/ha-mcp-server/build/index.js"],
            "env": {
              "SUPERVISOR_TOKEN": $token
            }
          }
        ' "$claude_json" > "$tmp_file" 2>/dev/null

        if [ $? -eq 0 ]; then
            mv "$tmp_file" "$claude_json"
        else
            rm -f "$tmp_file"
            create_fresh_claude_json
        fi
    else
        create_fresh_claude_json
    fi

    chmod 600 "$claude_json"
    bashio::log.info "  MCP server 'home-assistant' registered in ${claude_json}"
}

create_fresh_claude_json() {
    local claude_json="${HOME}/.claude.json"
    cat > "$claude_json" << CJEOF
{
  "mcpServers": {
    "home-assistant": {
      "type": "stdio",
      "command": "node",
      "args": ["/opt/ha-mcp-server/build/index.js"],
      "env": {
        "SUPERVISOR_TOKEN": "${SUPERVISOR_TOKEN}"
      }
    }
  }
}
CJEOF
}

# Main execution
main() {
    bashio::log.info "Initializing Claude Terminal add-on..."

    # Run diagnostics first (especially helpful for VirtualBox issues)
    run_health_check

    init_environment
    install_tools
    setup_session_picker
    setup_persistent_packages
    persist_secrets
    deploy_claude_md
    run_auto_discovery
    setup_mcp_server
    start_web_terminal
}

# Execute main function
main "$@"