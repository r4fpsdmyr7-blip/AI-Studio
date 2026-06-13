#!/usr/bin/env bash
MLX_COMP_NAME="mlx"
MLX_COMP_PORT=""
MLX_COMP_DEPS="python3,pip3"
MLX_COMP_DESC="Apple Silicon ML 框架 (LLM 推理)"
MLX_COMP_DIR="$AI_STUDIO_DATA_DIR/mlx"
comp_install() {
    log_info "安装 MLX..."
    if ! is_apple_silicon; then log_warn "MLX 仅支持 Apple Silicon"; confirm "继续?" || return 1; fi
    require_command python3 || return 1
    mkdir -p "$MLX_COMP_DIR"/{venv,models}; python3 -m venv "$MLX_COMP_DIR/venv" || return 1
    source "$MLX_COMP_DIR/venv/bin/activate"; pip install --upgrade pip
    pip install mlx mlx-lm mlx-vlm huggingface_hub; deactivate
    set_comp_config mlx DIR "$MLX_COMP_DIR"; set_comp_config mlx MODEL_DIR "$MLX_COMP_DIR/models"
    log_success "MLX 安装完成"
}
comp_start() {
    log_info "MLX 通过 API 服务启动..."
    local dir; dir="$(get_comp_config mlx DIR "$MLX_COMP_DIR")"; local port="${1:-8080}"
    source "$dir/venv/bin/activate"
    local model; model="$(get_comp_config mlx DEFAULT_MODEL "")"
    if [[ -z "$model" ]]; then log_warn "未设置默认模型"; deactivate; return 1; fi
    nohup python3 -m mlx_lm.server --model "$model" --port "$port" > "$AI_STUDIO_LOG_DIR/mlx.log" 2>&1 &
    save_pid mlx "$!"; deactivate; log_success "MLX Server 已启动 (端口: $port)"
}
comp_stop() { kill_service mlx; }
comp_status() {
    is_running mlx && echo -e "  API: http://localhost:8080 (OpenAI 兼容)"
    local model_dir; model_dir="$(get_comp_config mlx MODEL_DIR "$MLX_COMP_DIR/models")"
    [[ -d "$model_dir" ]] && echo -e "  本地模型: $(ls -1 "$model_dir" 2>/dev/null | wc -l | xargs) 个"
}
comp_update() {
    local dir; dir="$(get_comp_config mlx DIR "$MLX_COMP_DIR")"
    log_info "更新 MLX..."; source "$dir/venv/bin/activate"
    pip install --upgrade mlx mlx-lm mlx-vlm huggingface_hub; deactivate; log_success "MLX 已更新"
}
comp_download_model() {
    local model="${1:-}"; [[ -z "$model" ]] && { log_error "用法: download_model <model>"; return 1; }
    local dir; dir="$(get_comp_config mlx DIR "$MLX_COMP_DIR")"
    local model_dir; model_dir="$(get_comp_config mlx MODEL_DIR "$dir/models")"
    log_info "下载 MLX 模型: $model"; source "$dir/venv/bin/activate"
    python3 -c "
from huggingface_hub import snapshot_download
snapshot_download('$model', local_dir='$model_dir/$(basename "$model")')
print('下载完成')
"; deactivate
}
comp_uninstall() {
    log_info "卸载 MLX..."; is_running mlx && kill_service mlx
    if confirm "删除所有模型?"; then rm -rf "$MLX_COMP_DIR"; else rm -rf "$MLX_COMP_DIR/venv"; fi
    log_success "MLX 已卸载"
}
