#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Diagnosis Script
# File: components/model/diagnose.sh
# 
# Provides simple, deep, and auto-fix diagnostic capabilities specifically 
# tailored for the centralized MLX model repository. It focuses on file 
# integrity, disk space, and toolchain health rather than process status.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/diagnose.sh" # Core diagnosis logic
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Component-Specific Diagnostic Checks
# ============================================================================

# Check 1: Model Directory Accessibility and Permissions
check_model_directory_access() {
    local data_dir="$COMPONENT_DATA_DIR"
    
    if [[ ! -d "$data_dir" ]]; then
        echo "CRITICAL: Model directory does not exist."
        echo "  -> Run './ai-studio.sh install model' to create it and download models."
        return 1
    fi
    
    if [[ ! -w "$data_dir" ]]; then
        echo "CRITICAL: Model directory exists but is not writable."
        echo "  -> Model downloads and updates will fail."
        return 1
    fi
    
    echo "OK: Model directory is accessible and writable."
    return 0
}

# Check 2: Model File Integrity (Deep Diagnosis)
check_model_integrity() {
    local data_dir="$COMPONENT_DATA_DIR"
    local issues=0
    local has_models=false
    
    # Iterate through immediate subdirectories
    for model_dir in "$data_dir"/*/; do
        [[ -d "$model_dir" ]] || continue
        has_models=true
        
        local model_name
        model_name=$(basename "$model_dir")
        local has_config=false
        local has_weights=false
        
        # Check for essential MLX model files
        if [[ -f "${model_dir}config.json" ]]; then
            has_config=true
        fi
        
        if ls "${model_dir}"*.safetensors 1>/dev/null 2>&1 || \
           ls "${model_dir}"*.npz 1>/dev/null 2>&1 || \
           [[ -f "${model_dir}model.safetensors" ]] || \
           [[ -f "${model_dir}model.npz" ]]; then
            has_weights=true
        fi

        if [[ "$has_config" == false ]] && [[ "$has_weights" == false ]]; then
            echo "CRITICAL: Model '${model_name}' appears empty or corrupted."
            echo "  -> Missing both config.json and weight files (.safetensors/.npz)."
            ((issues++))
        elif [[ "$has_config" == false ]] || [[ "$has_weights" == false ]]; then
            echo "WARNING: Model '${model_name}' is incomplete."
            echo "  -> Missing either config.json or weight files. Download may have been interrupted."
            ((issues++))
        fi
    done
    
    if [[ "$has_models" == false ]]; then
        echo "INFO: No models found in directory. (Not an error, but nothing to verify)."
    elif [[ $issues -eq 0 ]]; then
        echo "OK: All discovered models appear structurally complete."
    fi
    
    return $issues
}

# Check 3: Disk Space for Large Models (Deep Diagnosis)
check_model_disk_space() {
    local data_dir="$COMPONENT_DATA_DIR"
    local avail_gb
    avail_gb=$(df -g "$data_dir" 2>/dev/null | awk 'NR==2 {print $4}' | tr -dc '0-9')
    
    if [[ -z "$avail_gb" ]]; then
        echo "WARNING: Could not determine available disk space."
        return 0
    fi
    
    if [[ "$avail_gb" -lt 20 ]]; then
        echo "CRITICAL: Less than 20GB of free space remaining on model partition."
        echo "  -> Downloading large MLX models (e.g., FLUX, 35B LLMs) will likely fail."
        return 1
    elif [[ "$avail_gb" -lt 50 ]]; then
        echo "WARNING: Less than 50GB of free space remaining."
        echo "  -> You may run out of space when downloading additional large models."
        return 0 # Warning, not critical
    else
        echo "OK: Sufficient disk space available (${avail_gb}GB)."
        return 0
    fi
}

# Check 4: Download Toolchain Health
check_toolchain_health() {
    local issues=0
    
    if ! command_exists "huggingface-cli"; then
        echo "CRITICAL: 'huggingface-cli' is not installed or not in PATH."
        echo "  -> Required for downloading and updating models."
        ((issues++))
    else
        # Quick version check to ensure it's not a broken symlink
        if ! huggingface-cli version >/dev/null 2>&1; then
            echo "WARNING: 'huggingface-cli' is present but fails to execute."
            ((issues++))
        fi
    fi
    
    # hf-transfer is optional but highly recommended
    if command_exists "python3"; then
        if ! python3 -c "import hf_transfer" >/dev/null 2>&1; then
            echo "WARNING: 'hf-transfer' Python package is missing."
            echo "  -> Model downloads will be significantly slower. Run './ai-studio.sh install model' to fix."
            # Not a critical failure, but worth noting
        fi
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "OK: Model download toolchain is healthy."
    fi
    
    return $issues
}

# ============================================================================
# 4. Component-Specific Auto-Fix Logic
# ============================================================================

attempt_model_fix() {
    local fixed=0
    
    # Fix 1: Repair directory permissions
    if [[ -d "$COMPONENT_DATA_DIR" ]] && [[ ! -w "$COMPONENT_DATA_DIR" ]]; then
        log_info "  -> Attempting to fix model directory permissions..."
        if chmod u+w "$COMPONENT_DATA_DIR" 2>/dev/null; then
            log_success "    Model directory permissions repaired."
            ((fixed++))
        else
            log_error "    Failed to repair permissions. Manual intervention required."
        fi
    fi
    
    # Fix 2: Reinstall missing toolchain dependencies
    if ! command_exists "huggingface-cli" || ! python3 -c "import hf_transfer" >/dev/null 2>&1; then
        log_info "  -> Attempting to repair model download toolchain..."
        if install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
            log_success "    Toolchain dependencies repaired."
            ((fixed++))
        else
            log_error "    Failed to repair toolchain. Please run './ai-studio.sh install model' manually."
        fi
    fi
    
    # Note: We intentionally DO NOT auto-delete corrupted model files. 
    # Deleting multi-gigabyte files automatically is too risky. 
    # The user must manually delete them or re-run the install/update script.
    
    return $fixed
}

# ============================================================================
# 5. Main Execution Flow
# ============================================================================

main() {
    # Parse arguments
    local is_deep=false
    local do_fix=false
    
    for arg in "$@"; do
        case "$arg" in
            --deep) is_deep=true ;;
            --fix) do_fix=true ;;
        esac
    done

    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Diagnosing: ${COMPONENT_NAME} (MLX Model Repository)${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  Note: Models are static assets and do not run as background services.${COLOR_RESET}"
    print_separator
    echo ""

    local specific_issues=0
    local result

    # --- Component-Specific Checks ---
    log_info "Running model repository specific checks..."
    
    result=$(check_model_directory_access)
    echo -e "  [${COLOR_BLUE}DIRECTORY${COLOR_RESET}] $result"
    [[ $? -ne 0 ]] && ((specific_issues++))
    
    if [[ "$is_deep" == true ]]; then
        result=$(check_model_integrity)
        echo -e "  [${COLOR_BLUE}INTEGRITY${COLOR_RESET}] $result"
        [[ $? -ne 0 ]] && ((specific_issues++))
        
        result=$(check_model_disk_space)
        echo -e "  [${COLOR_BLUE}DISK_SPACE${COLOR_RESET}] $result"
        [[ $? -ne 0 ]] && ((specific_issues++))
        
        result=$(check_toolchain_health)
        echo -e "  [${COLOR_BLUE}TOOLCHAIN${COLOR_RESET}] $result"
        [[ $? -ne 0 ]] && ((specific_issues++))
    else
        echo -e "  [${COLOR_BLUE}INTEGRITY${COLOR_RESET}] ${COLOR_GRAY}Skipped (Use --deep to check model file integrity)${COLOR_RESET}"
        echo -e "  [${COLOR_BLUE}DISK_SPACE${COLOR_RESET}] ${COLOR_GRAY}Skipped (Use --deep to check storage capacity)${COLOR_RESET}"
        echo -e "  [${COLOR_BLUE}TOOLCHAIN${COLOR_RESET}] ${COLOR_GRAY}Skipped (Use --deep to check download tools)${COLOR_RESET}"
    fi

    # --- Auto-Fix Execution ---
    if [[ $specific_issues -gt 0 ]] && [[ "$do_fix" == true ]]; then
        echo ""
        attempt_model_fix
        # Re-evaluate after fix (simplified: just report that fix was attempted)
    elif [[ $specific_issues -gt 0 ]] && [[ "$do_fix" != true ]]; then
        echo ""
        log_info "Tip: Run with '--deep --fix' to attempt automatic resolution of fixable issues (e.g., permissions, missing tools)."
        log_info "Note: Corrupted model files must be deleted manually or re-downloaded."
    fi

    echo ""
    print_separator
    
    if [[ $specific_issues -gt 0 ]]; then
        log_warn "Diagnosis completed with $specific_issues issue(s) detected."
        exit 1
    else
        if [[ "$is_deep" == true ]]; then
            log_success "Deep diagnosis completed. The model repository is healthy and ready for use."
        else
            log_success "Basic diagnosis completed. The model repository is accessible."
        fi
        exit 0
    fi
}

# Execute main function
main "$@"
