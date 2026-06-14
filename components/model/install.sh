#!/bin/bash

# ============================================================================
# AI Studio - Model Repository Installation Script
# File: components/model/install.sh
# 
# Handles the centralized downloading and management of large MLX-optimized 
# models (LLMs, SD, FLUX). It uses hf-transfer for high-speed, resumable 
# downloads and stores all models in a shared global directory to save disk space.
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

# Check available disk space specifically for the model directory
check_model_disk_space() {
    local target_dir="$1"
    local required_gb="${2:-50}" # Default require 50GB for large models
    
    # Get available space in GB on the partition containing the target directory
    local avail_gb
    avail_gb=$(df -g "$target_dir" | awk 'NR==2 {print $4}' | tr -dc '0-9')
    
    if [[ "$avail_gb" -lt "$required_gb" ]]; then
        log_error "Insufficient disk space at ${target_dir}."
        log_info "Found: ${avail_gb}GB, Required: ${required_gb}GB+ for large MLX models."
        return 1
    fi
    log_success "Disk space check passed (${avail_gb}GB available at ${target_dir})."
    return 0
}

# Download a specific MLX model from Hugging Face
# Usage: download_mlx_model "mlx-community/Qwen3-35B-Uncensored-MLX" "qwen3-35b-uncensored"
download_mlx_model() {
    local repo_id="$1"
    local model_dir_name="$2"
    local target_path="${COMPONENT_DATA_DIR}/${model_dir_name}"
    
    log_info "Checking model: ${COLOR_CYAN}${model_dir_name}${COLOR_RESET}"
    
    # Idempotency check: If config.json or a .safetensors file exists, assume it's downloaded
    if [[ -f "${target_path}/config.json" ]] || [[ -n "$(ls -A "${target_path}"/*.safetensors 2>/dev/null)" ]]; then
        log_success "Model '${model_dir_name}' already exists. Skipping download."
        return 0
    fi

    log_info "Downloading ${repo_id} to ${target_path}..."
    log_warn "${COLOR_YELLOW}This is a large file. The download supports resuming if interrupted.${COLOR_RESET}"
    
    # Ensure parent directory exists
    ensure_dir "$(dirname "$target_path")"

    # Enable hf-transfer for massive speedup (Rust-based, multi-threaded)
    # HUGGING_FACE_HUB_TOKEN can be set by user if downloading gated/private models
    export HF_HUB_ENABLE_HF_TRANSFER=1
    
    # Use huggingface-cli to download. 
    # --resume-download is critical for large models over unstable connections
    if huggingface-cli download "$repo_id" --local-dir "$target_path" --resume-download; then
        log_success "Successfully downloaded ${model_dir_name}."
        return 0
    else
        log_error "Failed to download ${model_dir_name}."
        log_info "Troubleshooting:"
        log_info "  1. Check your internet connection."
        log_info "  2. If this is a gated model, run: huggingface-cli login"
        log_info "  3. Ensure you have accepted the model license on Hugging Face."
        return 1
    fi
}

# ============================================================================
# 4. Main Execution Flow
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Installing: ${COMPONENT_NAME} (MLX Model Repository)${COLOR_RESET}"
    echo -e "${COLOR_GRAY}  Centralized storage for Qwen3, SD, and FLUX MLX models${COLOR_RESET}"
    print_separator
    echo ""

    # Step 1: Dependency Verification & Installation
    log_info "Step 1/3: Verifying system dependencies for large file downloads..."
    if ! install_component_deps "$COMPONENT_NAME" $COMPONENT_REQUIRED_DEPS; then
        log_error "Failed to install required dependencies. Aborting."
        exit 1
    fi

    # Step 2: Disk Space Verification
    log_info "Step 2/3: Verifying disk space for model storage..."
    # FLUX and 35B LLMs can easily exceed 30-40GB. We require at least 50GB free.
    if ! check_model_disk_space "$COMPONENT_DATA_DIR" 50; then
        exit 1
    fi

    # Step 3: Model Download Execution
    log_info "Step 3/3: Downloading MLX-optimized models..."
    echo ""
    
    local download_failed=0

    # 1. Qwen3 35B Uncensored (Aggressive variant)
    # Note: Replace repo_id with the actual mlx-community converted repository name
    download_mlx_model "mlx-community/Qwen3-35B-A3B-Uncensored-HauHauCS-Aggressive" "qwen3-35b-uncensored" || ((download_failed++))
    
    echo ""
    
    # 2. Stable Diffusion (e.g., SD 3.5 Large or SDXL)
    download_mlx_model "mlx-community/stable-diffusion-3.5-large" "stable-diffusion-3.5-large" || ((download_failed++))
    
    echo ""
    
    # 3. FLUX.1 (Dev or Schnell)
    download_mlx_model "mlx-community/FLUX.1-dev" "flux.1-dev" || ((download_failed++))

    echo ""
    print_separator

    if [[ $download_failed -gt 0 ]]; then
        log_error "Model installation completed with $download_failed error(s)."
        log_info "Please review the errors above. You can re-run this script to resume failed downloads."
        exit 1
    else
        log_success "All specified MLX models have been successfully downloaded!"
        echo ""
        echo -e "${COLOR_CYAN}Integration Guide:${COLOR_RESET}"
        echo "  Your models are centrally stored at: ${COLOR_BOLD}${COMPONENT_DATA_DIR}${COLOR_RESET}"
        echo ""
        echo "  To use these models in other components:"
        echo "  • ComfyUI: Add this path to your 'extra_model_paths.yaml'"
        echo "  • MLX-Video / Custom Scripts: Set your model path argument to this directory"
        echo "  • Ollama (for LLMs): You may need to convert or link these, or use native Ollama pull"
        echo ""
        echo -e "${COLOR_GRAY}💡 Tip: Run './ai-studio.sh update model --target models' later to check for model weight updates.${COLOR_RESET}"
        echo ""
    fi

    print_separator
    exit 0
}

# Execute main function
main "$@"
