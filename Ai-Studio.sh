#!/bin/zsh
# =============================================================================
# 🍎 macOS Local AI 一键部署脚本
# 功能: 检查环境 → 安装 MLX → 下载 Qwen3 → 启动 Open WebUI
# 用法: 
#   ./local-ai-setup.sh setup     # 首次安装环境与模型
#   ./local-ai-setup.sh start     # 启动所有服务
#   ./local-ai-setup.sh stop      # 停止所有服务
#   ./local-ai-setup.sh status    # 查看运行状态
#   ./local-ai-setup.sh logs      # 查看实时日志
#   ./local-ai-setup.sh clean     # 清理缓存/日志/容器
# =============================================================================

set -e  # 遇错即停

# 📁 全局配置（可按需修改）
PROJECT_DIR="$HOME/local-ai"
MODEL_DIR="$PROJECT_DIR/models/qwen3-8b-mlx"
VENV_DIR="$PROJECT_DIR/mlx-env"
LOG_DIR="$PROJECT_DIR/logs"
MLX_PORT=8000
WEBUI_PORT=3000
MODEL_REPO="mlx-community/Qwen3-8B-4bit"
HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

# 🎨 终端样式
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
success() { echo -e "${GREEN}[✓]${NC} $(date '+%H:%M:%S') $1"; }
warn()    { echo -e "${YELLOW}[⚠]${NC} $(date '+%H:%M:%S') $1"; }
error()   { echo -e "${RED}[✗]${NC} $(date '+%H:%M:%S') $1"; }

# =============================================================================
# 🔧 核心函数
# =============================================================================

check_arch() {
  [[ "$(uname -m)" == "arm64" ]] || { error "MLX 仅支持 Apple Silicon (M1/M2/M3/M4)"; exit 1; }
}

check_docker() {
  command -v docker >/dev/null || { error "Docker 未安装。请先安装 Docker Desktop: https://docker.com/products/docker-desktop"; exit 1; }
  docker info >/dev/null 2>&1 || { error "Docker 未运行。请启动 Docker Desktop"; exit 1; }
}

setup_env() {
  log "📦 创建项目目录..."
  mkdir -p "$MODEL_DIR" "$LOG_DIR"

  if [[ ! -d "$VENV_DIR" ]]; then
    log "🐍 创建 Python 虚拟环境..."
    python3 -m venv "$VENV_DIR"
  fi

  source "$VENV_DIR/bin/activate"
  
  log "🔧 修复 SSL 证书 & 安装依赖..."
  export SSL_CERT_FILE=$(python3 -m certifi)
  export REQUESTS_CA_BUNDLE=$(python3 -m certifi)
  export HF_ENDPOINT="$HF_ENDPOINT"

  pip install --quiet --upgrade pip setuptools
  pip install --quiet mlx-lm huggingface_hub accelerate certifi
  
  success "Python 环境就绪"
}

download_model() {
  if [[ -f "$MODEL_DIR/config.json" ]]; then
    success "模型已存在: $MODEL_DIR"
    return 0
  fi

  log "📥 下载 Qwen3 MLX 模型 (约 4.6GB，请耐心等待)..."
  source "$VENV_DIR/bin/activate"
  export HF_ENDPOINT="$HF_ENDPOINT"
  
  hf download "$MODEL_REPO" --local-dir "$MODEL_DIR" || {
    error "下载失败。请检查网络或手动设置 HF_ENDPOINT"
    exit 1
  }
  success "模型下载完成"
}

start_mlx() {
  log "⚡ 启动 MLX 推理服务 (端口 $MLX_PORT)..."
  
  # 清理残留进程
  if lsof -ti :$MLX_PORT >/dev/null 2>&1; then
    lsof -ti :$MLX_PORT | xargs kill -9 2>/dev/null
    sleep 1
  fi

  source "$VENV_DIR/bin/activate"
  nohup mlx_lm.server \
    --model "$MODEL_DIR" \
    --host 127.0.0.1 \
    --port $MLX_PORT \
    --max-tokens 4096 \
    > "$LOG_DIR/mlx.log" 2>&1 &
  
  echo $! > "$LOG_DIR/mlx.pid"
  log "等待模型加载 (首次约 30~60 秒)..."
  sleep 15

  if curl -s --max-time 5 "http://127.0.0.1:$MLX_PORT/v1/models" | grep -q "model"; then
    success "MLX 服务已就绪"
  else
    warn "模型仍在后台加载，可执行: tail -f $LOG_DIR/mlx.log 查看进度"
  fi
}

