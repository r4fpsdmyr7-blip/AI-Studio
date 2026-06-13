#!/bin/zsh
# =============================================================================
# 🍎 macOS AI Studio - 一键部署脚本
# 功能: Open WebUI + MLX + Qwen3 + Stable Diffusion
# 用法: 
#   ./ai-studio-setup.sh setup     # 首次安装
#   ./ai-studio-setup.sh start     # 启动所有服务 + 自动打开浏览器
#   ./ai-studio-setup.sh stop      # 停止所有服务
#   ./ai-studio-setup.sh status    # 查看状态
#   ./ai-studio-setup.sh chat      # 仅启动对话服务
#   ./ai-studio-setup.sh draw      # 仅启动画图服务
# =============================================================================

set -e

# 📁 全局配置
PROJECT_DIR="$HOME/ai-studio"
MODEL_DIR="$PROJECT_DIR/models"
LOG_DIR="$PROJECT_DIR/logs"
VENV_DIR="$PROJECT_DIR/venv"

# 端口配置
MLX_PORT=8000
WEBUI_PORT=3000
SD_PORT=7860

# 模型配置
QWEN_MODEL="mlx-community/Qwen3-8B-4bit"
SD_MODEL="stabilityai/stable-diffusion-xl-base-1.0"
HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

# 🎨 样式
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; NC='\033[0m'

