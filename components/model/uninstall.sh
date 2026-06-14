#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Uninstall Script
# File: components/model/uninstall.sh
# 
# Handles the safe removal of the MLX model repository management scripts.
# Due to the massive size of model assets (e.g., 35B LLMs, FLUX), this script 
# implements strict confirmation protocols to prevent accidental data loss.
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
# 3. Argument Parsing
# ============================================================================

KEEP_DATA=true # DEFAULT TO TRUE for models to prevent accidental massive deletions
FORCE_UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        --purge-models) # Specific flag for models to explicitly delete the heavy assets
            KEEP_DATA=false
            shift
            ;;
        --force)
            FORCE_UNINSTALL=true
            shift
            ;;
        *)
            log_error "Unknown uninstall argument: $1"
            log_info "Usage: ./ai-studio.sh uninstall ${COMPONENT_NAME} [--keep-data] [--purge-models] [--force]"
            log_info "Note: By default, this command ONLY removes management scripts and keeps your models safe."
            exit 1
            ;;
    esac
done

# ============================================================================
# 4. Core Uninstall Logic
# ============================================================================

check_installation() {
    if [[ ! -d "$COMPONENT_DATA_DIR" ]] && [[ ! -f "${AI_STUDIO_ROOT}/logs/model-manager.log" ]]; then
        log_info "${COMPONENT_NAME} management files do not appear to exist. Nothing to uninstall."
        return 1
    fi
    return 0
}

# Calculate and display the size of models to be deleted
show_deletion_impact() {
    if [[ -d "$COMPONENT_DATA_DIR" ]]; then
        local total_size
        total_size=$(du -sh "$COMPONENT_DATA_DIR" 2>/dev/null | awk '{print $1}')
        echo ""
        echo -e "${COLOR_RED}⚠️  CRITICAL DATA DESTRUCTION WARNING  ⚠️${COLOR_RESET}"
        echo -e "${COLOR_RED}You are about to permanently delete ALL downloaded MLX models.${COLOR_RESET}"
        echo -e "${COLOR_RED}This includes large assets like Qwen3 35B, FLUX, and Stable Diffusion.${COLOR_RESET}"
        echo ""
        echo -e "  Target Directory: ${COLOR_GRAY}${COMPONENT_DATA_DIR}${COLOR_RESET}"
        echo -e "  Space to be freed: ${COLOR_BOLD}${total_size:-Unknown}${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_RED}THIS ACTION CANNOT BE UNDONE.${COLOR_RESET}"
    fi
}

confirm_destruction() {
    if [[ "$FORCE_UNINSTALL" == true ]]; then
        return 0 # Skip confirmation in force mode
    fi

    show_deletion_impact

    # Require explicit, full-string confirmation for destructive action
    local confirm_input
    read -r -p "$(echo -e "${COLOR_RED}Type 'DELETE ALL MODELS' to confirm permanent deletion: ${COLOR_RESET}")" confirm_input
    
    if [[ "$confirm_input" == "DELETE ALL MODELS" ]]; then
        log_warn "Confirmation received. Proceeding with model deletion..."
        return 0
    else
        log_info "Uninstallation cancelled. Your models are safe."
        exit 0
    fi
}

cleanup_files() {
    log_info "Cleaning up component files..."
    
    # 1. Clean up global log file
    local log_file="${AI_STUDIO_ROOT}/logs/model-manager.log"
    if [[ -f "$log_file" ]]; then
        rm -f "$log_file"
        log_info "Cleared model manager log file."
    fi

    # 2. Clean up component-specific config file (if any)
    local conf_file="${AI_STUDIO_ROOT}/config/${COMPONENT_NAME}.conf"
    if [[ -f "$conf_file" ]]; then
        rm -f "$conf_file"
        log_info "Cleared model configuration file."
    fi

    # 3. Handle the main data directory based on KEEP_DATA flag
    if [[ "$KEEP_DATA" == true ]]; then
        log_success "Model assets preserved at: ${COLOR_CYAN}${COMPONENT_DATA_DIR}${COLOR_RESET}"
        log_info "Only management logs and configs were removed. You can reinstall the manager anytime."
    else
        if [[ -d "$COMPONENT_DATA_DIR" ]]; then
            log_warn "Permanently deleting model directory: ${COMPONENT_DATA_DIR}"
            if rm -rf "$COMPONENT_DATA_DIR"; then
                log_success "Model assets successfully deleted. Disk space has been freed."
            else
                log_error "Failed to delete model directory. You may need to remove it manually with sudo."
            fi
        fi
    fi
}

# ============================================================================
# 5. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_RED}  Uninstalling: ${COMPONENT_NAME}${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Pre-flight check
    if ! check_installation; then
        print_separator
        exit 0
    fi

    # Step 2: Strict Confirmation (if purging)
    if [[ "$KEEP_DATA" == false ]]; then
        confirm_destruction
    else
        log_info "Default mode: Preserving all downloaded model weights."
        log_info "This will only remove AI Studio management logs and configurations."
    fi

    # Step 3: Execute Cleanup
    echo ""
    cleanup_files

    # Step 4: Completion
    echo ""
    print_separator
    log_success "${COMPONENT_NAME} management has been successfully uninstalled!"
    echo ""
    
    if [[ "$KEEP_DATA" == true ]]; then
        echo -e "${COLOR_CYAN}Note:${COLOR_RESET}"
        echo "  Your models are still intact at: ${COMPONENT_DATA_DIR}"
        echo "  Other components (like ComfyUI) can still access them if configured."
    else
        echo -e "${COLOR_YELLOW}Note:${COLOR_RESET}"
        echo "  All local model weights have been permanently deleted."
        echo "  You will need to re-download them to use image/LLM generation features."
    fi
    
    echo ""
    echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
    echo "  • View remaining components: ./ai-studio.sh list"
    echo ""
    print_separator
    
    exit 0
}

# Execute main function
main "$@"
