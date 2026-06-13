#!/usr/bin/env bash
set -euo pipefail
export AI_STUDIO_ROOT="${AI_STUDIO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export AI_STUDIO_HOME="${AI_STUDIO_HOME:-$HOME/.ai-studio}"
export AI_STUDIO_CONFIG_DIR="$AI_STUDIO_HOME/config"
export AI_STUDIO_LOG_DIR="$AI_STUDIO_HOME/logs"
export AI_STUDIO_RUN_DIR="$AI_STUDIO_HOME/run"
export AI_STUDIO_DATA_DIR="$AI_STUDIO_HOME/data"
export AI_STUDIO_LIB_DIR="$AI_STUDIO_ROOT/lib"
export AI_STUDIO_COMPONENTS_DIR="$AI_STUDIO_ROOT/components"
export AI_STUDIO_COMMANDS_DIR="$AI_STUDIO_ROOT/commands"

init_dirs() { mkdir -p "$AI_STUDIO_CONFIG_DIR" "$AI_STUDIO_LOG_DIR" "$AI_STUDIO_RUN_DIR" "$AI_STUDIO_DATA_DIR"; }

if [[ -t 1 ]]; then
    CLR_RED="\033[0;31m"; CLR_GREEN="\033[0;32m"; CLR_YELLOW="\033[0;33m"
    CLR_BLUE="\033[0;34m"; CLR_CYAN="\033[0;36m"; CLR_BOLD="\033[1m"; CLR_DIM="\033[2m"; CLR_RESET="\033[0m"
else
    CLR_RED=""; CLR_GREEN=""; CLR_YELLOW=""; CLR_BLUE=""; CLR_CYAN=""; CLR_BOLD=""; CLR_DIM=""; CLR_RESET=""
fi

log_info()    { echo -e "${CLR_GREEN}[INFO]${CLR_RESET}  $*"; }
log_warn()    { echo -e "${CLR_YELLOW}[WARN]${CLR_RESET}  $*"; }
log_error()   { echo -e "${CLR_RED}[ERROR]${CLR_RESET} $*" >&2; }
log_debug()   { [[ "${AI_STUDIO_DEBUG:-0}" == "1" ]] && echo -e "${CLR_DIM}[DEBUG]${CLR_RESET} $*"; }
log_success() { echo -e "${CLR_GREEN}[OK]${CLR_RESET}    $*"; }

detect_platform() {
    case "$(uname -s)" in Darwin) export AI_STUDIO_OS="macos";; Linux) export AI_STUDIO_OS="linux";; *) log_error "不支持的OS"; return 1;; esac
    case "$(uname -m)" in arm64|aarch64) export AI_STUDIO_ARCH="arm64";; x86_64) export AI_STUDIO_ARCH="x64";; *) log_error "不支持的架构"; return 1;; esac
}
is_apple_silicon() { [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; }
check_command() { command -v "$1" &>/dev/null; }
require_command() { check_command "$1" || { log_error "缺少: $1 ${2:-}"; return 1; }; }

is_port_free() { ! lsof -i ":$1" &>/dev/null 2>&1; }
find_free_port() { for ((p=${1:-8000}; p<=${2:-9000}; p++)); do is_port_free "$p" && { echo "$p"; return 0; }; done; return 1; }

save_pid() { echo "$2" > "$AI_STUDIO_RUN_DIR/${1}.pid"; }
get_pid() { [[ -f "$AI_STUDIO_RUN_DIR/${1}.pid" ]] && cat "$AI_STUDIO_RUN_DIR/${1}.pid"; }
is_running() {
    local pid; pid="$(get_pid "$1")"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && return 0
    rm -f "$AI_STUDIO_RUN_DIR/${1}.pid"; return 1
}
kill_service() {
    local pid; pid="$(get_pid "$1")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null; local c=0
        while kill -0 "$pid" 2>/dev/null && ((c<10)); do sleep 1; ((c++)); done
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
        log_info "已停止 $1 (PID: $pid)"
    fi
    rm -f "$AI_STUDIO_RUN_DIR/${1}.pid"
}

open_browser() {
    local url="$1"
    [[ "$AI_STUDIO_OS" == "macos" ]] && open "$url" 2>/dev/null &
    [[ "$AI_STUDIO_OS" == "linux" ]] && xdg-open "$url" 2>/dev/null &
    log_info "浏览器已打开: $url"
}

download_file() {
    if check_command curl; then curl -fSL --progress-bar -o "$2" "$1"
    elif check_command wget; then wget -q --show-progress -O "$2" "$1"
    else log_error "需要 curl 或 wget"; return 1; fi
}

wait_for_service() {
    local url="$1" timeout="${2:-30}" name="${3:-service}" c=0
    log_info "等待 $name 就绪 ($url)..."
    while ((c < timeout)); do curl -sf "$url" &>/dev/null && { log_success "$name 已就绪"; return 0; }; sleep 1; ((c++)); done
    log_warn "$name 启动超时 (${timeout}s)"; return 1
}

confirm() {
    local msg="${1:-确认?}" default="${2:-n}" prompt
    [[ "$default" == "y" ]] && prompt="$msg [Y/n]: " || prompt="$msg [y/N]: "
    echo -en "${CLR_CYAN}$prompt${CLR_RESET}"; read -r answer; answer="${answer:-$default}"; [[ "$answer" =~ ^[Yy] ]]
}

handle_port_conflict() {
    local port="$1" name="$2"
    if ! is_port_free "$port"; then
        log_warn "端口 $port 被占用 ($name)"
        if confirm "终止占用进程?"; then
            lsof -i ":$port" -t 2>/dev/null | xargs kill -9 2>/dev/null; sleep 1
            is_port_free "$port" && { echo "$port"; return 0; }
        fi
        local np; np="$(find_free_port $((port+1)) $((port+100)))"
        [[ -n "$np" ]] && { log_info "替代端口: $np"; echo "$np"; return 0; }
        log_error "无可用端口"; return 1
    fi
    echo "$port"
}

load_libs() {
    init_dirs; detect_platform
    for lib in logger ui network config component; do
        [[ -f "$AI_STUDIO_LIB_DIR/${lib}.sh" ]] && source "$AI_STUDIO_LIB_DIR/${lib}.sh"
    done
}
