#!/bin/bash

# ============================================================================
# AI Studio - Environment Install Library (lib/env-install.sh)
# Automates the installation of system dependencies and AI toolchains.
# ============================================================================

# ============================================================================
# 1. Installation Functions
# ============================================================================

install_homebrew() {
    if command_exists "brew"; then
        log_info "Homebrew is already installed. Skipping."
        return 0
    fi
    log_info "Installing Homebrew (this may prompt for your password)..."
    
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ $? -ne 0 ]; then
        log_error "Failed to install Homebrew."
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
    log_info "Checking basic command-line tools..."
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
    log_info "Checking runtime environments (Python, Node.js)..."
    
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
    log_info "Checking AI core tools..."
    if ! command_exists "ollama"; then
        log_info "Installing Ollama (required for local LLM execution)..."
        curl -fsSL https://ollama.com/install.sh | sh
        if [ $? -ne 0 ]; then
            log_error "Failed to install Ollama."
            return 1
        fi
        log_success "Ollama installed successfully."
    else
        log_info "Ollama is already installed."
    fi
    return 0
}

# ============================================================================
# 2. Aggregated Installation Function
# ============================================================================

install_all_dependencies() {
    print_separator
    log_info "Starting AI Studio Environment Installation..."
    log_warn "This process may require your administrator password."
    print_separator

    local failed_steps=0

    install_homebrew
    if [ $? -ne 0 ]; then failed_steps=$((failed_steps + 1)); fi
    
    install_basic_tools
    if [ $? -ne 0 ]; then failed_steps=$((failed_steps + 1)); fi
    
    install_runtime_envs
    if [ $? -ne 0 ]; then failed_steps=$((failed_steps + 1)); fi
    
    install_ai_tools
    if [ $? -ne 0 ]; then failed_steps=$((failed_steps + 1)); fi

    print_separator
    if [ "$failed_steps" -eq 0 ]; then
        log_success "Environment installation completed successfully!"
        log_info "Your system is now fully prepared for AI Studio."
        return 0
    else
        log_error "Environment installation encountered $failed_steps error(s)."
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