start_webui() {
  log "🌐 启动 Open WebUI (端口 $WEBUI_PORT)..."
  
  if docker ps --format '{{.Names}}' | grep -q "^open-webui$"; then
    success "Open WebUI 已在运行"
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
  
  success "Open WebUI 容器已启动"
}

stop_all() {
  log "🛑 停止所有服务..."
  if [[ -f "$LOG_DIR/mlx.pid" ]]; then
    kill $(cat "$LOG_DIR/mlx.pid") 2>/dev/null
    rm -f "$LOG_DIR/mlx.pid"
  fi
  lsof -ti :$MLX_PORT | xargs kill -9 2>/dev/null
  docker stop open-webui 2>/dev/null || true
  docker rm open-webui 2>/dev/null || true
  success "服务已停止"
}

show_status() {
  echo -e "\n${BLUE}📊 本地 AI 环境状态:${NC}"
  echo -n "  🐍 MLX ($MLX_PORT): "
  lsof -ti :$MLX_PORT >/dev/null 2>&1 && echo -e "${GREEN}● 运行中${NC}" || echo -e "${RED}○ 未运行${NC}"
  
  echo -n "  🌐 Open WebUI ($WEBUI_PORT): "
  docker ps --format '{{.Names}}' | grep -q open-webui && echo -e "${GREEN}● 运行中${NC}" || echo -e "${RED}○ 未运行${NC}"
  
  echo -n "  📦 模型路径: $MODEL_DIR "
  [[ -f "$MODEL_DIR/config.json" ]] && echo -e "${GREEN}(完整)${NC}" || echo -e "${RED}(缺失，请运行 setup)${NC}"
}

show_logs() {
  echo -e "${BLUE}📋 实时日志 (Ctrl+C 退出)${NC}"
  [[ -d "$LOG_DIR" ]] && tail -f "$LOG_DIR"/*.log 2>/dev/null || warn "日志目录为空"
}

# =============================================================================
# 🎯 主入口
# =============================================================================

main() {
  case "${1:-help}" in
    setup)
      check_arch
      setup_env
      download_model
      success "✅ 环境部署完成！请执行: $0 start"
      ;;
    start)
      check_docker
      [[ ! -d "$VENV_DIR" ]] && { error "请先执行: $0 setup"; exit 1; }
      start_mlx
      start_webui
      echo -e "\n${GREEN}🎉 所有服务已启动！${NC}"
      echo "  🌐 浏览器访问: http://localhost:$WEBUI_PORT"
      echo "  🔗 Open WebUI 连接配置:"
      echo "     • API Base URL: http://host.docker.internal:$MLX_PORT/v1"
      echo "     • API Key: mlx-local (任意值)"
      echo "     • Model IDs: [留空自动识别]"
      ;;
    stop)   stop_all ;;
    restart) stop_all; sleep 2; $0 start ;;
    status) show_status ;;
    logs)   show_logs ;;
    clean)
      log "🧹 清理运行数据 (保留模型)..."
      stop_all
      rm -rf "$LOG_DIR"
      docker volume prune -f 2>/dev/null || true
      success "清理完成"
      ;;
    help|--help|-h)
      echo -e "${BLUE}用法:${NC} $0 {setup|start|stop|restart|status|logs|clean}"
      echo "  setup   - 初始化环境 & 下载模型 (首次必跑)"
      echo "  start   - 启动 MLX + Open WebUI"
      echo "  stop    - 停止所有服务"
      echo "  restart - 重启服务"
      echo "  status  - 查看运行状态"
      echo "  logs    - 查看实时日志"
      echo "  clean   - 清理日志与 Docker 缓存"
      ;;
    *) error "未知命令: $1"; $0 help; exit 1 ;;
  esac
}

main "$@"
