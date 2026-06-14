#!/bin/bash

# ============================================================================
# AI Studio - Environment Install Library (lib/env-install.sh)
# Automates the installation of system dependencies and AI toolchains.
# ============================================================================

# Ensure common functions are available
# This script expects to be sourced after lib/common.sh

# ============================================================================
# 1. Installation Functions
# ============================================================================

# Install Homebrew (The missing package manager for macOS)
install_homebrew() {
    if command_exists "brew"; then
        log_info "Homebrew is already installed. Skipping."
        return 0
    fi

    log_info "Installing Homebrew (this may take a few minutes and may prompt for your password)..."
    
    # Non-interactive Homebrew installation
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        log_error "Failed to install Homebrew. Please install it manually from https://brew.sh"
        return 1
    }

    # Configure PATH for the current session based on architecture
    if is_apple_silicon; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    log_success "Homebrew installed and configured successfully."
    return 0
}

# Install basic command-line utilities
install_basic_tools() {
    log_info "Checking and installing basic command-line tools..."
    local tools_to_install=()

    # Check which required tools are missing
    for tool in git curl wget; do
        if ! command_exists "$tool"; then
            tools_to_install+=("$tool")
        fi
    done

    if [[ ${#tools_to_install[@]} -eq 0 ]]; then
        log_info "All basic tools are already installed."
        return 0
    fi

    log_info "Installing missing tools: ${tools_to_install[*]}..."
    # Use brew to install. We assume brew is available because install_homebrew runs first.
    brew install "${tools_to_install[@]}" || {
        log_error "Failed to install basic tools via Homebrew."
        return 1
    }

    log_success "Basic tools installed successfully."
    return 0
}

# Install runtime environments (Python, Node.js)
install_runtime_envs() {
    log_info "Checking and installing runtime environments (Python, Node.js)..."
    
    # Install Python 3
    if ! command_exists "python3"; then
        log_info "Installing Python 3..."
        brew install python@3.11 || {
            log_error "Failed to install Python 3."
            return 1
        }
    else
        log_info "Python 3 is already installed."
    fi

    # Install Node.js (LTS version)
    if ! command_exists "node"; then
        log_info "Installing Node.js (LTS)..."
        brew install node || {
            log_error "Failed to install Node.js."
            return 1
        }
    else
        log_info "Node.js is already installed."
    fi

    log_success "Runtime environments are ready."
    return 0
}

# Install AI-specific core tools (Ollama)
install_ai_tools() {
    log_info "Checking and installing AI core tools..."

    # Install Ollama
    if ! command_exists "ollama"; then
        log_info "Installing Ollama (required for local LLM execution)..."
        # Official Ollama macOS installation script
        curl -fsSL https://ollama.com/install.sh | sh || {
            log_error "Failed to install Ollama. Please install it manually from https://ollama.com"
            return 1
        }
        log_success "Ollama installed successfully."
    else
        log_info "Ollama is already installed."
    fi

    # Optional: Ensure Rosetta 2 is installed on Apple Silicon (required for some x86_64 binaries)
    if is_apple_silicon; then
        if ! pgrep oahd >/dev/null; then
            log_info "Installing Rosetta 2 for compatibility with x86_64 binaries..."
            softwareupdate --install-rosetta --agree-to-license >/dev/null 2>&1
            log_success "Rosetta 2 installed."
        fi
    fi

    return 0
}

# ============================================================================
# 2. Aggregated Installation Function
# ============================================================================

# Run all installation steps in sequence
# Usage: install_all_dependencies
install_all_dependencies() {
    print_separator
    log_info "Starting AI Studio Environment Installation..."
    log_warn "This process may require your administrator password and will download several gigabytes of data."
    print_separator

    local failed_steps=0

    # Step 1: Homebrew (Foundation)
    install_homebrew || ((failed_steps++))
    
    # If Homebrew failed, subsequent steps will likely fail, but we continue to report all issues
    # Step 2: Basic Tools
    install_basic_tools || ((failed_steps++))
    
    # Step 3: Runtimes
    install_runtime_envs || ((failed_steps++))
    
    # Step 4: AI Tools
    install_ai_tools || ((failed_steps++))

    print_separator

    if [[ $failed_steps -eq 0 ]]; then
        log_success "Environment installation completed successfully!"
        log_info "Your system is now fully prepared for AI Studio."
        log_info "You can now run './ai-studio.sh install <component>' to deploy your first AI tool."
        return 0
    else
        log_error "Environment installation encountered $failed_steps error(s)."
        log_info "Please review the errors above. You may need to install some components manually or resolve network issues."
        return 1
    fi
}

# ============================================================================
# 3. Helper for Specific Component Dependencies
# ============================================================================

# Install dependencies for a specific component (called by component install.sh scripts)
# Usage: install_component_deps "comfyui" "python3" "git" "wget"
install_component_deps() {
    local component="$1"
    shift
    local deps=("$@")
    local missing_deps=()

    log_info "Checking dependencies for $component..."

    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps
