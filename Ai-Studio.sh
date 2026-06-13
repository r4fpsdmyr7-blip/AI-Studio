#!/bin/zsh
# =============================================================================
# 🚀 Local AI Starter: Open WebUI + MLX + Qwen3 (macOS Apple Silicon)
# 用法: 
#   ./start-local-ai.sh start     # 启动所有服务
#   ./start-local-ai.sh stop      # 停止所有服务
#   ./start-local-ai.sh status    # 查看服务状态
#   ./start-local-ai.sh logs      # 查看实时日志
#   ./start-local-ai.sh restart   # 重启服务
# =============================================================================

# 📁 配置区域（请根据实际情况修改）
PROJECT_DIR="$HOME/local-ai"                    # 项目根目录
MODEL_DIR="$PROJECT_DIR/qwen3-8b-mlx"          # MLX 模型路径
VENV_DIR="$PROJECT_DIR/mlx-env"                # Python 虚拟环境
LOG_DIR="$PROJECT_DIR/logs"                    # 日志目录
MLX_PORT=8000                                   # MLX API 端口
WEBUI_PORT=3000                                 # Open WebUI 端口
MLX_LOG="$LOG_DIR/mlx.log"                      # MLX 日志文件
WEBUI_LOG="$LOG_DIR/webui.log"                  # Open WebUI 日志文件

# 🎨 颜色输出
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# =============================================================================
# 🔧 工具函数
# =============================================================================

log() { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
success() { echo -e "${GREEN}[✓]${NC} $(date '+%H:%M:%S') $1"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $(date '+%H:%M:%S') $1"; }
error() { echo -e "${RED}[✗]${NC} $(date '+%H:%M:%S') $1" >&2; }

check_cmd() { command -v "$1" >/dev/null 2>&1 || { error "$1 未安装"; exit 1; } }

check_port() { lsof -ti :"$1" 2>/dev/null; }

wait_for_port() {
  local port=$1 timeout=${2:-30} elapsed=0
  while ! check_port "$port" >/dev/null 2>&1; do
    [[ $elapsed -ge $timeout ]] && return 1
    sleep 1; ((elapsed++))
  done
  return 0
}

# =============================================================================
# 🚀 核心功能
# =============================================================================

start_mlx() {
  log "启动 MLX + Qwen3 服务 (端口 $MLX_PORT)..."
  
  # 检查模型文件
  [[ ! -f "$MODEL_DIR/config.json" ]] && { error "模型文件缺失: $MODEL_DIR/config.json"; return 1; }
  
  # 激活虚拟环境
  source "$VENV_DIR/bin/activate" 2>/dev/null || { error "虚拟环境激活失败"; return 1; }
  
  # 创建日志目录
  mkdir -p "$LOG_DIR"
  
  # 后台启动 MLX 服务
  nohup mlx_lm.server \
    --model "$MODEL_DIR" \
    --host 127.0.0.1 \
    --port "$MLX_PORT" \
    --max-tokens 4096 \
    > "$MLX_LOG" 2>&1 &
  
  local pid=$!
  echo $pid > "$LOG_DIR/mlx.pid"
  
  # 等待服务就绪
  if wait_for_port "$MLX_PORT" 60; then
    success "MLX 服务已启动 (PID: $pid)"
    # 验证 API
    if curl -s --max-time 5 "http://127.0.0.1:$MLX_PORT/v1/models" | grep -q "model"; then
      success "API 验证通过"
      return 0
    fi
  fi
  warn "MLX 服务启动中，请查看日志: $MLX_LOG"
  return 0
}

start_webui() {
  log "启动 Open WebUI (端口 $WEBUI_PORT)..."
  
  # 检查 Docker
  check_cmd docker || return 1
  docker info >/dev/null 2>&1 || { error "Docker 未运行"; return 1; }
  
  # 检查容器是否已在运行
  if docker ps --format '{{.Names}}' | grep -q "^open-webui$"; then
    success "Open WebUI 已在运行"
    return 0
  fi
  
  # 启动容器
  docker run -d \
    --name open-webui \
    --restart always \
    -p "$WEBUI_PORT":8080 \
    -v open-webui:/app/backend/data \
    -e OLLAMA_BASE_URL="" \
    ghcr.io/open-webui/open-webui:main \
    > "$WEBUI_LOG" 2>&1
  
  # 等待容器就绪
  if wait_for_port "$WEBUI_PORT" 30; then
    success "Open WebUI 已启动 (http://localhost:$WEBUI_PORT)"
    return 0
  fi
  warn "Open WebUI 启动中，请查看日志: $WEBUI_LOG"
  return 0
}

start_all() {
  log "🚀 启动 Local AI 环境..."
  
  # 创建项目目录
  mkdir -p "$PROJECT_DIR" "$LOG_DIR"
  
  # 启动 MLX 服务
  start_mlx || { error "MLX 启动失败"; return 1; }
  
  # 等待 MLX 完全就绪（模型加载需要时间）
  log "等待模型加载 (最多 90 秒)..."
  sleep 10  # 给模型加载预留时间
  
  # 启动 Open WebUI
  start_webui || { error "Open WebUI 启动失败"; return 1; }
  
  # 自动打开浏览器
  if command -v open >/dev/null 2>&1; then
    log "🌐 正在打开 Open WebUI..."
    open "http://localhost:$WEBUI_PORT"
  fi
  
  success "✨ 所有服务启动完成！"
  echo -e "\n${GREEN}📋 使用指南:${NC}"
  echo "  • Open WebUI: http://localhost:$WEBUI_PORT"
  echo "  • MLX API:    http://127.0.0.1:$MLX_PORT/v1"
  echo "  • 模型名称:   $(curl -s "http://127.0.0.1:$MLX_PORT/v1/models" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'] if d.get('data') else '未知')" 2>/dev/null || echo "请查看 /v1/models")"
  echo "  • 停止服务:   ./start-local-ai.sh stop"
  echo "  • 查看日志:   ./start-local-ai.sh logs"
}

stop_mlx() {
  log "停止 MLX 服务..."
  if [[ -f "$LOG_DIR/mlx.pid" ]]; then
    local pid=$(cat "$LOG_DIR/mlx.pid")
    if ps -p "$pid" >/dev/null 2>&1; then
      kill "$pid" 2>/dev/null
      sleep 2
      kill -9 "$pid" 2>/dev/null
      success "MLX 服务已停止 (PID: $pid)"
    fi
    rm -f "$LOG_DIR/mlx.pid"
  fi
  # 备用：通过端口查找进程
  local port_pid=$(check_port "$MLX_PORT")
  if [[ -n "$port_pid" ]]; then
    kill -9 "$port_pid" 2>/dev/null
    success "MLX 服务已强制停止 (端口 $MLX_PORT)"
  fi
}

stop_webui() {
  log "停止 Open WebUI..."
  if docker ps --format '{{.Names}}' | grep -q "^open-webui$"; then
    docker stop open-webui >/dev/null 2>&1
    docker rm open-webui >/dev/null 2>&1
    success "Open WebUI 容器已停止"
  fi
}

stop_all() {
  log "🛑 停止所有服务..."
  stop_mlx
  stop_webui
  success "所有服务已停止"
}

show_status() {
  echo -e "\n${BLUE}📊 服务状态:${NC}"
  
  # MLX 状态
  echo -n "  MLX ($MLX_PORT): "
  if check_port "$MLX_PORT" >/dev/null 2>&1; then
    echo -e "${GREEN}● 运行中${NC}"
    curl -s "http://127.0.0.1:$MLX_PORT/v1/models" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('    模型:', d['data'][0]['id'] if d.get('data') else '未知')" 2>/dev/null
  else
    echo -e "${RED}○ 未运行${NC}"
  fi
  
  # Open WebUI 状态
  echo -n "  Open WebUI ($WEBUI_PORT): "
  if docker ps --format '{{.Names}}' | grep -q "^open-webui$"; then
    echo -e "${GREEN}● 运行中${NC} (http://localhost:$WEBUI_PORT)"
  else
    echo -e "${RED}○ 未运行${NC}"
  fi
  
  # 磁盘使用
  if [[ -d "$MODEL_DIR" ]]; then
    local size=$(du -sh "$MODEL_DIR" 2>/dev/null | cut -f1)
    echo "  模型大小: $size"
  fi
}

show_logs() {
  echo -e "${BLUE}📋 实时日志 (Ctrl+C 退出)${NC}\n"
  
  # 同时跟踪两个日志文件
  if [[ -f "$MLX_LOG" ]] || [[ -f "$WEBUI_LOG" ]]; then
    tail -f "$MLX_LOG" "$WEBUI_LOG" 2>/dev/null
  else
    warn "日志文件不存在，请先启动服务"
  fi
}

# =============================================================================
# 🎯 主入口
# =============================================================================

main() {
  case "${1:-start}" in
    start)   start_all ;;
    stop)    stop_all ;;
    restart) stop_all; sleep 2; start_all ;;
    status)  show_status ;;
    logs)    show_logs ;;
    help|--help|-h)
      echo "用法: $0 {start|stop|restart|status|logs}"
      echo "  start   - 启动所有服务"
      echo "  stop    - 停止所有服务"
      echo "  restart - 重启所有服务"
      echo "  status  - 查看服务状态"
      echo "  logs    - 查看实时日志"
      ;;
    *) error "未知命令: $1"; echo "使用 '$0 help' 查看帮助"; exit 1 ;;
  esac
}

# 执行主函数
main "$@"
