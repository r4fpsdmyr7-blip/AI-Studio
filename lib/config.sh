#!/bin/bash

# ============================================================================
# AI Studio - Configuration Library (lib/config.sh)
# Manages global and component-specific configurations.
# Uses a simple, robust KEY="VALUE" format for persistence.
# ============================================================================

# Ensure common functions (like logging) are available
# This script expects to be sourced after lib/common.sh

# ============================================================================
# 1. Configuration Paths & Defaults
# ============================================================================

# Base configuration directory (relative to AI_STUDIO_ROOT)
readonly AI_STUDIO_CONFIG_DIR="${AI_STUDIO_ROOT:-.}/config"
readonly AI_STUDIO_GLOBAL_CONFIG="${AI_STUDIO_CONFIG_DIR}/global.conf"

# Default configuration values (used if not explicitly set)
declare -A DEFAULT_GLOBAL_CONFIG=(
    ["AUTO_OPEN_BROWSER"]="true"
    ["DEFAULT_PORT_OFFSET"]="0"
    ["LOG_LEVEL"]="info"
    ["MAX_DIAGNOSE_DEPTH"]="1"
)

# ============================================================================
# 2. Initialization
# ============================================================================

# Initialize configuration directory and files
# Usage: init_config
init_config() {
    ensure_dir "$AI_STUDIO_CONFIG_DIR"
    
    # Create global config if it doesn't exist
    if [[ ! -f "$AI_STUDIO_GLOBAL_CONFIG" ]]; then
        log_debug "Initializing global configuration file..."
        touch "$AI_STUDIO_GLOBAL_CONFIG"
        # Apply defaults
        for key in "${!DEFAULT_GLOBAL_CONFIG[@]}"; do
            set_config "$key" "${DEFAULT_GLOBAL_CONFIG[$key]}" "global"
        done
    fi
}

# ============================================================================
# 3. Core Configuration Operations
# ============================================================================

# Get the file path for a specific component's config
# Usage: _get_component_config_file "open-webui"
_get_component_config_file() {
    local component="$1"
    echo "${AI_STUDIO_CONFIG_DIR}/${component}.conf"
}

# Read a configuration value
# Usage: value=$(get_config "KEY" ["component_name"])
# If component_name is omitted or "global", it reads from global.conf
get_config() {
    local key="$1"
    local target="${2:-global}"
    local config_file

    if [[ "$target" == "global" ]]; then
        config_file="$AI_STUDIO_GLOBAL_CONFIG"
    else
        config_file="$(_get_component_config_file "$target")"
    fi

    if [[ ! -f "$config_file" ]]; then
        # Fallback to default if file doesn't exist and it's a global key
        if [[ "$target" == "global" ]] && [[ -n "${DEFAULT_GLOBAL_CONFIG[$key]:-}" ]]; then
            echo "${DEFAULT_GLOBAL_CONFIG[$key]}"
        else
            echo ""
        fi
        return 0
    fi

    # Safely extract value: match ^KEY=, remove KEY=, remove surrounding quotes
    local value
    value=$(grep -E "^${key}=" "$config_file" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//')
    
    # If not found in file, check defaults (for global)
    if [[ -z "$value" ]] && [[ "$target" == "global" ]] && [[ -n "${DEFAULT_GLOBAL_CONFIG[$key]:-}" ]]; then
        echo "${DEFAULT_GLOBAL_CONFIG[$key]}"
    else
        echo "$value"
    fi
}

# Write or update a configuration value
# Usage: set_config "KEY" "VALUE" ["component_name"]
set_config() {
    local key="$1"
    local value="$2"
    local target="${3:-global}"
    local config_file

    if [[ "$target" == "global" ]]; then
        config_file="$AI_STUDIO_GLOBAL_CONFIG"
    else
        config_file="$(_get_component_config_file "$target")"
        ensure_dir "$AI_STUDIO_CONFIG_DIR"
        touch "$config_file" # Create if not exists
    fi

    # Validate key (alphanumeric and underscores only)
    if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log_error "Invalid configuration key: $key"
        return 1
    fi

    # Escape double quotes in value for safe storage
    local escaped_value="${value//\"/\\\"}"

    # Check if key already exists
    if grep -qE "^${key}=" "$config_file" 2>/dev/null; then
        # macOS (BSD) sed requires an empty string for -i ''
        # Update existing key
        sed -i '' "s|^${key}=.*|${key}=\"${escaped_value}\"|" "$config_file"
        log_debug "Updated config: $key in $target"
    else
        # Append new key
        echo "${key}=\"${escaped_value}\"" >> "$config_file"
        log_debug "Added config: $key in $target"
    fi
}

# Delete a configuration value
# Usage: delete_config "KEY" ["component_name"]
delete_config() {
    local key="$1"
    local target="${2:-global}"
    local config_file

    if [[ "$target" == "global" ]]; then
        config_file="$AI_STUDIO_GLOBAL_CONFIG"
    else
        config_file="$(_get_component_config_file "$target")"
    fi

    if [[ ! -f "$config_file" ]]; then
        return 0
    fi

    # Remove the line matching the key
    sed -i '' "/^${key}=/d" "$config_file"
    log_debug "Deleted config: $key from $target"
}

# ============================================================================
# 4. Helper / Convenience Functions
# ============================================================================

# Check if a boolean config is true
# Usage: if is_config_true "AUTO_OPEN_BROWSER"; then ...
is_config_true() {
    local key="$1"
    local target="${2:-global}"
    local value
    value=$(get_config "$key" "$target")
    
    # Convert to lowercase for comparison
    local lower_value="${value,,}"
    [[ "$lower_value" == "true" || "$lower_value" == "1" || "$lower_value" == "yes" ]]
}

# Load all configurations for a specific component into the current shell environment
# WARNING: Only use this if you trust the config file contents.
# Usage: load_component_env "open-webui"
load_component_env() {
    local component="$1"
    local config_file="$(_get_component_config_file "$component")"
    
    if [[ -f "$config_file" ]]; then
        # Source the file safely (it only contains KEY="VALUE" pairs)
        # shellcheck disable=SC1090
        source "$config_file"
        log_debug "Loaded environment variables for $component"
    fi
}

# Reset a component's configuration to defaults (by deleting the file)
# Usage: reset_component_config "open-webui"
reset_component_config() {
    local component="$1"
    local config_file="$(_get_component_config_file "$component")"
    
    if [[ -f "$config_file" ]]; then
        rm -f "$config_file"
        log_info "Reset configuration for $component"
    fi
}

# ============================================================================
# 5. Auto-initialization
# ============================================================================
# Automatically ensure config directory exists when this library is sourced
init_config
