#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_model() {
    local action="${1:-list}"
    log_info "===== AI-Studio 模型管理 ====="; echo ""
    case "$action" in
        list)
            info_box "已安装模型"
            echo -e "\n  ${CLR_BOLD}LLM 模型 (Ollama):${CLR_RESET}"
            if check_command ollama; then ollama list 2>/dev/null | tail -n +2 | while read -r line; do echo -e "    $line"; done
            else echo -e "    ${CLR_DIM}Ollama 未安装${CLR_RESET}"; fi
            echo -e "\n  ${CLR_BOLD}SD/FLUX 模型 (ComfyUI):${CLR_RESET}"
            local md="$AI_STUDIO_DATA_DIR/comfyui/ComfyUI/models/checkpoints"
            [[ -d "$md" ]] && { ls -1 "$md" 2>/dev/null | while read -r f; do echo -e "    $f"; done; } || echo -e "    ${CLR_DIM}无模型${CLR_RESET}"
            echo -e "\n  ${CLR_BOLD}MLX 模型:${CLR_RESET}"
            local mlx_d="$AI_STUDIO_DATA_DIR/mlx/models"
            [[ -d "$mlx_d" ]] && { ls -1 "$mlx_d" 2>/dev/null | while read -r f; do echo -e "    $f"; done; } || echo -e "    ${CLR_DIM}无模型${CLR_RESET}"
            ;;
        pull)
            local model="${2:-}"; [[ -z "$model" ]] && { log_error "用法: model pull <model_name>"; return 1; }
            log_info "拉取模型: $model"
            if [[ "$model" == *"flux"* || "$model" == *"sd"* || "$model" == *"stable"* ]]; then comp_do comfyui download_model "$model"
            elif [[ "$model" == *"mlx"* ]]; then comp_do mlx download_model "$model"
            else check_command ollama && ollama pull "$model" || log_error "需要 Ollama"; fi
            ;;
        download)
            local type="${2:-}" model="${3:-}"
            [[ -z "$model" ]] && { log_error "用法: model download <type> <model>"; return 1; }
            case "$type" in
                llm) check_command ollama && ollama pull "$model" ;;
                sd|flux) comp_do comfyui download_model "$model" ;;
                mlx) comp_do mlx download_model "$model" ;;
                video) comp_do mlx-video download_model "$model" ;;
                *) log_error "未知类型: $type (可选: llm, sd, flux, mlx, video)" ;;
            esac
            ;;
        architectures)
            info_box "支持的架构"
            echo -e "  ${CLR_BOLD}LLM:${CLR_RESET}"
            echo -e "    - Ollama: llama3, qwen2.5, mistral, gemma2, phi3..."
            echo -e "    - MLX: mlx-community/* (Apple Silicon 优化)"
            echo -e "  ${CLR_BOLD}图像生成:${CLR_RESET}"
            echo -e "    - SDXL: stable-diffusion-xl-base-1.0"
            echo -e "    - FLUX: FLUX.1-schnell, FLUX.1-dev"
            echo -e "    - MLX: mlx-community/* SD/FLUX 量化版"
            echo -e "  ${CLR_BOLD}视频生成:${CLR_RESET}"
            echo -e "    - MLX-Video: hunyuan-video, wan2.1 (Apple Silicon)"
            ;;
        *)
            echo -e "${CLR_BOLD}模型子命令:${CLR_RESET}"
            echo -e "  list           - 列出已安装模型"
            echo -e "  pull <name>    - 拉取模型 (自动识别类型)"
            echo -e "  download <type> <name> - 下载指定类型模型"
            echo -e "  architectures  - 查看支持的架构"
            ;;
    esac
}
cmd_model "$@"
