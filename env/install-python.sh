#!/bin/bash

# ============================================================================
# AI Studio - Python Environment Installation Script (env/install-python.sh)
# Automates the installation and configuration of a compatible Python 3 
# environment for AI components on macOS.
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
readonly MIN_PYTHON_MAJOR="3"
readonly MIN_PYTHON_MINOR="10"
readonly TARGET_PYTHON_VERSION="3.11" # 3.11 offers the best compatibility for current AI tools (MLX, ComfyUI, etc.)

# ============================================================================
# 4. Core Installation Logic
# ============================================================================

# Check if the current python3 meets the minimum version requirement
check_python_version() {
    if ! command_exists "python3"; then
        return 1
    fi

    # Extract major and minor version (e.g., "3.11.4" -> "3" and "11")
    local version_str
    version_str=$(python3 --version 2>&1 | awk '{print $2}')
    local major minor
    major=$(echo "$version_str" | cut -d. -f1)
    minor=$(echo "$version_str" | cut -d. -f2)

    if [[ "$major" -gt "$MIN_PYTHON_MAJOR" ]] || \
       { [[ "$major" -eq "$MIN_PYTHON_MAJOR" ]] && [[ "$minor" -ge "$MIN_PYTHON_MINOR" ]]; }; then
        log_info "Python $version_str is installed and meets the minimum requirement (>= ${MIN_PYTHON_MAJOR}.${MIN_PYTHON_MINOR})."
        return 0
    else
        log_warn "Found Python $version_str, but version >= ${MIN_PYTHON_MAJOR}.${MIN_PYTHON_MINOR} is required."
        return 1
    fi
}

# Install Python via Homebrew
install_python_via_brew() {
    log_info "Installing Python ${TARGET_PYTHON_VERSION} via Homebrew..."

    # Ensure brew is available
    if ! command_exists "brew"; then
        log_error "Homebrew is required to install Python, but it is not found."
        log_info "Please run './env/install-homebrew.sh' first."
        return 1
    fi

    # Install specific Python version
    log_info "Running: brew install python@${TARGET_PYTHON_VERSION}"
    if ! brew install "python@${TARGET_PYTHON_VERSION}"; then
        log_error "Failed to install Python ${TARGET_PYTHON_VERSION} via Homebrew."
        return 1
    fi

    log_success "Python ${TARGET_PYTHON_VERSION} installed successfully."
    
    # Handle Homebrew's keg-only nature for python@3.11
    # We need to ensure it's accessible as 'python3' in the current session and future sessions
    configure_python_path
}

# Configure PATH to ensure the newly installed Python is prioritized
configure_python_path() {
    local brew_prefix
    brew_prefix=$(brew --prefix "python@${TARGET_PYTHON_VERSION}" 2>/dev/null)
    
    if [[ -z "$brew_prefix" ]] || [[ ! -d "$brew_prefix" ]]; then
        log_warn "Could not determine Homebrew prefix for Python. You may need to configure PATH manually."
        return 1
    fi

    local python_bin_dir="${brew_prefix}/libexec/bin"
    local shell_profile=""

    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zprofile"
    else
        shell_profile="$HOME/.bash_profile"
    fi

    # Check if already configured
    if grep -q "$python_bin_dir" "$shell_profile" 2>/dev/null; then
        log_info "Python PATH is already configured in $shell_profile."
    else
        log_info "Adding Python ${TARGET_PYTHON_VERSION} to your shell profile ($shell_profile)..."
        echo "" >> "$shell_profile"
        echo "# Added by AI Studio: Python ${TARGET_PYTHON_VERSION} PATH" >> "$shell_profile"
        echo "export PATH=\"${python_bin_dir}:\$PATH\"" >> "$shell_profile"
    fi

    # Apply to current session immediately
    export PATH="${python_bin_dir}:${PATH}"
    
    # Verify the active python3 is now the correct one
    if check_python_version; then
        log_success "Python environment configured and activated for the current session."
    else
        log_warn "Python PATH updated, but version check still shows old version. You may need to restart your terminal."
    fi
}

# Ensure essential Python packaging tools are up to date
setup_python_toolchain() {
    log_info "Ensuring Python packaging toolchain is up to date..."
    
    # Upgrade pip, setuptools, and wheel (essential for building AI dependencies)
    if ! python3 -m pip install --upgrade --quiet pip setuptools wheel; then
        log_warn "Failed to upgrade pip/setuptools/wheel. Some component installations might require manual intervention."
    else
        log_success "Python packaging toolchain (pip, setuptools, wheel) is ready."
    fi

    # Verify venv module is available (critical for component isolation)
    if ! python3 -m venv --help >/dev/null 2>&1; then
        log_error "Python 'venv' module is missing. This is required for isolated component environments."
        return 1
    fi
    log_success "Python virtual environment (venv) support is verified."
    
    return 0
}

# ============================================================================
# 5. Main Execution Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  AI Studio - Python Environment Installer${COLOR_RESET}"
    print_separator
    echo ""

    local exit_code=0

    if check_python_version; then
        log_success "Python environment is already healthy."
        # Still ensure toolchain is ready even if version is OK
        setup_python_toolchain || exit_code=1
    else
        install_python_via_brew || exit_code=1
        
        if [[ $exit_code -eq 0 ]]; then
            setup_python_toolchain || exit_code=1
        fi
    fi

    echo ""
    print_separator

    if [[ $exit_code -eq 0 ]]; then
        log_success "Python setup completed successfully."
        echo ""
        echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
        echo "  You can now proceed to install other core dependencies:"
        echo "  ./env/install-nodejs.sh  (if needed for Web UIs)"
        echo "  ./env/install-ollama.sh  (for local LLM execution)"
        echo ""
    else
        log_error "Python setup encountered an error."
        echo ""
        echo -e "${COLOR_YELLOW}Troubleshooting:${COLOR_RESET}"
        echo "  1. Ensure you have a stable internet connection."
        echo "  2. Check if Xcode Command Line Tools are installed: xcode-select --install"
        echo ""
    fi

    print_separator
    exit $exit_code
}

# Execute main function
main "$@"
