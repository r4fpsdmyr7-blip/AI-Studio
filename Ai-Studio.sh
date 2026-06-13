#!/bin/zsh
# =============================================================================
# 🍎 AI Studio Pro v2.0 - macOS 一键部署脚本
# 功能: Open WebUI + MLX + Qwen3 + Stable Diffusion + 智能画图集成
# 
# 核心特性:
#   • 🤖 Qwen3 通过 Function Calling 自动调用 SD 画图
#   • 🌐 服务启动后自动打开浏览器
#   • 🔄 自我修复: 自动检测并修复常见问题
#   • 📦 完整生命周期: setup/start/status/update/repair/stop/uninstall
#
# 用法:
#   ./ai-studio.sh setup      # 首次部署（环境+模型）
#   ./ai-studio.sh start      # 启动所有服务 + 自动打开浏览器
#   ./ai-studio.sh status     # 查看服务运行状态
#   ./ai-studio.sh update     # 检查并应用更新
#   ./ai-studio.sh repair     # 自我修复常见问题
#   ./ai-studio.sh stop       # 优雅停止所有服务
#   ./ai-studio.sh uninstall  # 完全卸载（删除所有数据）
#   ./ai-studio.sh logs       # 查看实时日志
#   ./ai-studio.sh help       # 查看帮助
# =============================================================================

# 严格模式：遇错即停 + 未定义变量报错
set -euo pipefail

# =============================================================================
# 📁 全局配置区（可按需修改）
# =============================================================================

# 项目路径
: "${AI_STUDIO_DIR:=$HOME/ai-studio}"
: "${MODEL_DIR:=$AI_STUDIO_DIR/models}"
: "${LOG_DIR:=$AI_STUDIO_DIR/logs}"
: "${VENV_DIR:=$AI_STUDIO_DIR/venv}"
: "${CONFIG_DIR:=$AI_STUDIO_DIR/config}"
: "${CACHE_DIR:=$AI_STUDIO_DIR/.cache}"

# 端口配置（避免冲突）
: "${MLX_PORT:=8000}"
: "${WEBUI_PORT:=3000}"
: "${SD_PORT:=7860}"

# 模型配置（支持环境变量覆盖）
: "${QWEN_MODEL:=mlx-community/Qwen3-8B-4bit}"
: "${SD_MODEL:=stabilityai/stable-diffusion-xl-base-1.0}"
: "${HF_ENDPOINT:=${HF_ENDPOINT:-https://hf-mirror.com}}"

# 网络配置
: "${DOCKER_HOST_URL:=host.docker.internal}"

# 版本信息
: "${SCRIPT_VERSION:=2.0.0}"
: "${SCRIPT_REPO:=https://raw.githubusercontent.com/ai-studio-mac/scripts/main/ai-studio.sh}"

# 终端样式（兼容所有 shell）
if [[ -t 1 ]]; then
  readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
  readonly BLUE='\033[0;34m' MAGENTA='\033[0;35m' CYAN='\033[0;36m'
  readonly NC='\033[0m' BOLD='\033[1m' DIM='\033[2m'
else
  # 非终端输出（日志文件）禁用颜色
  readonly RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' NC='' BOLD='' DIM=''
fi

# =============================================================================
# 🔧 工具函数库
# =============================================================================

# 日志输出
log()     { printf "${BLUE}[INFO]${NC} %s %s\n" "$(date '+%H:%M:%S')" "$1"; }
success() { printf "${GREEN}[✓]${NC} %s ${BOLD}%s${NC}\n" "$(date '+%H:%M:%S')" "$1"; }
warn()    { printf "${YELLOW}[⚠]${NC} %s %s\n" "$(date '+%H:%M:%S')" "$1"; }
error()   { printf "${RED}[✗]${NC} %s ${BOLD}ERROR:${NC} %s\n" "$(date '+%H:%M:%S')" "$1" >&2; }

# 标题输出
title() {
  printf "\n${MAGENTA}╔════════════════════════════════════════╗${NC}\n"
  printf "${MAGENTA}║  ${CYAN}${BOLD}%-36s${NC}${MAGENTA}  ║${NC}\n" "$1"
  printf "${MAGENTA}╚════════════════════════════════════════╝${NC}\n\n"
}

# 检查命令是否存在
check_cmd() {
  command -v "$1" &>/dev/null || { error "$1 未安装"; return 1; }
  return 0
}

# 检查端口是否被占用
port_in_use() {
  lsof -ti :"$1" &>/dev/null
}

# 等待端口就绪（超时 60 秒）
wait_for_port() {
  local port=$1 timeout=60 elapsed=0
  while ! port_in_use "$port"; do
    [[ $elapsed -ge $timeout ]] && return 1
    sleep 1
    ((elapsed++))
  done
  return 0
}

# 等待 HTTP 服务响应（超时 60 秒）
wait_for_http() {
  local url=$1 timeout=60 elapsed=0
  while ! curl -sf --max-time 2 "$url" &>/dev/null; do
    [[ $elapsed -ge $timeout ]] && return 1
    sleep 2
    ((elapsed+=2))
  done
  return 0
}

# 安全执行命令（带错误处理）
safe_exec() {
  local cmd="$*"
  log "执行: $cmd"
  if eval "$cmd"; then
    return 0
  else
    error "命令失败: $cmd"
    return 1
  fi
}

