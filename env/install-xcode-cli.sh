#!/bin/bash

# ============================================================================
# AI Studio - Xcode Command Line Tools Installer (env/install-xcode-cli.sh)
# Automates the detection and installation of macOS development tools required 
# for compiling AI dependencies (e.g., llama.cpp, ONNX Runtime).
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

# Check if Xcode Command Line Tools are installed and functional
check_xcode_cli() {
    # Check if the path is registered
    local cli_path
    cli_path=$(xcode-select -p 2>/dev/null)
    
    if [[ "$cli_path" == "/Library/Developer/CommandLineTools" ]] && [[ -d "$cli_path" ]]; then
        # Verify a core compiler exists to ensure it's not a broken installation
        if [[ -x "$cli_path/usr/bin/clang" ]] && [[ -x "$cli_path/usr/bin/make" ]]; then
            local version
            version=$(clang --version | head -n 1 | awk '{print $3, $4}')
            log_info "Xcode Command Line Tools are installed (Clang ${version})."
            return 0
        else
            log_warn "Xcode CLI path exists, but core tools (clang/make) are missing or broken."
            return 1
        fi
    else
        log_info "Xcode Command Line Tools are not installed."
        return 1
    fi
}

# Trigger the macOS native installation dialog
trigger_installation() {
    log_info "Triggering macOS system installer for Command Line Tools..."
    log_warn "${COLOR_YELLOW}A system dialog will appear shortly. Please click 'Install' and accept the license agreement.${COLOR_RESET}"
    echo ""
    
    # This command triggers the GUI popup. It returns immediately, but the popup stays on screen.
    xcode-select --install
    
    # We must wait for the user to complete the GUI installation.
    # A simple 'read' prompt is the most reliable way to pause the script and let the user catch up.
    echo ""
    read -r -p "$(echo -e "${COLOR_CYAN}👉 Press [Enter] once the installation window says 'The software was installed'...${COLOR_RESET}")"
    
    echo ""
    log_info "Verifying installation..."
}

# Attempt to fix a corrupted or stuck CLT installation
fix_corrupted_cli() {
    log_warn "Attempting to reset corrupted Command Line Tools installation..."
    log_info "This requires administrator privileges. You may be prompted for your password."
    
    if sudo rm -rf /Library/Developer/CommandLineTools; then
        log_success "Old Command Line Tools directory removed."
        log_info "Please run this script again to trigger a fresh installation."
        return 0
    else
        log_error "Failed to remove old Command Line Tools. Please remove manually via Finder or Terminal."
        return 1
    fi
}

# ============================================================================
# 4. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  AI Studio - Xcode CLI Installer${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  Setting up macOS compilation tools for AI dependencies...${COLOR_RESET}"
    print_separator
    echo ""

    if check_xcode_cli; then
        log_success "Xcode Command Line Tools are already installed and healthy."
        echo ""
        print_separator
        exit 0
    fi

    # Check if it's a corrupted state (path exists but tools are missing)
    local cli_path
    cli_path=$(xcode-select -p 2>/dev/null)
    if [[ -n "$cli_path" ]] && [[ -d "$cli_path" ]]; then
        log_warn "Detected a potentially corrupted installation at: $cli_path"
        if confirm_action "Do you want to delete it and perform a clean installation?" "Y"; then
            fix_corrupted_cli
            exit $?
        else
            log_info "Aborting. Please manually fix the installation at $cli_path."
            exit 1
        fi
    fi

    # Trigger fresh installation
    trigger_installation
    
    # Final verification
    if check_xcode_cli; then
        echo ""
        print_separator
        log_success "Xcode Command Line Tools setup completed successfully!"
        echo ""
        echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
        echo "  Your Mac is now ready to compile AI packages."
        echo "  Proceed to install Homebrew and other dependencies:"
        echo "  ./env/install-homebrew.sh"
        echo ""
        print_separator
        exit 0
    else
        echo ""
        print_separator
        log_error "Verification failed. The installation may have been cancelled or failed."
        echo ""
        echo -e "${COLOR_YELLOW}Troubleshooting:${COLOR_RESET}"
        echo "  1. If the popup didn't appear, check System Settings > Software Update."
        echo "  2. If it says 'Cannot install software', try: sudo rm -rf /Library/Developer/CommandLineTools"
        echo "  3. Then run this script again: ./env/install-xcode-cli.sh"
        echo ""
        print_separator
        exit 1
    fi
}

# Execute main function
main "$@"
