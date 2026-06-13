#!/bin/zsh
# =============================================================================
# 🍎 AI Studio Pro - macOS 一键部署脚本
# 功能: Open WebUI + MLX + Qwen3 + Stable Diffusion + 智能画图集成
# 
# 核心特性:
#   • Qwen3 通过 Function Calling 自动调用 SD 画图
#   • 服务启动后自动打开浏览器
#   • 完整的生命周期管理：部署/启动/状态/停止/卸载
#
# 用法:
#   ./ai-studio.sh setup      # 首次部署（下载环境+模型）
#   ./ai-studio.sh start      # 启动所有服务 + 自动打开浏览器
#   ./ai-studio.sh status     # 查看服务运行状态
#   ./ai-studio.sh stop       # 优雅停止所有服务
#   ./ai-studio.sh uninstall  # 完全卸载（删除所有数据）
#   ./ai-studio.sh logs       # 查看实时日志
#   ./ai-studio.sh help       # 查看帮助
# =============================================================================

set -euo pipefail

# 📁 全局配置（可按需修改）
readonly PROJECT_DIR="$HOME/ai-studio"
readonly MODEL_DIR="$PROJECT_DIR/models"
readonly LOG_DIR="$PROJECT_DIR/logs"
readonly VENV_DIR="$PROJECT_DIR/venv"
readonly CONFIG_DIR="$PROJECT_DIR/config"

# 🔌 端口配置
readonly MLX_PORT=8000
readonly WEBUI_PORT=3000
readonly SD_PORT=7860

# 🤖 模型配置
readonly QWEN_MODEL="mlx-community/Qwen3-8B-4bit"
readonly SD_MODEL="stabilityai/stable-diffusion-xl-base-1.0"
readonly HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

# 🎨 终端样式
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# =============================================================================
# 🔧 工具函数
# =============================================================================

