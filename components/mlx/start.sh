#!/bin/bash

# ============================================================================
# AI Studio - MLX Framework Start Script
# File: components/mlx/start.sh
# 
# Since MLX is a foundational Python framework/library and not a standalone 
# background service, this script gracefully handles the "start" command by 
# verifying the installation and providing actionable guidance on how to 
# actually use the framework (e.g., activating the venv, running mlx-lm).
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Logic
# ============================================================================

# Verify that MLX is actually installed and functional
check_installation() {
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    
    if [[ ! -x "$venv_python" ]]; then
        log_error "MLX virtual environment not found."
        return 1
    fi
    
    if ! "$venv_python" -c "import mlx" >/dev/null 2>&1; then
        log_error "MLX is installed but cannot be imported. The environment may be corrupted."
        return 1
    fi
    
    return 0
}

# Provide actionable guidance on how to use MLX
provide_usage_guide() {
    local venv_activate="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/activate"
    
    echo -e "${COLOR_BOLD}${COLOR_CYAN}💡 How to use the MLX Framework:${COLOR_RESET}"
    echo ""
    echo "  MLX is a computational library, not a background service. It does not need"
    echo "  to be 'started'. Instead, you interact with it via Python scripts or CLI tools."
    echo ""
    
    echo -e "  ${COLOR_BOLD}1. Activate the isolated environment:${COLOR_RESET}"
    echo "     ${COLOR_GRAY}source ${venv_activate}${COLOR_RESET}"
    echo ""
    
    echo -e "  ${COLOR_BOLD}2. Verify MLX is using Apple Silicon acceleration:${COLOR_RESET}"
    echo "     ${COLOR_GRAY}python3 -c \"import mlx.core as mx; print('Device:', mx.default_device())\"${COLOR_RESET}"
    echo "     (Expected output: Device: mlx)"
    echo ""
    
    echo -e "  ${COLOR_BOLD}3. Run Large Language Models (via mlx-lm):${COLOR_RESET}"
    echo "     ${COLOR_GRAY}mlx_lm.generate --model mlx-community/Qwen2.5-7B-Instruct-4bit --prompt \"Hello\"${COLOR_RESET}"
    echo ""
    
    echo -e "  ${COLOR_BOLD}4. Download models (Centralized Management):${COLOR_RESET}"
    echo "     ${COLOR_GRAY}./ai-studio.sh install model${COLOR_RESET}"
    echo ""
}

# ============================================================================
# 4. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Verifying: ${COMPONENT_NAME}${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight check
    if ! check_installation; then
        echo ""
        print_separator
        log_error "MLX is not properly installed."
        log_info "To set up the MLX framework and its extensions, run:"
        log_info "  ${COLOR_CYAN}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}"
        print_separator
        exit 1
    fi

    # Step 2: Show version info
    local venv_python="${COMPONENT_DIR}/${COMPONENT_VENV_DIR}/bin/python"
    local mlx_version
    mlx_version=$("$venv_python" -c "import mlx; print(mlx.__version__)" 2>/dev/null)
    
    log_success "MLX v${mlx_version} is installed and ready to use."
    echo ""

    # Step 3: Provide usage guide
    provide_usage_guide

    print_separator
    log_success "No background service to start. Framework is ready for your scripts."
    echo ""
    print_separator
    
    # Always exit 0 to ensure this doesn't break batch operations like `./ai-studio.sh start all`
    exit 0
}

# Execute main function
main "$@"