log()     { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
success() { echo -e "${GREEN}[✓]${NC} $(date '+%H:%M:%S') $1"; }
warn()    { echo -e "${YELLOW}[⚠]${NC} $(date '+%H:%M:%S') $1"; }
error()   { echo -e "${RED}[✗]${NC} $(date '+%H:%M:%S') $1"; }
title()   { echo -e "\n${MAGENTA}═══════════════════════════════════════${NC}"; 
            echo -e "${MAGENTA}  $1${NC}"; 
            echo -e "${MAGENTA}═══════════════════════════════════════${NC}\n"; }

# =============================================================================
# 🔧 核心函数
# =============================================================================

check_requirements() {
  title "系统检查"
  
  # 检查 Apple Silicon
  if [[ "$(uname -m)" != "arm64" ]]; then
    error "MLX 仅支持 Apple Silicon (M1/M2/M3/M4)"
    exit 1
  fi
  success "✓ Apple Silicon 芯片检测通过"
  
  # 检查 Docker
  if ! command -v docker &>/dev/null; then
    error "Docker 未安装。请访问: https://docker.com/products/docker-desktop"
    exit 1
  fi
  
  if ! docker info &>/dev/null; then
    error "Docker 未运行。请启动 Docker Desktop"
    exit 1
  fi
  success "✓ Docker 运行正常"
  
  # 检查 Python 3.10+
  if ! command -v python3 &>/dev/null; then
    error "Python3 未安装"
    exit 1
  fi
  
  local py_version=$(python3 --version | awk '{print $2}' | cut -d. -f1,2)
  if (( $(echo "$py_version < 3.10" | bc -l) )); then
    error "需要 Python 3.10+，当前: $py_version"
    exit 1
  fi
  success "✓ Python $py_version 检测通过"
}

setup_environment() {
  title "创建环境"
  
  log "创建项目目录..."
  mkdir -p "$MODEL_DIR/qwen3-8b-mlx" "$MODEL_DIR/stable-diffusion" "$LOG_DIR"
  
  # 创建 Python 虚拟环境
  if [[ ! -d "$VENV_DIR" ]]; then
    log "创建 Python 虚拟环境..."
    python3 -m venv "$VENV_DIR"
  fi
  
  source "$VENV_DIR/bin/activate"
  
  # 修复 SSL 证书
  export SSL_CERT_FILE=$(python3 -m certifi 2>/dev/null || echo "")
  export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
  export HF_ENDPOINT="$HF_ENDPOINT"
  
  log "安装 MLX 依赖..."
  pip install --quiet --upgrade pip setuptools wheel
  pip install --quiet mlx-lm huggingface_hub accelerate certifi
  
  success "✓ Python 环境就绪"
}

download_models() {
  title "下载模型"
  
  source "$VENV_DIR/bin/activate"
  export HF_ENDPOINT="$HF_ENDPOINT"
  
  # 下载 Qwen3
  if [[ ! -f "$MODEL_DIR/qwen3-8b-mlx/config.json" ]]; then
    log "下载 Qwen3-8B-4bit 模型 (约 4.6GB)..."
    hf download "$QWEN_MODEL" --local-dir "$MODEL_DIR/qwen3-8b-mlx" || {
      error "Qwen3 下载失败"
      exit 1
    }
    success "✓ Qwen3 模型下载完成"
  else
    success "✓ Qwen3 模型已存在"
  fi
  
  # 下载 Stable Diffusion (可选)
  if [[ ! -f "$MODEL_DIR/stable-diffusion/model_index.json" ]]; then
    log "下载 Stable Diffusion XL (约 6.5GB，可跳过)..."
    read -q "REPLY?是否下载 Stable Diffusion 模型？(Y/n) "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      hf download "$SD_MODEL" --local-dir "$MODEL_DIR/stable-diffusion" || {
        warn "SD 模型下载失败，可稍后手动下载"
      }
    fi
  else
    success "✓ Stable Diffusion 模型已存在"
  fi
}

start_mlx() {
  log "启动 MLX 推理服务 (端口 $MLX_PORT)..."
  
  # 清理残留
  if lsof -ti :$MLX_PORT &>/dev/null; then
    lsof -ti :$MLX_PORT | xargs kill -9 2>/dev/null
    sleep 1
  fi
  
  source "$VENV_DIR/bin/activate"
  nohup mlx_lm.server \
    --model "$MODEL_DIR/qwen3-8b-mlx" \
    --host 127.0.0.1 \
    --port $MLX_PORT \
    --max-tokens 4096 \
    > "$LOG_DIR/mlx.log" 2>&1 &
  
  echo $! > "$LOG_DIR/mlx.pid"
  
  # 等待加载
  log "等待模型加载 (30-60秒)..."
  local count=0
  while ! curl -s "http://127.0.0.1:$MLX_PORT/v1/models" &>/dev/null; do
    sleep 2
    ((count++))
    if [[ $count -gt 30 ]]; then
      warn "模型加载较慢，后台继续中..."
      break
    fi
  done
  
  if curl -s "http://127.0.0.1:$MLX_PORT/v1/models" | grep -q "model"; then
    success "✓ MLX 服务就绪"
  fi
}

start_webui() {
  log "启动 Open WebUI (端口 $WEBUI_PORT)..."
  
  if docker ps --format '{{.Names}}' | grep -q "^open-webui$"; then
    success "✓ Open WebUI 已在运行"
    return 0
  fi
  
  docker run -d \
    --name open-webui \
    --restart always \
    -p $WEBUI_PORT:8080 \
    -v open-webui:/app/backend/data \
    -e OPENAI_API_BASE_URL="" \
    ghcr.io/open-webui/open-webui:main \
    > "$LOG_DIR/webui.log" 2>&1
  
  # 等待启动
  sleep 10
  if curl -s "http://127.0.0.1:$WEBUI_PORT" &>/dev/null; then
    success "✓ Open WebUI 就绪"
  else
    warn "Open WebUI 启动中，请稍后刷新页面"
  fi
}

start_stable_diffusion() {
  log "启动 Stable Diffusion WebUI (端口 $SD_PORT)..."
  
  # 检查模型
  if [[ ! -f "$MODEL_DIR/stable-diffusion/model_index.json" ]]; then
    warn "SD 模型未下载，跳过启动"
    return 0
  fi
  
  # 检查是否已运行
  if lsof -ti :$SD_PORT &>/dev/null; then
    success "✓ SD WebUI 已在运行"
    return 0
  fi
  
  # 创建启动脚本
  cat > "$PROJECT_DIR/run_sd.sh" << 'SDSCRIPT'
#!/bin/zsh
source ~/ai-studio/venv/bin/activate
cd ~/ai-studio/models/stable-diffusion
python3 -m diffusers launch --model_path . --port 7860 --share=False
SDSCRIPT
  chmod +x "$PROJECT_DIR/run_sd.sh"
  
  # 后台启动
  nohup "$PROJECT_DIR/run_sd.sh" > "$LOG_DIR/sd.log" 2>&1 &
  echo $! > "$LOG_DIR/sd.pid"
  
  sleep 15
  if curl -s "http://127.0.0.1:$SD_PORT" &>/dev/null; then
    success "✓ Stable Diffusion 就绪"
  else
    warn "SD WebUI 启动中，请查看日志: $LOG_DIR/sd.log"
  fi
}

open_browser() {
  title "打开浏览器"
  
  log "等待服务就绪..."
  sleep 5
  
  # 打开 Open WebUI
  if curl -s "http://127.0.0.1:$WEBUI_PORT" &>/dev/null; then
    log "打开 Open WebUI..."
    open "http://localhost:$WEBUI_PORT"
    success "✓ Open WebUI: http://localhost:$WEBUI_PORT"
  fi
  
  # 打开 SD WebUI (如果运行)
  if curl -s "http://127.0.0.1:$SD_PORT" &>/dev/null; then
    log "打开 Stable Diffusion WebUI..."
    open "http://localhost:$SD_PORT"
    success "✓ SD WebUI: http://localhost:$SD_PORT"
  fi
  
  echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
  echo -e "${GREEN}  🎉 AI Studio 启动完成！${NC}"
  echo -e "${GREEN}═══════════════════════════════════════${NC}\n"
  
  echo "📋 配置指南:"
  echo "  1️⃣  Open WebUI 连接配置:"
  echo "      • API Base URL: http://host.docker.internal:$MLX_PORT/v1"
  echo "      • API Key: mlx-local"
  echo "      • Model IDs: [留空]"
  echo ""
  echo "  2️⃣  停止服务: ~/ai-studio-setup.sh stop"
  echo "  3️⃣  查看日志: ~/ai-studio-setup.sh logs"
}

stop_all() {
  title "停止服务"
  
  log "停止 MLX 服务..."
  if [[ -f "$LOG_DIR/mlx.pid" ]]; then
    kill $(cat "$LOG_DIR/mlx.pid") 2>/dev/null || true
    rm -f "$LOG_DIR/mlx.pid"
  fi
  lsof -ti :$MLX_PORT | xargs kill -9 2>/dev/null || true
  
  log "停止 Open WebUI..."
  docker stop open-webui 2>/dev/null || true
  docker rm open-webui 2>/dev/null || true
  
  log "停止 Stable Diffusion..."
  if [[ -f "$LOG_DIR/sd.pid" ]]; then
    kill $(cat "$LOG_DIR/sd.pid") 2>/dev/null || true
    rm -f "$LOG_DIR/sd.pid"
  fi
  lsof -ti :$SD_PORT | xargs kill -9 2>/dev/null || true
  
  success "✓ 所有服务已停止"
}

show_status() {
  title "服务状态"
  
  echo -e "${BLUE} AI Studio 运行状态:${NC}\n"
  
  # MLX
  echo -n "  🤖 MLX ($MLX_PORT): "
  if lsof -ti :$MLX_PORT &>/dev/null; then
    echo -e "${GREEN}● 运行中${NC}"
    curl -s "http://127.0.0.1:$MLX_PORT/v1/models" 2>/dev/null | \
      python3 -c "import sys,json; d=json.load(sys.stdin); print('     模型:', d['data'][0]['id'] if d.get('data') else '未知')" 2>/dev/null || true
  else
    echo -e "${RED}○ 未运行${NC}"
  fi
  
  # Open WebUI
  echo -n "  🌐 Open WebUI ($WEBUI_PORT): "
  if docker ps --format '{{.Names}}' | grep -q open-webui; then
    echo -e "${GREEN}● 运行中${NC}"
    echo "     访问: http://localhost:$WEBUI_PORT"
  else
    echo -e "${RED}○ 未运行${NC}"
  fi
  
  # Stable Diffusion
  echo -n "  🎨 Stable Diffusion ($SD_PORT): "
  if lsof -ti :$SD_PORT &>/dev/null; then
    echo -e "${GREEN}● 运行中${NC}"
    echo "     访问: http://localhost:$SD_PORT"
  else
    echo -e "${YELLOW}○ 未运行 (可选)${NC}"
  fi
  
  # 模型
  echo -e "\n  📦 模型目录:"
  echo "     Qwen3: $MODEL_DIR/qwen3-8b-mlx"
  [[ -f "$MODEL_DIR/qwen3-8b-mlx/config.json" ]] && echo -e "     状态: ${GREEN}完整${NC}" || echo -e "     状态: ${RED}缺失${NC}"
  
  if [[ -f "$MODEL_DIR/stable-diffusion/model_index.json" ]]; then
    echo "     SD-XL: $MODEL_DIR/stable-diffusion"
    echo -e "     状态: ${GREEN}完整${NC}"
  else
    echo -e "     SD-XL: ${YELLOW}未下载 (可选)${NC}"
  fi
}

show_logs() {
  title "实时日志"
  echo -e "${BLUE}跟踪日志 (Ctrl+C 退出)${NC}\n"
  [[ -d "$LOG_DIR" ]] && tail -f "$LOG_DIR"/*.log 2>/dev/null || warn "无日志文件"
}

# =============================================================================
# 🎯 主入口
# =============================================================================

main() {
  case "${1:-help}" in
    setup)
      check_requirements
      setup_environment
      download_models
      success "✅ 部署完成！执行: $0 start"
      ;;
    
    start)
      check_requirements
      [[ ! -d "$VENV_DIR" ]] && { error "请先执行: $0 setup"; exit 1; }
      
      title "启动 AI Studio"
      start_mlx
      start_webui
      start_stable_diffusion
      open_browser
      ;;
    
    chat)
      [[ ! -d "$VENV_DIR" ]] && { error "请先执行: $0 setup"; exit 1; }
      start_mlx
      start_webui
      open "http://localhost:$WEBUI_PORT"
      success "✓ 对话服务已启动"
      ;;
    
    draw)
      [[ ! -d "$VENV_DIR" ]] && { error "请先执行: $0 setup"; exit 1; }
      start_stable_diffusion
      open "http://localhost:$SD_PORT"
      success "✓ 画图服务已启动"
      ;;
    
    stop)
      stop_all
      ;;
    
    restart)
      stop_all
      sleep 2
      $0 start
      ;;
    
    status)
      show_status
      ;;
    
    logs)
      show_logs
      ;;
    
    clean)
      log "清理运行数据 (保留模型)..."
      stop_all
      rm -rf "$LOG_DIR"
      docker volume prune -f 2>/dev/null || true
      success "✓ 清理完成"
      ;;
    
    help|--help|-h)
      echo -e "${BLUE}用法:${NC} $0 {setup|start|stop|restart|status|logs|clean|chat|draw}"
      echo ""
      echo "命令说明:"
      echo "  setup   - 初始化环境 & 下载模型 (首次必跑)"
      echo "  start   - 启动所有服务 + 自动打开浏览器"
      echo "  chat    - 仅启动对话服务 (MLX + Open WebUI)"
      echo "  draw    - 仅启动画图服务 (Stable Diffusion)"
      echo "  stop    - 停止所有服务"
      echo "  restart - 重启所有服务"
      echo "  status  - 查看运行状态"
      echo "  logs    - 查看实时日志"
      echo "  clean   - 清理日志与 Docker 缓存"
      echo ""
      echo "快捷方式:"
      echo "  首次使用: $0 setup && $0 start"
      echo "  仅对话:   $0 chat"
      echo "  仅画图:   $0 draw"
      ;;
    
    *)
      error "未知命令: $1"
      $0 help
      exit 1
      ;;
  esac
}

main "$@"
