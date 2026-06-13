#!/usr/bin/env bash
MLX_VIDEO_COMP_NAME="mlx-video"
MLX_VIDEO_COMP_PORT="7860"
MLX_VIDEO_COMP_DEPS="python3,pip3"
MLX_VIDEO_COMP_DESC="Apple Silicon 视频生成 (HunyuanVideo/Wan2.1)"
MLX_VIDEO_COMP_DIR="$AI_STUDIO_DATA_DIR/mlx-video"
comp_install() {
    log_info "安装 MLX-Video..."
    if ! is_apple_silicon; then log_warn "MLX-Video 仅支持 Apple Silicon"; confirm "继续?" || return 1; fi
    require_command python3 || return 1
    mkdir -p "$MLX_VIDEO_COMP_DIR"/{venv,models,outputs}; python3 -m venv "$MLX_VIDEO_COMP_DIR/venv" || return 1
    source "$MLX_VIDEO_COMP_DIR/venv/bin/activate"; pip install --upgrade pip
    pip install mlx mlx-vlm huggingface_hub diffusers gradio ffmpeg-python
    pip install mlx-video 2>/dev/null || { log_warn "mlx-video 包不可用"; pip install imageio[ffmpeg] pillow; }
    deactivate
    set_comp_config mlx-video PORT "$(get_config MLX_VIDEO_PORT 7860)"
    set_comp_config mlx-video DIR "$MLX_VIDEO_COMP_DIR"
    set_comp_config mlx-video MODEL_DIR "$MLX_VIDEO_COMP_DIR/models"
    log_success "MLX-Video 安装完成"
}
comp_start() {
    local port; port="$(get_comp_config mlx-video PORT 7860)"
    local dir; dir="$(get_comp_config mlx-video DIR "$MLX_VIDEO_COMP_DIR")"
    log_info "启动 MLX-Video WebUI (端口: $port)..."; source "$dir/venv/bin/activate"
    cat > "$dir/webui.py" << 'PYEOF'
import gradio as gr, os
MODEL_DIR = os.environ.get("MODEL_DIR", "models")
def generate_video(prompt, steps=20, seed=-1):
    return f"视频生成占位: {prompt} (steps={steps}, seed={seed})\n模型目录: {MODEL_DIR}"
with gr.Blocks(title="MLX-Video") as demo:
    gr.Markdown("# MLX-Video (Apple Silicon)")
    with gr.Row():
        with gr.Column():
            prompt = gr.Textbox(label="Prompt", lines=3)
            steps = gr.Slider(1, 50, value=20, label="Steps")
            seed = gr.Number(value=-1, label="Seed (-1=random)")
            btn = gr.Button("生成视频", variant="primary")
        with gr.Column(): output = gr.Textbox(label="输出")
    btn.click(generate_video, [prompt, steps, seed], output)
demo.launch(server_name="0.0.0.0", server_port=int(os.environ.get("PORT", "7860")))
PYEOF
    MODEL_DIR="$dir/models" PORT="$port" nohup python3 "$dir/webui.py" > "$AI_STUDIO_LOG_DIR/mlx-video.log" 2>&1 &
    save_pid mlx-video "$!"; deactivate
    log_success "MLX-Video 已启动 (PID: $!)"; auto_open_browser mlx-video "$port"
}
comp_stop() { kill_service mlx-video; }
comp_status() { is_running mlx-video && { local port; port="$(get_comp_config mlx-video PORT 7860)"; echo -e "  Web UI: http://localhost:$port"; }; }
comp_update() {
    local dir; dir="$(get_comp_config mlx-video DIR "$MLX_VIDEO_COMP_DIR")"
    log_info "更新 MLX-Video..."; source "$dir/venv/bin/activate"
    pip install --upgrade mlx mlx-vlm gradio huggingface_hub; deactivate; log_success "MLX-Video 已更新"
}
comp_download_model() {
    local model="${1:-}"; [[ -z "$model" ]] && { log_error "用法: download_model <model>"; return 1; }
    local dir; dir="$(get_comp_config mlx-video DIR "$MLX_VIDEO_COMP_DIR")"
    local model_dir; model_dir="$(get_comp_config mlx-video MODEL_DIR "$dir/models")"
    log_info "下载视频模型: $model"; source "$dir/venv/bin/activate"
    python3 -c "
from huggingface_hub import snapshot_download
snapshot_download('$model', local_dir='$model_dir/$(basename "$model")')
print('下载完成')
"; deactivate
}
comp_uninstall() {
    log_info "卸载 MLX-Video..."; is_running mlx-video && kill_service mlx-video
    if confirm "删除所有模型?"; then rm -rf "$MLX_VIDEO_COMP_DIR"; else rm -rf "$MLX_VIDEO_COMP_DIR/venv"; fi
    log_success "MLX-Video 已卸载"
}