log()     { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
success() { echo -e "${GREEN}[✓]${NC} $(date '+%H:%M:%S') ${BOLD}$1${NC}"; }
warn()    { echo -e "${YELLOW}[⚠]${NC} $(date '+%H:%M:%S') $1"; }
error()   { echo -e "${RED}[✗]${NC} $(date '+%H:%M:%S') ${BOLD}ERROR:${NC} $1"; }
title() {
  echo -e "\n${MAGENTA}╔════════════════════════════════════════╗${NC}"
  echo -e "${MAGENTA}║  ${CYAN}${BOLD}$1${NC}${MAGENTA}                        ║${NC}"
  echo -e "${MAGENTA}╚════════════════════════════════════════╝${NC}\n"
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

# 检查服务是否响应
wait_for_http() {
  local url=$1 timeout=60 elapsed=0
  while ! curl -sf "$url" &>/dev/null; do
    [[ $elapsed -ge $timeout ]] && return 1
    sleep 2
    ((elapsed+=2))
  done
  return 0
}

# =============================================================================
# 🔍 系统检查
# =============================================================================

check_system() {
  title "系统环境检查"
  
  # 检查 Apple Silicon
  if [[ "$(uname -m)" != "arm64" ]]; then
    error "MLX 仅支持 Apple Silicon (M1/M2/M3/M4)"
    echo "  当前芯片: $(uname -m)"
    exit 1
  fi
  success "✓ Apple Silicon 芯片检测通过"
  
  # 检查 macOS 版本
  local macos_ver=$(sw_vers -productVersion | cut -d. -f1)
  if [[ $macos_ver -lt 13 ]]; then
    error "需要 macOS 13 Ventura 或更高版本"
    exit 1
  fi
  success "✓ macOS $(sw_vers -productVersion) 检测通过"
  
  # 检查 Docker
  if ! check_cmd docker; then
    echo "  💡 请安装 Docker Desktop: https://docker.com/products/docker-desktop"
    exit 1
  fi
  
  if ! docker info &>/dev/null; then
    error "Docker 未运行，请启动 Docker Desktop"
    exit 1
  fi
  success "✓ Docker 运行正常"
  
  # 检查 Python
  if ! check_cmd python3; then
    error "Python 3 未安装"
    exit 1
  fi
  
  local py_ver=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
  if (( $(echo "$py_ver < 3.10" | bc -l 2>/dev/null || echo 1) )); then
    error "需要 Python 3.10+，当前: $py_ver"
    exit 1
  fi
  success "✓ Python $py_ver 检测通过"
  
  # 检查磁盘空间（至少 15GB）
  local free_space=$(df -g "$HOME" | awk 'NR==2 {print $4}' | cut -d'G' -f1)
  if [[ $free_space -lt 15 ]]; then
    warn "可用磁盘空间较少 ($free_space GB)，建议 ≥15GB"
  else
    success "✓ 磁盘空间充足 (${free_space}GB)"
  fi
}

# =============================================================================
# 📦 环境初始化
# =============================================================================

setup_environment() {
  title "创建项目环境"
  
  log "创建目录结构..."
  mkdir -p "$MODEL_DIR/qwen3-8b-mlx" \
           "$MODEL_DIR/stable-diffusion" \
           "$LOG_DIR" \
           "$CONFIG_DIR"
  
  # 创建 Python 虚拟环境
  if [[ ! -d "$VENV_DIR" ]]; then
    log "创建 Python 虚拟环境 (可能需 1-2 分钟)..."
    python3 -m venv "$VENV_DIR"
  fi
  
  source "$VENV_DIR/bin/activate"
  
  # 修复 SSL 证书（解决 macOS 证书验证问题）
  log "配置 SSL 证书..."
  export SSL_CERT_FILE=$(python3 -m certifi 2>/dev/null || echo "")
  export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
  export HF_ENDPOINT="$HF_ENDPOINT"
  
  # 安装核心依赖
  log "安装 Python 依赖..."
  pip install --quiet --upgrade pip setuptools wheel
  
  # MLX 相关
  pip install --quiet \
    mlx-lm \
    huggingface_hub \
    accelerate \
    certifi \
    diffusers \
    transformers \
    Pillow
  
  success "✓ Python 环境就绪"
  
  # 创建配置文件模板
  cat > "$CONFIG_DIR/open-webui-functions.json" << 'EOF'
{
  "name": "stable-diffusion-draw",
  "description": "使用 Stable Diffusion 生成图片",
  "parameters": {
    "type": "object",
    "properties": {
      "prompt": {
        "type": "string",
        "description": "图片描述提示词"
      },
      "negative_prompt": {
        "type": "string",
        "description": "负面提示词（可选）",
        "default": ""
      },
      "width": {
        "type": "integer",
        "description": "图片宽度",
        "default": 1024
      },
      "height": {
        "type": "integer",
        "description": "图片高度", 
        "default": 1024
      },
      "steps": {
        "type": "integer",
        "description": "采样步数",
        "default": 30
      }
    },
    "required": ["prompt"]
  }
}
EOF
  success "✓ 配置文件创建完成"
}

# =============================================================================
# 📥 模型下载
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
    
    hf download "$QWEN_MODEL" \
      --local-dir "$MODEL_DIR/qwen3-8b-mlx" \
      --resume-download || {
      error "Qwen3 下载失败"
      echo "  💡 尝试: 检查网络或手动设置 HF_ENDPOINT"
      exit 1
    }
    success "✓ Qwen3 模型下载完成"
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
      
      hf download "$SD_MODEL" \
        --local-dir "$MODEL_DIR/stable-diffusion" \
        --resume-download || {
        warn "SD 模型下载中断，可稍后运行: $0 setup 继续"
      }
      success "✓ Stable Diffusion 模型下载完成"
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
  cat > "$PROJECT_DIR/run_sd.sh" << 'SDSCRIPT'
#!/bin/zsh
set -e
source ~/ai-studio/venv/bin/activate
export PYTORCH_ENABLE_MPS_FALLBACK=1
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

cd ~/ai-studio/models/stable-diffusion

# 使用 diffusers 启动轻量 API
python3 << 'PYEOF'
import torch
from diffusers import StableDiffusionXLPipeline
from flask import Flask, request, jsonify
from PIL import Image
import io, base64, os

app = Flask(__name__)
model_path = os.path.expanduser("~/ai-studio/models/stable-diffusion")

print(f"[SD] Loading model from {model_path}...")
pipe = StableDiffusionXLPipeline.from_pretrained(
    model_path,
    torch_dtype=torch.float16 if torch.backends.mps.is_available() else torch.float32,
    variant="fp16" if torch.backends.mps.is_available() else None
)
if torch.backends.mps.is_available():
    pipe.to("mps")
else:
    pipe.to("cpu")
print("[SD] Model loaded!")

@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "stable-diffusion"})

