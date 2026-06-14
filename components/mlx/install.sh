#!/bin/bash

# ============================================================================
# AI Studio - MLX Framework Installation Script
# File: components/mlx/install.sh
# 
# Handles the initial deployment of the MLX framework and its core extensions 
# (mlx-lm, mlx-vlm). It sets up an isolated Python environment to prevent 
# dependency conflicts with other AI components.
# ============================================================================

set -u # Prevent unbound variable errors

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

    # Hardware Check (MLX is optimized for Apple Silicon)
    if ! is_apple_silicon; then
        log_warn "MLX is designed for Apple Silicon (M1/M2/M3/M4). You are on $(uname -m)."
        log_info "Installation will proceed, but performance will be significantly limited or unsupported."
        echo ""
    fi

    # --- Step 1: Idempotency Check ---
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    if [[ -x "$venv_python" ]]; then
        if "$venv_python" -c "import mlx" >/dev/null 2>&1; then
            log_info "${COMPONENT_NAME} appears to be already installed and functional."
            log_info "Skipping installation. Use './ai-studio.sh update ${COMPONENT_NAME}' to upgrade."
            echo ""
            print_separator
            exit 0
        else
            log_warn "Virtual environment exists but MLX is not importable. Re-installing..."
        fi
    fi

    # --- Step 2: Dependency Verification & Installation ---
    log_info "Step 1/4: Verifying system dependencies..."
    if ! install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
        log_error "Failed to install required dependencies (python3, git, cmake). Aborting."
        exit 1
    fi

    # --- Step 3: Virtual Environment Setup ---
    log_info "Step 2/4: Setting up isolated Python virtual environment..."
    if [[ -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        log_info "Removing existing corrupted or incomplete virtual environment..."
        rm -rf "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}"
    fi

    if ! python3 -m venv "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}"; then
        log_error "Failed to create Python virtual environment."
        exit 1
    fi
    
    # Activate the virtual environment for the current shell session
    # shellcheck disable=SC1091
    source "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    log_success "Virtual environment created and activated."

    # --- Step 4: Python Packages Installation ---
    log_info "Step 3/4: Installing MLX framework and core extensions..."
    
    # Upgrade pip first
    python3 -m pip install --upgrade pip --quiet
    
    # Install core MLX packages
    # We install them together to let pip resolve dependencies optimally
    local packages_to_install=(
        "mlx"
        "mlx-lm"      # Essential for running LLMs like Qwen
        "mlx-vlm"     # Essential for Vision-Language Models
        "huggingface-hub" # Required for downloading models
        "numpy"
    )

    log_info "Installing: ${packages_to_install[*]} ..."
    if ! python3 -m pip install "${packages_to_install[@]}"; then
        log_error "Failed to install MLX Python packages."
        log_info "This may be due to missing system headers (ensure Xcode CLI tools are installed)."
        exit 1
    fi
    
    log_success "MLX packages installed successfully."

    # --- Step 5: Verification & Initialization ---
    log_info "Step 4/4: Verifying installation..."
    local mlx_version
    mlx_version=$(python3 -c "import mlx; print(mlx.__version__)" 2>/dev/null)
    
    if [[ -n "$mlx_version" ]]; then
        log_success "MLX v${mlx_version} is successfully installed and verified."
    else
        log_error "Installation verification failed. MLX module could not be imported."
        exit 1
    fi

    # Initialize the global cache directory for MLX models
    ensure_dir "$COMPONENT_DATA_DIR"
    log_info "Initialized MLX cache directory at: ${COMPONENT_DATA_DIR}"

    # --- Completion ---
    echo ""
    print_separator
    log_success "${COMPONENT_NAME} has been successfully installed!"
    echo ""
    echo -e "${COLOR_CYAN}Next Steps & Usage:${COLOR_RESET}"
    echo "  MLX is a foundational framework. You typically don't 'start' it directly."
    echo "  Instead, use it via:"
    echo "  1. The 'model' component to download weights: ./ai-studio.sh install model"
    echo "  2. Custom Python scripts activating this venv: source ${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    echo "  3. Other AI Studio components that depend on MLX."
    echo ""
    print_separator
}

# Execute main function
main "$@"