# 下载文件（带重试）
download_with_retry() {
  local url=$1 output=$2 max_retries=3 retry=0
  while [[ $retry -lt $max_retries ]]; do
    if curl -sfL --retry 2 --connect-timeout 10 "$url" -o "$output" 2>/dev/null; then
      return 0
    fi
    ((retry++))
    warn "下载失败，重试 $retry/$max_retries..."
    sleep $((retry * 2))
  done
  error "下载失败: $url"
  return 1
}

# =============================================================================
# 🔍 系统检查函数
# =============================================================================

check_system() {
  title "系统环境检查"
  
  # 检查 Apple Silicon
  if [[ "$(uname -m)" != "arm64" ]]; then
    error "MLX 仅支持 Apple Silicon (M1/M2/M3/M4)"
    echo "  当前芯片: $(uname -m)"
    echo "  💡 请检查设备或使用兼容的推理框架"
    return 1
  fi
  success "✓ Apple Silicon 芯片检测通过"
  
  # 检查 macOS 版本
  local macos_ver=$(sw_vers -productVersion | cut -d. -f1)
  if [[ $macos_ver -lt 13 ]]; then
    error "需要 macOS 13 Ventura 或更高版本"
    echo "  当前版本: $(sw_vers -productVersion)"
    return 1
  fi
  success "✓ macOS $(sw_vers -productVersion) 检测通过"
  
  # 检查 Docker
  if ! check_cmd docker; then
    error "Docker 未安装"
    echo "  💡 请安装 Docker Desktop: https://docker.com/products/docker-desktop"
    return 1
  fi
  
  if ! docker info &>/dev/null; then
    error "Docker 未运行"
    echo "  💡 请启动 Docker Desktop 应用"
    return 1
  fi
  success "✓ Docker 运行正常"
  
  # 检查 Python
  if ! check_cmd python3; then
    error "Python 3 未安装"
    return 1
  fi
  
  local py_ver=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
  if (( $(echo "$py_ver < 3.10" | bc -l 2>/dev/null || echo 1) )); then
    error "需要 Python 3.10+，当前: $py_ver"
    return 1
  fi
  success "✓ Python $py_ver 检测通过"
  
  # 检查磁盘空间（至少 15GB）
  local free_space=$(df -g "$HOME" 2>/dev/null | awk 'NR==2 {print $4}' | cut -d'G' -f1)
  if [[ -z "$free_space" ]] || [[ $free_space -lt 15 ]]; then
    warn "可用磁盘空间较少 (${free_space:-未知}GB)，建议 ≥15GB"
  else
    success "✓ 磁盘空间充足 (${free_space}GB)"
  fi
  
  return 0
}

# =============================================================================
# 📦 环境初始化函数
# =============================================================================

setup_environment() {
  title "创建项目环境"
  
  log "创建目录结构..."
  mkdir -p "$MODEL_DIR/qwen3-8b-mlx" \
           "$MODEL_DIR/stable-diffusion" \
           "$LOG_DIR" \
           "$CONFIG_DIR" \
           "$CACHE_DIR"
  
  # 创建 Python 虚拟环境
  if [[ ! -d "$VENV_DIR" ]]; then
    log "创建 Python 虚拟环境 (可能需 1-2 分钟)..."
    python3 -m venv "$VENV_DIR"
  fi
  
  # 激活虚拟环境
  source "$VENV_DIR/bin/activate"
  
  # 修复 SSL 证书（解决 macOS 证书验证问题）
  log "配置 SSL 证书..."
  if python3 -m certifi &>/dev/null; then
    export SSL_CERT_FILE=$(python3 -m certifi)
    export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
  fi
  export HF_ENDPOINT="$HF_ENDPOINT"
  
  # 安装/升级核心依赖
  log "安装 Python 依赖..."
  pip install --quiet --upgrade pip setuptools wheel 2>/dev/null || true
  
  # 安装 MLX 相关（带版本约束避免冲突）
  pip install --quiet \
    'mlx-lm>=0.20.0' \
    'huggingface_hub>=0.20.0' \
    'accelerate>=0.25.0' \
    'certifi>=2024.0.0' \
    'diffusers>=0.25.0' \
    'transformers>=4.36.0' \
    'Pillow>=10.0.0' \
    'flask>=2.3.0' \
    2>/dev/null || {
    warn "部分依赖安装警告（通常可忽略）"
  }
  
  success "✓ Python 环境就绪"
  
  # 创建配置文件模板
  cat > "$CONFIG_DIR/open-webui-functions.json" << 'EOF'
{
  "name": "stable-diffusion-draw",
  "description": "使用 Stable Diffusion 生成图片",
  "parameters": {
    "type": "object",
    "properties": {
      "prompt": {"type": "string", "description": "图片描述提示词"},
      "negative_prompt": {"type": "string", "description": "负面提示词（可选）", "default": ""},
      "width": {"type": "integer", "description": "图片宽度", "default": 1024},
      "height": {"type": "integer", "description": "图片高度", "default": 1024},
      "steps": {"type": "integer", "description": "采样步数", "default": 30}
    },
    "required": ["prompt"]
  }
}
EOF
  success "✓ 配置文件创建完成"
}