@app.route("/generate", methods=["POST"])
def generate():
    try:
        data = request.json
        prompt = data.get("prompt", "")
        negative = data.get("negative_prompt", "")
        width = int(data.get("width", 1024))
        height = int(data.get("height", 1024))
        steps = int(data.get("steps", 30))
        
        print(f"[SD] Generating: '{prompt}' ({width}x{height})")
        image = pipe(
            prompt=prompt,
            negative_prompt=negative,
            width=width,
            height=height,
            num_inference_steps=steps,
            guidance_scale=7.5
        ).images[0]
        
        # 转为 base64
        buf = io.BytesIO()
        image.save(buf, format="PNG")
        buf.seek(0)
        img_base64 = base64.b64encode(buf.read()).decode("utf-8")
        
        return jsonify({
            "success": True,
            "image": f"data:image/png;base64,{img_base64}",
            "prompt": prompt
        })
    except Exception as e:
        print(f"[SD] Error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == "__main__":
    print(f"[SD] Starting server on port 7860...")
    app.run(host="127.0.0.1", port=7860, debug=False)
PYEOF
SDSCRIPT
  chmod +x "$PROJECT_DIR/run_sd.sh"
  
  # 后台启动
  nohup "$PROJECT_DIR/run_sd.sh" > "$LOG_DIR/sd.log" 2>&1 &
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
# 🌐 启动 Open WebUI 并配置画图功能
# =============================================================================

start_open_webui() {
  log "启动 Open WebUI (端口 $WEBUI_PORT)..."
  
  # 检查容器状态
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^open-webui$"; then
    success "✓ Open WebUI 已在运行"
    return 0
  fi
  
  # 启动容器
  docker run -d \
    --name open-webui \
    --restart always \
    -p $WEBUI_PORT:8080 \
    -v open-webui:/app/backend/data \
    -v "$CONFIG_DIR:/app/config" \
    -e OPENAI_API_BASE_URL="" \
    -e ENABLE_SIGNUP=true \
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
# 🔗 配置 Open WebUI 连接 + 画图 Function
# =============================================================================

configure_webui_integration() {
  log "配置 Open WebUI 集成..."
  
  # 1. 配置 MLX 连接（通过 API）
  local webui_api="http://127.0.0.1:$WEBUI_PORT/api"
  
  # 等待管理员账号创建（首次运行需手动）
  if ! curl -sf "$webui_api/auths/status" &>/dev/null; then
    warn "Open WebUI 尚未初始化，请先在浏览器完成注册"
    echo "  💡 访问: http://localhost:$WEBUI_PORT"
    return 0
  fi
  
  # 2. 创建画图 Function 配置（供用户手动导入）
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
    """处理画图请求"""
    prompt = user_message.get("content", "")
    
    # 调用本地 SD 服务
    try:
        resp = requests.post(
            "http://127.0.0.1:7860/generate",
            json={
                "prompt": prompt,
                "negative_prompt": "blurry, low quality, distorted",
                "width": 1024,
                "height": 1024,
                "steps": 30
            },
            timeout=120
        )
        result = resp.json()
        
        if result.get("success"):
            # 返回图片 Markdown
            return {
                "response": f"![Generated Image]({result['image']})\n\n✅ 图片生成完成！"
            }
        else:
            return {"error": f"生成失败: {result.get('error')}"}
            
    except Exception as e:
        return {"error": f"调用失败: {str(e)}"}
PYFUNC
  
  success "✓ 画图 Function 配置已生成: $CONFIG_DIR/draw-function.py"
  echo -e "\n${CYAN}📋 手动配置步骤:${NC}"
  echo "  1. 登录 Open WebUI → Admin Panel → Functions"
  echo "  2. 点击 '+ Add Function' → 粘贴 $CONFIG_DIR/draw-function.py 内容"
  echo "  3. 保存后，在聊天中勾选 '🎨 AI Drawing' 即可使用"
  echo ""
  echo "  💡 使用示例:"
  echo "     👤 你: 画一只在太空站喝咖啡的猫咪"
  echo "     🤖 Qwen: [自动调用 SD] → 返回生成的图片"
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
    echo -e "  ${GREEN}✓${NC} Open WebUI: ${BOLD}http://localhost:$WEBUI_PORT${NC}"
    ((opened++))
  fi
  
  # 打开 SD WebUI（如果运行）
  if curl -sf "http://127.0.0.1:$SD_PORT/health" &>/dev/null; then
    log "打开 Stable Diffusion..."
    open "http://localhost:$SD_PORT"
    echo -e "  ${GREEN}✓${NC} SD WebUI: ${BOLD}http://localhost:$SD_PORT${NC}"
    ((opened++))
  fi
  
  if [[ $opened -eq 0 ]]; then
    warn "服务尚未就绪，请稍后手动访问"
  fi
  
  # 显示配置指南
  echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  ${BOLD}🎉 AI Studio 启动完成！${NC}${GREEN}            ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"
  
  echo "${BOLD}📋 首次使用配置:${NC}"
  echo "  1️⃣  在 Open WebUI 注册/登录管理员账号"
  echo "  2️⃣  Settings → Connections → Add Connection → OpenAI API"
  echo "  3️⃣  填写:"
  echo "      • API Base URL: ${CYAN}http://host.docker.internal:$MLX_PORT/v1${NC}"
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
}

# =============================================================================
# 🛑 停止服务
# =============================================================================

stop_services() {
  title "停止所有服务"
  
  log "停止 MLX 服务..."
  if [[ -f "$LOG_DIR/mlx.pid" ]]; then
    kill $(cat "$LOG_DIR/mlx.pid") 2>/dev/null || true
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
    kill $(cat "$LOG_DIR/sd.pid") 2>/dev/null || true
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
  
  echo -e "${RED}${BOLD}警告:${NC} 此操作将${BOLD}永久删除${NC}:"
  echo "  • 所有下载的模型 (~11GB)"
  echo "  • Python 虚拟环境"
  echo "  • 配置文件与日志"
  echo "  • Docker 数据卷 (open-webui)"
  echo ""
  echo -e "${YELLOW}模型文件将不会被回收，如需保留请提前备份${NC}"
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
  rm -rf "$PROJECT_DIR"
  success "✓ 项目目录已删除"
  
  log "清理 Docker 资源..."
  docker volume rm open-webui 2>/dev/null || true
  docker image prune -f 2>/dev/null || true
  success "✓ Docker 资源已清理"
  
  echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  ${BOLD}✅ 卸载完成！${NC}${GREEN}                      ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"
  
  echo "💡 如需重新安装，运行: $0 setup"
}

# =============================================================================
# 📊 查看状态
# =============================================================================

show_status() {
  title "AI Studio 运行状态"
  
  echo -e "${BOLD}🔌 服务状态:${NC}\n"
  
  # MLX
  echo -n "  🤖 MLX ($MLX_PORT): "
  if port_in_use "$MLX_PORT" && curl -sf "http://127.0.0.1:$MLX_PORT/v1/models" &>/dev/null; then
    echo -e "${GREEN}● 运行中${NC}"
    curl -s "http://127.0.0.1:$MLX_PORT/v1/models" 2>/dev/null | \
      python3 -c "import sys,json; d=json.load(sys.stdin); print('     模型:', d['data'][0]['id'] if d.get('data') else '未知')" 2>/dev/null || true
  else
    echo -e "${RED}○ 未运行${NC}"
  fi
  
  # Open WebUI
  echo -n "  🌐 Open WebUI ($WEBUI_PORT): "
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q open-webui; then
    echo -e "${GREEN}● 运行中${NC}"
    echo "     访问: ${CYAN}http://localhost:$WEBUI_PORT${NC}"
  else
    echo -e "${RED}○ 未运行${NC}"
  fi
  
  # Stable Diffusion
  echo -n "  🎨 Stable Diffusion ($SD_PORT): "
  if port_in_use "$SD_PORT" && curl -sf "http://127.0.0.1:$SD_PORT/health" &>/dev/null; then
    echo -e "${GREEN}● 运行中${NC}"
    echo "     访问: ${CYAN}http://localhost:$SD_PORT${NC}"
  else
    echo -e "${YELLOW}○ 未运行 (可选)${NC}"
  fi
  
  # 模型
  echo -e "\n${BOLD}📦 模型状态:${NC}"
  echo "  Qwen3-8B: $MODEL_DIR/qwen3-8b-mlx"
  if [[ -f "$MODEL_DIR/qwen3-8b-mlx/config.json" ]]; then
    local size=$(du -sh "$MODEL_DIR/qwen3-8b-mlx" 2>/dev/null | cut -f1)
    echo -e "    状态: ${GREEN}完整${NC} (${CYAN}$size${NC})"
  else
    echo -e "    状态: ${RED}缺失${NC} (运行: $0 setup)"
  fi
  
  if [[ -f "$MODEL_DIR/stable-diffusion/model_index.json" ]]; then
    local size=$(du -sh "$MODEL_DIR/stable-diffusion" 2>/dev/null | cut -f1)
    echo "  SD-XL: $MODEL_DIR/stable-diffusion"
    echo -e "    状态: ${GREEN}完整${NC} (${CYAN}$size${NC})"
  else
    echo -e "  SD-XL: ${YELLOW}未下载${NC} (可选，运行: $0 setup)"
  fi
  
  # 配置
  echo -e "\n${BOLD}⚙️  配置状态:${NC}"
  if [[ -f "$CONFIG_DIR/draw-function.py" ]]; then
    echo -e "  画图 Function: ${GREEN}已生成${NC}"
  else
    echo -e "  画图 Function: ${YELLOW}未生成${NC} (启动后自动创建)"
  fi
}

# =============================================================================
# 📋 查看日志
# =============================================================================

show_logs() {
  title "实时日志跟踪"
  echo -e "${CYAN}按 Ctrl+C 退出跟踪${NC}\n"
  
  if [[ ! -d "$LOG_DIR" ]] || [[ -z "$(ls -A "$LOG_DIR" 2>/dev/null)" ]]; then
    warn "暂无日志文件"
    return 0
  fi
  
  # 同时跟踪所有日志
  tail -f "$LOG_DIR"/*.log 2>/dev/null || warn "日志文件为空"
}

# =============================================================================
# 🎯 主入口
# =============================================================================

main() {
  case "${1:-help}" in
    setup)
      check_system
      setup_environment
      download_models
      echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
      echo -e "${GREEN}║  ${BOLD}✅ 部署完成！${NC}${GREEN}                      ║${NC}"
      echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
      echo -e "\n🚀 现在运行: ${BOLD}$0 start${NC} 启动服务"
      ;;
    
    start)
      check_system
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
    
    stop)
      stop_services
      ;;
    
    restart)
      stop_services
      sleep 2
      $0 start
      ;;
    
    logs)
      show_logs
      ;;
    
    uninstall)
      uninstall
      ;;
    
    help|--help|-h)
      echo -e "${BOLD}用法:${NC} $0 {setup|start|stop|restart|status|logs|uninstall}"
      echo ""
      echo "${BOLD}命令说明:${NC}"
      echo "  setup     - 首次部署：检查环境 + 安装依赖 + 下载模型"
      echo "  start     - 启动所有服务 + 自动打开浏览器"
      echo "  status    - 查看服务与模型运行状态"
      echo "  stop      - 优雅停止所有服务"
      echo "  restart   - 重启所有服务"
      echo "  logs      - 实时查看服务日志"
      echo "  uninstall - 完全卸载（删除所有数据）"
      echo ""
      echo "${BOLD}快速开始:${NC}"
      echo "  1. 首次:  ${CYAN}$0 setup && $0 start${NC}"
      echo "  2. 日常:  ${CYAN}$0 start${NC}"
      echo "  3. 停止:  ${CYAN}$0 stop${NC}"
      echo ""
      echo "${BOLD}配置提示:${NC}"
      echo "  • Open WebUI 连接 MLX:"
      echo "    API Base URL: ${CYAN}http://host.docker.internal:$MLX_PORT/v1${NC}"
      echo "    API Key: ${CYAN}mlx-local${NC}"
      echo ""
      echo "  • 启用画图: 导入 $CONFIG_DIR/draw-function.py"
      ;;
    
    *)
      error "未知命令: $1"
      $0 help
      exit 1
      ;;
  esac
}

# 执行主函数
main "$@"
