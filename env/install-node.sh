#!/bin/bash

# ============================================================================
# AI Studio - Node.js Environment Installation Script (env/install-node.sh)
# Automates the installation and configuration of a compatible Node.js 
# environment for Web-based AI components on macOS.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine the root directory of the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 2. Source core libraries
source "$AI_STUDIO_ROOT/lib/common.sh"

# ============================================================================
# 3. Configuration Constants
# ============================================================================
readonly MIN_NODE_MAJOR="18" # Node 18 is the current minimum LTS requirement for most modern AI Web UIs
readonly TARGET_NODE_VERSION="node" # Installing default 'node' from brew ensures the latest stable LTS

# ============================================================================
# 4. Core Installation Logic
# ============================================================================

# Check if the current node meets the minimum version requirement
check_node_version() {
    if ! command_exists "node"; then
        return 1
    fi

    # Extract major version (e.g., "v20.11.1" -> "20")
    local version_str
    version_str=$(node --version 2>&1 | tr -d 'v')
    local major
    major=$(echo "$version_str" | cut -d. -f1)

    if [[ "$major" -ge "$MIN_NODE_MAJOR" ]]; then
        log_info "Node.js v$version_str is installed and meets the minimum requirement (>= v${MIN_NODE_MAJOR})."
        return 0
    else
        log_warn "Found Node.js v$version_str, but version >= v${MIN_NODE_MAJOR} is required."
        return 1
    fi
}

# Install Node.js via Homebrew
install_node_via_brew() {
    log_info "Installing Node.js (LTS) via Homebrew..."

    # Ensure brew is available
    if ! command_exists "brew"; then
        log_error "Homebrew is required to install Node.js, but it is not found."
        log_info "Please run './env/install-homebrew.sh' first."
        return 1
    fi

    # Install node
    log_info "Running: brew install ${TARGET_NODE_VERSION}"
    if ! brew install "${TARGET_NODE_VERSION}"; then
        log_error "Failed to install Node.js via Homebrew."
        return 1
    fi

    log_success "Node.js installed successfully."
    return 0
}

# Ensure essential Node.js packaging tools are up to date and configured
setup_npm_toolchain() {
    log_info "Ensuring Node.js packaging toolchain is ready..."
    
    # 1. Update npm to the latest version compatible with the installed Node
    log_info "Updating npm..."
    if ! npm install -g npm@latest >/dev/null 2>&1; then
        log_warn "Failed to update npm globally. You may need to run this with sudo or fix npm permissions."
    else
        log_success "npm updated to latest version."
    fi

    # 2. Verify core tools
    local tools_to_check=("node" "npm" "npx")
    local missing_tools=()

    for tool in "${tools_to_check[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Core Node.js tools are missing after installation: ${missing_tools[*]}"
        log_info "You may need to restart your terminal or manually configure your PATH."
        return 1
    fi

    log_success "Node.js toolchain (node, npm, npx) is verified and ready."
    return 0
}

# Optional: Configure npm to install global packages in user directory to avoid sudo
# This is a best practice for macOS to prevent permission errors.
configure_npm_global_prefix() {
    log_info "Configuring npm to install global packages without sudo..."
    
    local npm_global_dir="$HOME/.npm-global"
    
    # Create directory if it doesn't exist
    mkdir -p "$npm_global_dir"

    # Set npm config
    npm config set prefix "$npm_global_dir" >/dev/null 2>&1

    local shell_profile=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zprofile"
    else
        shell_profile="$HOME/.bash_profile"
    fi

    # Add to PATH if not already present
    if ! grep -q "$npm_global_dir/bin" "$shell_profile" 2>/dev/null; then
        log_info "Adding npm global bin to your shell profile ($shell_profile)..."
        echo "" >> "$shell_profile"
        echo "# Added by AI Studio: npm global packages PATH" >> "$shell_profile"
        echo "export PATH=\"${npm_global_dir}/bin:\$PATH\"" >> "$shell_profile"
        
        # Apply to current session
        export PATH="${npm_global_dir}/bin:${PATH}"
    fi
    
    log_success "npm global installation configured safely in user directory."
}

# ============================================================================
# 5. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  AI Studio - Node.js Environment Installer${COLOR_RESET}"
    print_separator
    echo ""

    local exit_code=0

    if check_node_version; then
        log_success "Node.js environment is already healthy."
    else
        install_node_via_brew || exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        # Even if node was already installed, we still want to ensure the toolchain and permissions are correct
        setup_npm_toolchain || exit_code=1
        configure_npm_global_prefix || exit_code=1
    fi

    echo ""
    print_separator

    if [[ $exit_code -eq 0 ]]; then
        log_success "Node.js setup completed successfully."
        echo ""
        echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
        echo "  Your system is now ready to deploy Web-based AI components."
        echo "  Run: ./ai-studio.sh install open-webui"
        echo ""
    else
        log_error "Node.js setup encountered an error."
        echo ""
        echo -e "${COLOR_YELLOW}Troubleshooting:${COLOR_RESET}"
        echo "  1. Check Homebrew status: brew doctor"
        echo "  2. Ensure you have a stable internet connection."
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
