#!/bin/bash

# ============================================================================
# AI Studio - Environment Install Library (lib/env-install.sh)
# Automates the installation of system dependencies and AI toolchains.
# 
# CRITICAL FIX: Refactored to use standard if/then/else blocks instead of 
# inline `|| { ... }` blocks to prevent any potential Bash parsing issues 
# (unexpected EOF) across all macOS Bash versions.
# ============================================================================

# Ensure common functions are available
# This script expects to be sourced after lib/common.sh

# ============================================================================
# 1. Installation Functions
# ============================================================================

install_homebrew() {
    if command_exists "brew"; then
        log_info "Homebrew is already installed. Skipping."
        return 0
    fi

    log_info "Installing Homebrew (this may take a few minutes and may prompt for your password)..."
    
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ $? -ne 0 ]; then
        log_error "Failed to install Homebrew. Please install it manually from https://brew.sh"
        return 1
    fi

    if is_apple_silicon; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    log_success "Homebrew installed and configured successfully."
    return 0
}

install_basic_tools() {
    log_info "Checking and installing basic command-line tools..."
    local tools_to_install=""

    for tool in git curl wget; do
        if ! command_exists "$tool"; then
            tools_to_install="$tools_to_install $tool"
        fi
    done

    if [ -z "$tools_to_install" ]; then
        log_info "All basic tools are already installed."
        return 0
    fi

    log_info "Installing missing tools:$tools_to_install ..."
    brew install $tools_to_install
    if [ $? -ne 0 ]; then
        log_error "Failed to install basic tools via Homebrew."
        return 1
    fi

    log_success "Basic tools installed successfully."
    return 0
}

install_runtime_envs() {
    log_info "Checking and installing runtime environments (Python, Node.js)..."
    
    if ! command_exists "python3"; then
        log_info "Installing Python 3..."
        brew install python@3.11
        if [ $? -ne 0 ]; then
            log_error "Failed to install Python 3."
            return 1
        fi
    else
        log_info "Python 3 is already installed."
    fi

    if ! command_exists "node"; then
        log_info "Installing Node.js (LTS)..."
        brew install node
        if [ $? -ne 0 ]; then
            log_error "Failed to install Node.js."
            return 1
        fi
    else
        log_info "Node.js is already installed."
    fi

    log_success "Runtime environments are ready."
    return 0
}

install_ai_tools() {
    log_info "Checking and installing AI core tools..."

    if ! command_exists "ollama"; then
        log_info "Installing Ollama (required for local LLM execution)..."
        curl -fsSL https://ollama.com/install.sh | sh
        if [ $? -ne 0 ]; then
            log_error "Failed to install Ollama. Please install it manually from https://ollama.com"
            return 1
        fi
        log_success "Ollama installed successfully."
    else
        log_info "Ollama is already installed."
    fi

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

install_all_dependencies() {
    print_separator
    log_info "Starting AI Studio Environment Installation..."
    log_warn "This process may require your administrator password and will download several gigabytes of data."
    print_separator

    local failed_steps=0

    install_homebrew
    if [ $? -ne 0 ]; then
        failed_steps=$((failed_steps + 1))
    fi
    
    install_basic_tools
    if [ $? -ne 0 ]; then
        failed_steps=$((failed_steps + 1))
    fi
    
    install_runtime_envs
    if [ $? -ne 0 ]; then
        failed_steps=$((failed_steps + 1))
    fi
    
    install_ai_tools
    if [ $? -ne 0 ]; then
        failed_steps=$((failed_steps + 1))
    fi

    print_separator

    if [ "$failed_steps" -eq 0 ]; then
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

install_component_deps() {
    local component="$1"
    shift
    local missing_deps=""

    log_info "Checking dependencies for $component..."

    for dep in "$@"; do
        if ! command_exists "$dep"; then
            missing_deps="$missing_deps $dep"
        fi
    done

    if [ -z "$missing_deps" ]; then
        log_info "All dependencies for $component are already installed."
        return 0
    fi

    log_info "Installing missing dependencies for $component:$missing_deps ..."
    brew install $missing_deps
    if [ $? -ne 0 ]; then
        log_error "Failed to install dependencies for $component."
        return 1
    fi

    log_success "Dependencies for $component installed successfully."
    return 0
}
