#!/bin/bash

# ============================================================================
# AI Studio - Common Library (lib/common.sh)
# Provides universal tools, logging, colors, and helper functions.
# This file should be sourced by the main script and other components.
# ============================================================================

# Prevent unbound variable errors. 
# Note: We intentionally avoid 'set -e' here to allow calling scripts to handle errors gracefully.
set -u

# ============================================================================
# 1. Color Definitions (ANSI Escape Codes)
# ============================================================================
readonly COLOR_RESET="\033[0m"
readonly COLOR_BOLD="\033[1m"
readonly COLOR_RED="\033[31m"
readonly COLOR_GREEN="\033[32m"
readonly COLOR_YELLOW="\033[33m"
readonly COLOR_BLUE="\033[34m"
readonly COLOR_CYAN="\033[36m"
readonly COLOR_GRAY="\033[90m"

# ============================================================================
# 2. Logging Functions (Progressive Disclosure: Debug is hidden by default)
# ============================================================================

# Usage: log_info "Message"
log_info() {
    echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $1"
}

# Usage: log_success "Message"
log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

# Usage: log_warn "Message"
log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1"
}

# Usage: log_error "Message" (Outputs to stderr)
log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
}

# Usage: log_debug "Message" (Only prints if AI_STUDIO_DEBUG=1 is set in environment)
log_debug() {
    if [[ "${AI_STUDIO_DEBUG:-0}" == "1" ]]; then
        echo -e "${COLOR_GRAY}[DEBUG]${COLOR_RESET} $1"
    fi
}

# ============================================================================
# 3. System & Environment Helper Functions
# ============================================================================

# Check if the current OS is macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Check if the current hardware is Apple Silicon (M1/M2/M3/M4)
is_apple_silicon() {
    if is_macos; then
        [[ "$(uname -m)" == "arm64" ]]
    else
        return 1
    fi
}

# Check if a specific command exists in the PATH
# Usage: if command_exists "brew"; then ...
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a specific TCP port is currently in use (listening)
# Usage: if is_port_in_use 8080; then ...
is_port_in_use() {
    local port=$1
    # lsof returns 0 if the port is in use, 1 otherwise
    lsof -i ":$port" >/dev/null 2>&1
}

# Wait for a port to become available (listening), with a timeout
# Usage: wait_for_port 8080 10 (wait up to 10 seconds)
wait_for_port() {
    local port=$1
    local timeout=${2:-15} # Default timeout: 15 seconds
    local elapsed=0

    log_info "Waiting for service on port $port to be ready (timeout: ${timeout}s)..."
    while ! is_port_in_use "$port"; do
        if [[ $elapsed -ge $timeout ]]; then
            log_warn "Timeout waiting for port $port to open."
            return 1
        fi
        sleep 1
        ((elapsed++))
    done
    log_success "Service on port $port is ready."
    return 0
}

# Require sudo privileges for the current operation, or exit with an error
# Usage: require_sudo "$0" "$@"
require_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This operation requires administrator privileges."
        log_info "Please run with sudo: sudo $*"
        exit 1
    fi
}

# Ensure a directory exists, creating it if necessary
# Usage: ensure_dir "/path/to/dir"
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

# Print a visual separator line for better CLI readability
print_separator() {
    echo -e "${COLOR_GRAY}================================================================================${COLOR_RESET}"
}

# ============================================================================
# 4. Initialization (Optional but recommended)
# ============================================================================
# Verify that this library is running on a supported OS
check_platform_compatibility() {
    if ! is_macos; then
        log_error "AI Studio is currently optimized for macOS."
        log_info "Detected OS: $OSTYPE"
        
        case "$OSTYPE" in
            linux*)
                log_warn "Linux support is experimental. Some features may not work."
                log_info "Apple Silicon-specific components (MLX, MLX-Video) will be disabled."
                return 0  # 允许继续但警告
                ;;
            *)
                log_error "Unsupported platform. Please use macOS 13+ for full functionality."
                return 1
                ;;
        esac
    fi
    return 0
}