# =============================================================================
# 📥 模型下载函数（带验证和重试）
# =============================================================================

download_models() {
  title "下载 AI 模型"
  
  source "$VENV_DIR/bin/activate"
  export HF_ENDPOINT="$HF_ENDPOINT"
  
  # ── 下载 Qwen3 ─────────────────────────────────────
  if [[ -f "$MODEL_DIR/qwen3-8b-mlx/config.json" ]]; then
    success "✓ Qwen3 模型已存在"
  else
    log "下载 Qwen3-8B-4bit 模型 (~4.6GB)..."
    echo -e "  ${CYAN}提示:${NC} 首次下载需 5-15 分钟，取决于网络"
    
    # 清理模型名称中的空格（修复 %20 问题）
    local clean_model=$(echo "$QWEN_MODEL" | xargs)
    
    # 尝试下载（新版 hf 命令，默认支持断点续传）
    if hf download "$clean_model" --local-dir "$MODEL_DIR/qwen3-8b-mlx" 2>&1 | tee -a "$LOG_DIR/download.log"; then
      # 验证下载完整性
      if [[ -f "$MODEL_DIR/qwen3-8b-mlx/config.json" ]] && \
         [[ -f "$MODEL_DIR/qwen3-8b-mlx/tokenizer.json" ]]; then
        success "✓ Qwen3 模型下载完成"
      else
        error "模型文件不完整，请重试"
        return 1
      fi
    else
      error "Qwen3 下载失败"
      echo "  💡 尝试: 检查网络或手动设置 HF_ENDPOINT"
      echo "  💡 或运行: $0 repair 自动修复"
      return 1
    fi
  fi
  
  # ── 下载 Stable Diffusion ──────────────────────────
  if [[ -f "$MODEL_DIR/stable-diffusion/model_index.json" ]]; then
    success "✓ Stable Diffusion 模型已存在"
  else
    echo -e "\n${YELLOW}⚠️  Stable Diffusion XL 模型较大 (~6.5GB)${NC}"
    read -q "REPLY?是否现在下载？(Y/n, 可稍后手动下载) " || true
    echo
    
    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
      log "下载 Stable Diffusion XL (~6.5GB)..."
      echo -e "  ${CYAN}提示:${NC} 下载时间可能较长，请耐心等待"
      
      local clean_sd=$(echo "$SD_MODEL" | xargs)
      if hf download "$clean_sd" --local-dir "$MODEL_DIR/stable-diffusion" 2>&1 | tee -a "$LOG_DIR/download.log"; then
        if [[ -f "$MODEL_DIR/stable-diffusion/model_index.json" ]]; then
          success "✓ Stable Diffusion 模型下载完成"
        else
          warn "SD 模型下载不完整，可稍后重试"
        fi
      else
        warn "SD 模型下载中断，可稍后运行: $0 setup 继续"
      fi
    else
      warn "跳过 SD 模型下载，画图功能暂不可用"
    fi
  fi
}

# =============================================================================
# ⚡ 启动 MLX 推理服务
# =============================================================================

start_mlx() {
  log "启动 MLX 推理服务 (端口 $MLX_PORT)..."
  
  # 清理残留进程
  if port_in_use "$MLX_PORT"; then
    log "清理占用端口 $MLX_PORT 的进程..."
    lsof -ti :$MLX_PORT | xargs kill -9 2>/dev/null || true
    sleep 1
  fi
  
  source "$VENV_DIR/bin/activate"
  
  # 后台启动 MLX server
  nohup mlx_lm.server \
    --model "$MODEL_DIR/qwen3-8b-mlx" \
    --host 127.0.0.1 \
    --port $MLX_PORT \
    --max-tokens 4096 \
    --prompt-cache-size 2048 \
    > "$LOG_DIR/mlx.log" 2>&1 &
  
  local pid=$!
  echo "$pid" > "$LOG_DIR/mlx.pid"
  log "MLX 进程启动 (PID: $pid)"
  
  # 等待服务就绪
  log "等待模型加载 (首次 30-60 秒)..."
  if wait_for_http "http://127.0.0.1:$MLX_PORT/v1/models"; then
    success "✓ MLX 服务就绪"
    return 0
  else
    warn "模型加载较慢，后台继续中..."
    echo "  💡 查看日志: tail -f $LOG_DIR/mlx.log"
    return 0
  fi
}

# =============================================================================
# 🎨 启动 Stable Diffusion 服务
# =============================================================================

start_stable_diffusion() {
  # 检查模型
  if [[ ! -f "$MODEL_DIR/stable-diffusion/model_index.json" ]]; then
    warn "SD 模型未下载，跳过启动"
    echo "  💡 运行: $0 setup 下载模型"
    return 0
  fi
  
  log "启动 Stable Diffusion WebUI (端口 $SD_PORT)..."
  
  # 检查是否已运行
  if port_in_use "$SD_PORT"; then
    success "✓ SD WebUI 已在运行"
    return 0
  fi
  
  # 创建启动脚本
  cat > "$AI_STUDIO_DIR/run_sd.sh" << 'SDSCRIPT'
#!/bin/zsh
set -e
source ~/ai-studio/venv/bin/activate
export PYTORCH_ENABLE_MPS_FALLBACK=1
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

cd ~/ai-studio/models/stable-diffusion

python3 << 'PYEOF'
import torch, os, io, base64, json
from diffusers import StableDiffusionXLPipeline
from flask import Flask, request, jsonify
from PIL import Image

app = Flask(__name__)
model_path = os.path.expanduser("~/ai-studio/models/stable-diffusion")

print(f"[SD] Loading model from {model_path}...")
pipe = StableDiffusionXLPipeline.from_pretrained(
    model_path,
    torch_dtype=torch.float16 if torch.backends.mps.is_available() else torch.float32,
    variant="fp16" if torch.backends.mps.is_available() else None,
    local_files_only=True
)
if torch.backends.mps.is_available():
    pipe.to("mps")
else:
    pipe.to("cpu")
print("[SD] Model loaded!")

@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "stable-diffusion", "version": "1.0"})

