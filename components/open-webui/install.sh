#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Installation Script
# File: components/open-webui/install.sh
# 
# Handles the initial deployment of Open WebUI, including dependency checks,
# repository cloning, virtual environment setup, and package installation.
# ============================================================================

set -e # Exit immediately if a command exits with a non-zero status

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Installation Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Installing: ${COMPONENT_NAME}${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  ${COMPONENT_DESCRIPTION}${COLOR_RESET}"
    print_separator
    echo ""

    # --- Step 1: Idempotency Check ---
    if [[ -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]] && [[ -f "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate" ]]; then
        log_info "${COMPONENT_NAME} appears to be already installed."
        log_info "Skipping installation. Use './ai-studio.sh update ${COMPONENT_NAME}' to upgrade."
        echo ""
        print_separator
        exit 0
    fi

    # --- Step 2: Dependency Verification & Installation ---
    log_info "Step 1/4: Verifying system dependencies..."
    # install_component_deps is defined in lib/env-install.sh
    if ! install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
        log_error "Failed to install required dependencies. Aborting."
        exit 1
    fi

    # --- Step 3: Source Code Retrieval ---
    log_info "Step 2/4: Retrieving source code from ${COMPONENT_REPO}..."
    if [[ ! -d "${COMPONENT_DIR}/.git" ]]; then
        # Clean directory if it exists but is not a git repo
        if [[ -n "$(ls -A "${COMPONENT_DIR}" 2>/dev/null | grep -v 'install.sh\|metadata.sh\|start.sh\|stop.sh\|status.sh\|update.sh\|diagnose.sh\|uninstall.sh')" ]]; then
            log_warn "Directory is not empty and not a git repository. Cleaning up..."
            find "${COMPONENT_DIR}" -mindepth 1 -maxdepth 1 ! -name '*.sh' -exec rm -rf {} +
        fi
        
        git clone --branch "$COMPONENT_BRANCH" "$COMPONENT_REPO" "${COMPONENT_DIR}/.tmp_clone"
        # Move contents to root, preserving standard scripts
        shopt -s dotglob nullglob
        mv "${COMPONENT_DIR}/.tmp_clone"/* "${COMPONENT_DIR}/"
        rm -rf "${COMPONENT_DIR}/.tmp_clone"
        shopt -u dotglob nullglob
        
        log_success "Source code cloned successfully."
    else
        log_info "Source code already exists. Ensuring it's on the correct branch..."
        git checkout "$COMPONENT_BRANCH"
        git pull origin "$COMPONENT_BRANCH"
        log_success "Source code updated."
    fi

    # --- Step 4: Virtual Environment Setup ---
    log_info "Step 3/4: Setting up isolated Python virtual environment..."
    # Use the python3 that was verified/installed by env-install.sh
    if ! python3 -m venv "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}"; then
        log_error "Failed to create Python virtual environment."
        exit 1
    fi
    
    # Activate the virtual environment for the current shell session
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    log_success "Virtual environment created and activated."

    # --- Step 5: Python Dependencies Installation ---
    log_info "Step 4/4: Installing Python dependencies (this may take a few minutes)..."
    
    # Upgrade pip first
    python3 -m pip install --upgrade pip --quiet
    
    # Install requirements. Open WebUI uses requirements.txt for source installations.
    if [[ -f "${COMPONENT_DIR}/requirements.txt" ]]; then
        if ! python3 -m pip install -r "${COMPONENT_DIR}/requirements.txt"; then
            log_error "Failed to install Python dependencies from requirements.txt."
            exit 1
        fi
    else
        # Fallback: install the package directly if requirements.txt is missing (newer versions might change structure)
        log_warn "requirements.txt not found. Attempting to install 'open-webui' package directly..."
        if ! python3 -m pip install open-webui; then
            log_error "Failed to install open-webui package."
            exit 1
        fi
    fi
    
    log_success "Python dependencies installed successfully."

    # --- Step 6: Initialize Data Directories ---
    log_info "Initializing component data directories..."
    ensure_dir "${COMPONENT_DIR}/${COMPONENT_DATA_DIR}"
    log_success "Data directory ready at ${COMPONENT_DATA_DIR}"

    # --- Completion ---
    echo ""
    print_separator
    log_success "${COMPONENT_NAME} has been successfully installed!"
    echo ""
    echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
    echo "  1. Start the service (will auto-open browser):"
    echo "     ./ai-studio.sh start ${COMPONENT_NAME}"
    echo "  2. View service status:"
    echo "     ./ai-studio.sh status ${COMPONENT_NAME}"
    echo ""
    print_separator
}

# Execute main function
main "$@"
