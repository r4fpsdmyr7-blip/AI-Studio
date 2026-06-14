#!/bin/bash

# ============================================================================
# AI Studio - Homebrew Installation Script (env/install-homebrew.sh)
# Automates the installation and configuration of Homebrew on macOS.
# Can be run standalone or sourced by other installation scripts.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine the root directory of the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 2. Source core libraries
source "$AI_STUDIO_ROOT/lib/common.sh"

# ============================================================================
# 3. Core Installation Logic
# ============================================================================

install_homebrew() {
    log_info "Checking Homebrew installation status..."

    # Check if brew is already available in the current PATH
    if command_exists "brew"; then
        log_success "Homebrew is already installed and available."
        
        # Optional: Run a quick update to ensure it's healthy
        log_info "Running a quick 'brew update' to ensure everything is healthy..."
        brew update --quiet >/dev/null 2>&1
        return 0
    fi

    log_warn "Homebrew is not installed or not in the system PATH."
    log_info "Starting automated Homebrew installation..."
    log_info "${COLOR_GRAY}(Note: This may prompt for your macOS administrator password)${COLOR_RESET}"
    echo ""

    # Verify curl is available (required for the installation script)
    if ! command_exists "curl"; then
        log_error "'curl' is required to download the Homebrew installer but is missing."
        log_info "Please install curl manually or ensure your system has basic command-line tools."
        return 1
    fi

    # Execute the official Homebrew installation script
    # -f: fail silently on server errors, -s: silent mode, -S: show errors, -L: follow redirects
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    local install_status=$?

    if [[ $install_status -ne 0 ]]; then
        log_error "Homebrew installation failed with exit code $install_status."
        log_info "Please check your network connection or install manually from: https://brew.sh"
        return 1
    fi

    log_success "Homebrew installed successfully!"
    echo ""

    # ========================================================================
    # 4. Post-Installation PATH Configuration
    # ========================================================================
    # Homebrew installs to different locations based on architecture.
    # We need to ensure the user's shell knows where to find it.
    
    local brew_path=""
    local shell_profile=""

    # Determine architecture and set paths
    if is_apple_silicon; then
        brew_path="/opt/homebrew/bin"
        log_info "Detected Apple Silicon. Homebrew installed to: ${COLOR_CYAN}${brew_path}${COLOR_RESET}"
    else
        brew_path="/usr/local/bin"
        log_info "Detected Intel Mac. Homebrew installed to: ${COLOR_CYAN}${brew_path}${COLOR_RESET}"
    fi

    # Determine the user's default shell profile
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zprofile"
    else
        shell_profile="$HOME/.bash_profile"
    fi

    # Check if the path is already in the profile
    if ! grep -q "$brew_path" "$shell_profile" 2>/dev/null; then
        log_info "Adding Homebrew to your shell profile ($shell_profile)..."
        echo "" >> "$shell_profile"
        echo "# Added by AI Studio: Homebrew PATH" >> "$shell_profile"
        echo "eval \"\$(${brew_path}/brew shellenv)\"" >> "$shell_profile"
        
        # Apply to the current session immediately
        eval "$(${brew_path}/brew shellenv)"
        
        log_success "Homebrew PATH configured for current session and future logins."
    else
        log_info "Homebrew PATH already exists in your shell profile."
        # Still apply to current session just in case it wasn't loaded
        eval "$(${brew_path}/brew shellenv)"
    fi

    echo ""
    log_info "Verification:"
    brew --version | head -n 1
    
    return 0
}

# ============================================================================
# 5. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  AI Studio - Homebrew Installer${COLOR_RESET}"
    print_separator
    echo ""

    install_homebrew
    local exit_code=$?

    echo ""
    print_separator

    if [[ $exit_code -eq 0 ]]; then
        log_success "Homebrew setup completed successfully."
        echo ""
        echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
        echo "  You can now proceed to install other dependencies:"
        echo "  ./env/install-deps.sh"
        echo ""
    else
        log_error "Homebrew setup encountered an error."
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