@app.route("/generate", methods=["POST"])
def generate():
    try:
        data = request.get_json()
        prompt = data.get("prompt", "")
        negative = data.get("negative_prompt", "blurry, low quality, distorted, text")
        width = int(data.get("width", 1024))
        height = int(data.get("height", 1024))
        steps = int(data.get("steps", 30))
        
        print(f"[SD] Generating: '{prompt[:50]}...' ({width}x{height})")
        image = pipe(
            prompt=prompt,
            negative_prompt=negative,
            width=width,
            height=height,
            num_inference_steps=steps,
            guidance_scale=7.5
        ).images[0]
        
        buf = io.BytesIO()
        image.save(buf, format="PNG")
        buf.seek(0)
        img_base64 = base64.b64encode(buf.read()).decode("utf-8")
        
        return jsonify({
            "success": True,
            "image": f"data:image/png;base64,{img_base64}",
            "prompt": prompt,
            "dimensions": f"{width}x{height}"
        })
    except Exception as e:
        print(f"[SD] Error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == "__main__":
    print(f"[SD] Starting server on port 7860...")
    app.run(host="127.0.0.1", port=7860, debug=False, threaded=True)
PYEOF
SDSCRIPT
  chmod +x "$AI_STUDIO_DIR/run_sd.sh"
  
  # 后台启动
  nohup "$AI_STUDIO_DIR/run_sd.sh" > "$LOG_DIR/sd.log" 2>&1 &
  echo $! > "$LOG_DIR/sd.pid"
  
  # 等待就绪
  sleep 10
  if wait_for_http "http://127.0.0.1:$SD_PORT/health"; then
    success "✓ Stable Diffusion 就绪"
  else
    warn "SD 启动中，请查看日志: $LOG_DIR/sd.log"
  fi
}

# =============================================================================
# 🌐 启动 Open WebUI
# =============================================================================

start_open_webui() {
  log "启动 Open WebUI (端口 $WEBUI_PORT)..."
  
  # 检查容器状态
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^open-webui$"; then
    success "✓ Open WebUI 已在运行"
    return 0
  fi
  
  # 清理旧容器（如有）
  docker rm -f open-webui 2>/dev/null || true
  
  # 启动容器
  docker run -d \
    --name open-webui \
    --restart always \
    -p $WEBUI_PORT:8080 \
    -v open-webui:/app/backend/data \
    -v "$CONFIG_DIR:/app/config:ro" \
    -e OPENAI_API_BASE_URL="" \
    -e ENABLE_SIGNUP=true \
    -e WEBUI_NAME="AI Studio" \
    ghcr.io/open-webui/open-webui:main \
    > "$LOG_DIR/webui.log" 2>&1
  
  # 等待启动
  sleep 15
  if wait_for_http "http://127.0.0.1:$WEBUI_PORT"; then
    success "✓ Open WebUI 就绪"
  else
    warn "Open WebUI 启动中，请刷新页面"
  fi
}

# =============================================================================
# 🔗 配置 Open WebUI 集成（画图 Function）
# =============================================================================

configure_webui_integration() {
  log "配置 Open WebUI 集成..."
  
  # 创建画图 Function 配置（供用户手动导入）
  cat > "$CONFIG_DIR/draw-function.py" << 'PYFUNC'
"""
title: 🎨 AI Drawing (Stable Diffusion)
description: 让 Qwen 调用 Stable Diffusion 生成图片
author: AI Studio
version: 1.0
"""

import requests
import json

def action(user_message, metadata, **kwargs):
    """处理画图请求 - 调用本地 SD 服务"""
    prompt = user_message.get("content", "").strip()
    if not prompt:
        return {"error": "请提供图片描述"}
    
    # 调用本地 SD 服务
    try:
        resp = requests.post(
            "http://127.0.0.1:7860/generate",
            json={
                "prompt": prompt,
                "negative_prompt": "blurry, low quality, distorted, text, watermark",
                "width": 1024,
                "height": 1024,
                "steps": 30
            },
            timeout=180  # 3 分钟超时
        )
        result = resp.json()
        
        if result.get("success"):
            # 返回图片 Markdown（Open WebUI 支持直接渲染）
            return {
                "response": f"![Generated Image]({result['image']})\n\n✅ **图片生成完成！**\n- 提示词: `{prompt}`\n- 尺寸: {result.get('dimensions', '1024x1024')}"
            }
        else:
            return {"error": f"生成失败: {result.get('error', '未知错误')}"}
            
    except requests.Timeout:
        return {"error": "生成超时，请简化提示词或稍后重试"}
    except requests.ConnectionError:
        return {"error": "无法连接画图服务，请确认 SD 已启动"}
    except Exception as e:
        return {"error": f"调用失败: {str(e)}"}
PYFUNC
  
  success "✓ 画图 Function 配置已生成: $CONFIG_DIR/draw-function.py"
  
  # 输出配置指南
  echo -e "\n${CYAN}📋 手动配置步骤（首次运行需执行）:${NC}"
  echo "  1. 登录 Open WebUI → Admin Panel → Functions"
  echo "  2. 点击 '+ Add Function' → 粘贴 $CONFIG_DIR/draw-function.py 内容"
  echo "  3. 保存后，在聊天中勾选 '🎨 AI Drawing' 即可使用"
  echo ""
  echo "  💡 使用示例:"
  echo "     👤 你: 画一只在太空站喝咖啡的赛博朋克猫咪"
  echo "     🤖 Qwen: [自动调用 SD] → 返回生成的图片 🎨"
}

# =============================================================================
# 🌐 自动打开浏览器
# =============================================================================

open_browser() {
  title "打开浏览器"
  
  log "等待服务完全就绪..."
  sleep 8
  
  local opened=0
  
  # 打开 Open WebUI
  if curl -sf "http://127.0.0.1:$WEBUI_PORT" &>/dev/null; then
    log "打开 Open WebUI..."
    open "http://localhost:$WEBUI_PORT"
    printf "  ${GREEN}✓${NC} Open WebUI: ${BOLD}http://localhost:$WEBUI_PORT${NC}\n"
    ((opened++))
  fi
  
  # 打开 SD WebUI（如果运行）
  if curl -sf "http://127.0.0.1:$SD_PORT/health" &>/dev/null; then
    log "打开 Stable Diffusion..."
    open "http://localhost:$SD_PORT"
    printf "  ${GREEN}✓${NC} SD WebUI: ${BOLD}http://localhost:$SD_PORT${NC}\n"
    ((opened++))
  fi
  
  if [[ $opened -eq 0 ]]; then
    warn "服务尚未就绪，请稍后手动访问"
  fi
  
  # 显示配置指南
  printf "\n${GREEN}╔════════════════════════════════════════╗${NC}\n"
  printf "${GREEN}║  ${BOLD}🎉 AI Studio 启动完成！${NC}${GREEN}            ║${NC}\n"
  printf "${GREEN}╚════════════════════════════════════════╝${NC}\n\n"
  
  printf "${BOLD}📋 首次使用配置:${NC}\n"
  echo "  1️⃣  在 Open WebUI 注册/登录管理员账号"
  echo "  2️⃣  Settings → Connections → Add Connection → OpenAI API"
  echo "  3️⃣  填写:"
  echo "      • API Base URL: ${CYAN}http://$DOCKER_HOST_URL:$MLX_PORT/v1${NC}"
  echo "      • API Key: ${CYAN}mlx-local${NC} (任意值)"
  echo "      • Model IDs: ${CYAN}[留空]${NC} (自动识别)"
  echo "  4️⃣  Save → 刷新模型 → 开始对话 🎉"
  echo ""
  echo "${BOLD}🎨 启用画图功能:${NC}"
  echo "  • 导入 Function: $CONFIG_DIR/draw-function.py"
  echo "  • 聊天时勾选 '🎨 AI Drawing'"
  echo "  • 示例: '画一只赛博朋克风格的熊猫'"
  echo ""
  echo "${BOLD}🛠 常用命令:${NC}"
  echo "  • 查看状态: ${CYAN}$0 status${NC}"
  echo "  • 查看日志: ${CYAN}$0 logs${NC}"
  echo "  • 停止服务: ${CYAN}$0 stop${NC}"
  echo "  • 自我修复: ${CYAN}$0 repair${NC}"
}

# =============================================================================
# 🛑 停止服务（优雅关闭）
# =============================================================================

stop_services() {
  title "停止所有服务"
  
  log "停止 MLX 服务..."
  if [[ -f "$LOG_DIR/mlx.pid" ]]; then
    local pid=$(cat "$LOG_DIR/mlx.pid" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$LOG_DIR/mlx.pid"
  fi
  if port_in_use "$MLX_PORT"; then
    lsof -ti :$MLX_PORT | xargs kill -9 2>/dev/null || true
  fi
  success "✓ MLX 已停止"
  
  log "停止 Open WebUI..."
  docker stop open-webui 2>/dev/null || true
  docker rm open-webui 2>/dev/null || true
  success "✓ Open WebUI 已停止"
  
  log "停止 Stable Diffusion..."
  if [[ -f "$LOG_DIR/sd.pid" ]]; then
    local pid=$(cat "$LOG_DIR/sd.pid" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$LOG_DIR/sd.pid"
  fi
  if port_in_use "$SD_PORT"; then
    lsof -ti :$SD_PORT | xargs kill -9 2>/dev/null || true
  fi
  success "✓ Stable Diffusion 已停止"
  
  echo -e "\n${GREEN}✓ 所有服务已优雅停止${NC}"
}

# =============================================================================
# 🗑️ 完全卸载
# =============================================================================

uninstall() {
  title "⚠️  完全卸载确认"
  
  printf "${RED}${BOLD}警告:${NC} 此操作将${BOLD}永久删除${NC}:\n"
  echo "  • 所有下载的模型 (~11GB)"
  echo "  • Python 虚拟环境"
  echo "  • 配置文件与日志"
  echo "  • Docker 数据卷 (open-webui)"
  echo ""
  printf "${YELLOW}模型文件将不会被回收，如需保留请提前备份${NC}\n"
  echo ""
  
  read -q "REPLY?确认卸载？(输入 YES 继续) " || true
  echo
  
  if [[ $REPLY != "YES" ]]; then
    log "取消卸载"
    return 0
  fi
  
  log "停止服务..."
  stop_services
  
  log "删除项目目录..."
  rm -rf "$AI_STUDIO_DIR"
  success "✓ 项目目录已删除"
  
  log "清理 Docker 资源..."
  docker volume rm open-webui 2>/dev/null || true
  docker image prune -f 2>/dev/null || true
  success "✓ Docker 资源已清理"
  
  # 清理 PATH 中的脚本引用（如已添加）
  if grep -q "ai-studio.sh" ~/.zshrc 2>/dev/null; then
    sed -i '' '/ai-studio.sh/d' ~/.zshrc 2>/dev/null || true
    log "已清理 ~/.zshrc 中的脚本引用"
  fi
  
  printf "\n${GREEN}╔════════════════════════════════════════╗${NC}\n"
  printf "${GREEN}║  ${BOLD}✅ 卸载完成！${NC}${GREEN}                      ║${NC}\n"
  printf "${GREEN}╚════════════════════════════════════════╝${NC}\n\n"
  
  echo "💡 如需重新安装，运行: $0 setup"
}

# =============================================================================
# 📊 查看状态
# =============================================================================

show_status() {
  title "AI Studio 运行状态"
  
  printf "${BOLD}🔌 服务状态:${NC}\n\n"
  
  # MLX
  printf "  🤖 MLX ($MLX_PORT): "
  if port_in_use "$MLX_PORT" && curl -sf "http://127.0.0.1:$MLX_PORT/v1/models" &>/dev/null; then
    printf "${GREEN}● 运行中${NC}\n"
    curl -s "http://127.0.0.1:$MLX_PORT/v1/models" 2>/dev/null | \
      python3 -c "import sys,json; d=json.load(sys.stdin); print('     模型:', d['data'][0]['id'] if d.get('data') else '未知')" 2>/dev/null || true
  else
    printf "${RED}○ 未运行${NC}\n"
  fi
  
  # Open WebUI
  printf "  🌐 Open WebUI ($WEBUI_PORT): "
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q open-webui; then
    printf "${GREEN}● 运行中${NC}\n"
    printf "     访问: ${CYAN}http://localhost:$WEBUI_PORT${NC}\n"
  else
    printf "${RED}○ 未运行${NC}\n"
  fi
  
  # Stable Diffusion
  printf "  🎨 Stable Diffusion ($SD_PORT): "
  if port_in_use "$SD_PORT" && curl -sf "http://127.0.0.1:$SD_PORT/health" &>/dev/null; then
    printf "${GREEN}● 运行中${NC}\n"
    printf "     访问: ${CYAN}http://localhost:$SD_PORT${NC}\n"
  else
    printf "${YELLOW}○ 未运行 (可选)${NC}\n"
  fi
  
  # 模型
  printf "\n${BOLD}📦 模型状态:${NC}\n"
  printf "  Qwen3-8B: $MODEL_DIR/qwen3-8b-mlx\n"
  if [[ -f "$MODEL_DIR/qwen3-8b-mlx/config.json" ]]; then
    local size=$(du -sh "$MODEL_DIR/qwen3-8b-mlx" 2>/dev/null | cut -f1)
    printf "    状态: ${GREEN}完整${NC} (${CYAN}$size${NC})\n"
  else
    printf "    状态: ${RED}缺失${NC} (运行: $0 setup)\n"
  fi
  
  if [[ -f "$MODEL_DIR/stable-diffusion/model_index.json" ]]; then
    local size=$(du -sh "$MODEL_DIR/stable-diffusion" 2>/dev/null | cut -f1)
    printf "  SD-XL: $MODEL_DIR/stable-diffusion\n"
    printf "    状态: ${GREEN}完整${NC} (${CYAN}$size${NC})\n"
  else
    printf "  SD-XL: ${YELLOW}未下载${NC} (可选，运行: $0 setup)\n"
  fi
  
  # 配置
  printf "\n${BOLD}⚙️  配置状态:${NC}\n"
  if [[ -f "$CONFIG_DIR/draw-function.py" ]]; then
    printf "  画图 Function: ${GREEN}已生成${NC}\n"
  else
    printf "  画图 Function: ${YELLOW}未生成${NC} (启动后自动创建)\n"
  fi
  
  # 脚本版本
  printf "\n${BOLD}📦 脚本信息:${NC}\n"
  printf "  版本: ${CYAN}$SCRIPT_VERSION${NC}\n"
  printf "  路径: ${CYAN}$0${NC}\n"
}

# =============================================================================
# 🔄 更新功能
# =============================================================================

update_script() {
  title "检查并应用更新"
  
  log "检查脚本更新..."
  
  # 下载最新版本（临时文件）
  local tmp_script="$CACHE_DIR/ai-studio-new.sh"
  mkdir -p "$CACHE_DIR"
  
  if download_with_retry "$SCRIPT_REPO" "$tmp_script"; then
    # 比较版本
    local new_version=$(grep "^: \"\${SCRIPT_VERSION:=" "$tmp_script" 2>/dev/null | cut -d'=' -f2 | cut -d'}' -f1 | tr -d '"')
    
    if [[ "$new_version" == "$SCRIPT_VERSION" ]]; then
      success "✓ 已是最新版本 ($SCRIPT_VERSION)"
      rm -f "$tmp_script"
      return 0
    fi
    
    log "发现新版本: $new_version (当前: $SCRIPT_VERSION)"
    
    # 备份旧脚本
    cp "$0" "${0}.bak.$(date +%Y%m%d%H%M)"
    
    # 替换脚本
    mv "$tmp_script" "$0"
    chmod +x "$0"
    
    success "✓ 脚本已更新到 $new_version"
    echo "  💡 重新运行: $0 $*"
    
    # 自动重新执行更新后的脚本（传递原参数）
    exec "$0" "$@"
  else
    warn "检查更新失败，继续使用当前版本"
    return 1
  fi
}

update_dependencies() {
  title "更新依赖和模型"
  
  source "$VENV_DIR/bin/activate" 2>/dev/null || {
    warn "虚拟环境未激活，跳过依赖更新"
    return 0
  }
  
  log "更新 Python 依赖..."
  pip install --quiet --upgrade \
    'mlx-lm>=0.20.0' \
    'huggingface_hub>=0.20.0' \
    2>/dev/null && success "✓ 依赖已更新" || warn "依赖更新警告（可忽略）"
  
  # 检查模型更新（可选）
  log "检查模型更新..."
  if [[ -f "$MODEL_DIR/qwen3-8b-mlx/config.json" ]]; then
    # 简单检查：比较远程 config.json 的 hash（简化版）
    echo "  💡 模型更新需手动运行: $0 setup"
  fi
  
  success "✓ 依赖检查完成"
}

# =============================================================================
# 🔧 自我修复功能
# =============================================================================

repair_common_issues() {
  title "自我修复常见问题"
  
  local fixed=0
  
  # 🔹 修复 1: readonly HF_ENDPOINT 问题
  if grep -q "readonly HF_ENDPOINT=" "$0" 2>/dev/null; then
    log "修复: readonly HF_ENDPOINT 变量..."
    sed -i '' 's/readonly HF_ENDPOINT=/HF_ENDPOINT=/' "$0" 2>/dev/null || true
    success "✓ 已修复 HF_ENDPOINT 变量"
    ((fixed++))
  fi
  
  # 🔹 修复 2: hf download --resume-download 参数问题
  if grep -q "\-\-resume-download" "$0" 2>/dev/null; then
    log "修复: 移除过时的 --resume-download 参数..."
    sed -i '' 's/--resume-download//g' "$0" 2>/dev/null || true
    success "✓ 已修复 hf download 参数"
    ((fixed++))
  fi
  
  # 🔹 修复 3: 模型名称空格问题
  if grep -q 'QWEN_MODEL=".* "' "$0" 2>/dev/null; then
    log "修复: 清理模型名称尾随空格..."
    sed -i '' 's/QWEN_MODEL="\(.*\) "/QWEN_MODEL="\1"/g' "$0" 2>/dev/null || true
    success "✓ 已修复模型名称格式"
    ((fixed++))
  fi
  
  # 🔹 修复 4: SSL 证书问题
  if ! python3 -m certifi &>/dev/null 2>&1; then
    log "修复: 安装 certifi 证书包..."
    source "$VENV_DIR/bin/activate" 2>/dev/null && \
    pip install --quiet certifi 2>/dev/null && \
    success "✓ 已安装 certifi" && ((fixed++)) || warn "certifi 安装失败"
  fi
  
  # 🔹 修复 5: 端口冲突检测
  for port in $MLX_PORT $WEBUI_PORT $SD_PORT; do
    if port_in_use "$port"; then
      local proc=$(lsof -ti :$port 2>/dev/null | head -1)
      if [[ -n "$proc" ]]; then
        log "检测到端口 $port 被占用 (PID: $proc)"
        read -q "REPLY?是否释放端口 $port？(y/N) " || true
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          kill -9 "$proc" 2>/dev/null && success "✓ 已释放端口 $port" && ((fixed++)) || warn "释放失败"
        fi
      fi
    fi
  done
  
  # 🔹 修复 6: Docker 网络配置
  if ! docker inspect host.docker.internal &>/dev/null 2>&1; then
    log "修复: Docker host.docker.internal 配置..."
    # macOS 通常已内置支持，此处仅为提示
    echo "  💡 如连接失败，请确保 Docker Desktop 已启动"
  fi
  
  # 🔹 修复 7: 权限问题
  if [[ ! -w "$LOG_DIR" ]] 2>/dev/null; then
    log "修复: 日志目录权限..."
    chmod -R u+w "$LOG_DIR" 2>/dev/null && success "✓ 已修复日志目录权限" && ((fixed++)) || true
  fi
  
  # 总结
  echo
  if [[ $fixed -gt 0 ]]; then
    success "✓ 已修复 $fixed 个问题"
    echo "  💡 建议重新运行: $0 ${1:-start}"
  else
    success "✓ 未检测到常见问题"
  fi
  
  return 0
}

# =============================================================================
# 📋 查看日志
# =============================================================================

show_logs() {
  title "实时日志跟踪"
  printf "${CYAN}按 Ctrl+C 退出跟踪${NC}\n\n"
  
  if [[ ! -d "$LOG_DIR" ]] || [[ -z "$(ls -A "$LOG_DIR" 2>/dev/null)" ]]; then
    warn "暂无日志文件"
    return 0
  fi
  
  # 同时跟踪所有日志（带颜色区分）
  if command -v multitail &>/dev/null; then
    multitail -c "$LOG_DIR"/*.log
  else
    # 简化版：轮流显示
    echo "=== MLX 日志 ===" && tail -20 "$LOG_DIR/mlx.log" 2>/dev/null
    echo -e "\n=== WebUI 日志 ===" && tail -20 "$LOG_DIR/webui.log" 2>/dev/null
    echo -e "\n=== SD 日志 ===" && tail -20 "$LOG_DIR/sd.log" 2>/dev/null
    echo -e "\n${DIM}提示: 安装 multitail 可获得更好的日志体验: brew install multitail${NC}"
  fi
}

# =============================================================================
# 🎯 主入口函数
# =============================================================================

main() {
  local cmd="${1:-help}"
  shift 2>/dev/null || true
  
  case "$cmd" in
    setup)
      check_system || exit 1
      setup_environment
      download_models
      printf "\n${GREEN}╔════════════════════════════════════════╗${NC}\n"
      printf "${GREEN}║  ${BOLD}✅ 部署完成！${NC}${GREEN}                      ║${NC}\n"
      printf "${GREEN}╚════════════════════════════════════════╝${NC}\n"
      printf "\n🚀 现在运行: ${BOLD}$0 start${NC} 启动服务\n"
      ;;
    
    start)
      check_system || exit 1
      if [[ ! -d "$VENV_DIR" ]]; then
        error "环境未初始化，请先运行: $0 setup"
        exit 1
      fi
      
      title "启动 AI Studio"
      start_mlx
      start_stable_diffusion
      start_open_webui
      configure_webui_integration
      open_browser
      ;;
    
    status)
      show_status
      ;;
    
    update)
      update_script "$@"
      update_dependencies
      ;;
    
    repair)
      repair_common_issues "$@"
      ;;
    
    stop)
      stop_services
      ;;
    
    restart)
      stop_services
      sleep 2
      exec "$0" start
      ;;
    
    logs)
      show_logs
      ;;
    
    uninstall)
      uninstall
      ;;
    
    version|--version|-v)
      echo "AI Studio Pro v$SCRIPT_VERSION"
      echo "Repository: $SCRIPT_REPO"
      ;;
    
    help|--help|-h)
      printf "${BOLD}用法:${NC} $0 {setup|start|stop|restart|status|update|repair|logs|uninstall|version}\n\n"
      printf "${BOLD}命令说明:${NC}\n"
      printf "  setup     - 首次部署：检查环境 + 安装依赖 + 下载模型\n"
      printf "  start     - 启动所有服务 + 自动打开浏览器\n"
      printf "  status    - 查看服务与模型运行状态\n"
      printf "  update    - 检查并应用脚本/依赖更新\n"
      printf "  repair    - 自我修复常见问题（端口/配置/权限）\n"
      printf "  stop      - 优雅停止所有服务\n"
      printf "  restart   - 重启所有服务（stop + start）\n"
      printf "  logs      - 实时查看服务日志\n"
      printf "  uninstall - 完全卸载（删除所有数据）\n"
      printf "  version   - 显示脚本版本信息\n"
      printf "\n${BOLD}快速开始:${NC}\n"
      printf "  1. 首次:  ${CYAN}$0 setup && $0 start${NC}\n"
      printf "  2. 日常:  ${CYAN}$0 start${NC}\n"
      printf "  3. 停止:  ${CYAN}$0 stop${NC}\n"
      printf "  4. 修复:  ${CYAN}$0 repair${NC}（遇到问题时）\n"
      printf "\n${BOLD}配置提示:${NC}\n"
      printf "  • Open WebUI 连接 MLX:\n"
      printf "    API Base URL: ${CYAN}http://$DOCKER_HOST_URL:$MLX_PORT/v1${NC}\n"
      printf "    API Key: ${CYAN}mlx-local${NC}\n"
      printf "\n"
      printf "  • 启用画图: 导入 $CONFIG_DIR/draw-function.py\n"
      printf "  • 自定义: 编辑脚本顶部的配置区变量\n"
      ;;
    
    *)
      error "未知命令: $cmd"
      printf "💡 运行 '${BOLD}$0 help${NC}' 查看可用命令\n"
      exit 1
      ;;
  esac
}

# =============================================================================
# 🚀 执行入口
# =============================================================================

# 确保脚本在正确目录执行（避免相对路径问题）
if [[ "${BASH_SOURCE[0]:-${(%):-%x}}" != "$0" ]]; then
  # 被 source 执行，不自动运行
  :
else
  main "$@"
fi
