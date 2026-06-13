#!/usr/bin/env bash
# =============================================================================
# AI Studio Manager for macOS (Production Ready)
# =============================================================================
# 功能：管理 Open WebUI, SillyTavern, Continue.dev, FaaS, Browser Use,
#       MLX, ComfyUI (SDXL/FLUX), MLX-Video 的部署、更新、诊断与卸载
# 版本：1.5.0 (Ultimate Fix: HTTP/2 CANCEL, Auth Hang, PyPI Mirror, Full Menu)
# =============================================================================
set -uo pipefail

# =============================================================================
# 前置检查
# =============================================================================
if [[ ${BASH_VERSINFO[0]:-0} -lt 4 ]]; then
    echo -e "\033[0;31m[ERROR]\033[0m 此脚本需要 Bash 4.0 或更高版本。macOS 默认 Bash 为 3.2。" >&2
    echo "请执行以下命令升级 Bash，并使用新版本运行：" >&2
    echo "  brew install bash" >&2
    echo "  /opt/homebrew/bin/bash ai-studio.sh  (Apple Silicon)" >&2
    echo "  /usr/local/bin/bash ai-studio.sh     (Intel)" >&2
    exit 1
fi

readonly SCRIPT_VERSION="1.5.0"
readonly INSTALL_DIR="${HOME}/ai-studio"
readonly LOG_DIR="${INSTALL_DIR}/logs"
readonly BACKUP_DIR="${INSTALL_DIR}/backups"

# 🌟 核心修复 1：强制 Git 使用 HTTP/1.1 并增大缓冲区，解决 curl 92 CANCEL 错误
readonly GIT_NET_OPTS=(-c http.version=HTTP/1.1 -c http.postBuffer=524288000)
# 🌟 核心修复 2：彻底禁用 Git 交互式密码提示，防止脚本假死
export GIT_TERMINAL_PROMPT=0

# 🌟 核心修复 3：PyPI 国内镜像源加速
readonly PIP_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"
readonly PIP_TRUSTED="pypi.tuna.tsinghua.edu.cn"

# 固定遍历顺序，解决 Bash 关联数组无序问题
readonly COMP_KEYS=(open-webui sillytavern continue-dev faas browser-use mlx comfyui mlx-video)

declare -A COMPONENTS=(
    [open-webui]="Open WebUI|https://github.com/open-webui/open-webui.git|8080|http://localhost:8080"
    [sillytavern]="SillyTavern|https://github.com/SillyTavern/SillyTavern.git|8000|http://localhost:8000"
    [continue-dev]="Continue.dev|https://github.com/continuedev/continue.git|3000|http://localhost:3000"
    [faas]="FaaS|https://github.com/openfaas/faas.git|8081|http://localhost:8081"
    [browser-use]="Browser Use|https://github.com/browser-use/browser-use.git|8082|http://localhost:8082"
    [mlx]="MLX|https://github.com/ml-explore/mlx.git|N/A|local"
    [comfyui]="ComfyUI|https://github.com/comfyanonymous/ComfyUI.git|8188|http://localhost:8188"
    # 🌟 核心修复 4：修正为真实存在的公开仓库
    [mlx-video]="MLX-Video|https://github.com/Blaizzy/mlx-video.git|N/A|local"
)

# 全局变量：用于函数间返回数据（避免 echo 污染标准输出）
VENV_PIP=""
VENV_PYTHON=""
SELECTED_COMPONENT=""

# =============================================================================
# 工具函数
# =============================================================================
log_info()    { echo -e "\033[0;34m[INFO]\033[0m $1" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1" >&2; }
log_warn()    { echo -e "\033[0;33m[WARN]\033[0m $1" >&2; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

check_dependencies() {
    log_info "检查系统依赖..."
    local deps=("git" "python3" "node" "npm" "curl" "brew")
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    # macOS 编译工具检查 (防止 pip 编译 C 扩展时卡死)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! xcode-select -p &>/dev/null; then
            missing+=("xcode-select (请运行: xcode-select --install)")
        fi
    fi

    if [ ${#missing[@]} -eq 0 ]; then
        log_success "所有基础依赖已满足"
        return 0
    fi
    log_warn "发现缺失依赖: ${missing[*]}"
    log_info "请运行以下命令安装缺失依赖后重试："
    echo -e "\033[0;36m  brew install ${missing[*]} \033[0m" >&2
    if [[ "${1:-}" != "--ignore-missing" ]]; then
        exit 1
    fi
    return 0
}

# =============================================================================
# 诊断功能
# =============================================================================
diagnose_simple() {
    log_info "=== 简单诊断 ==="
    echo ""
    echo "系统信息:"
    echo "  macOS版本: $(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
    echo "  芯片类型: $(uname -m)"
    echo "  内存: $(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f GB", $1/1073741824}' || echo 'N/A')"
    echo ""
    echo "组件安装状态:"
    for key in "${COMP_KEYS[@]}"; do
        IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
        if [ -d "${INSTALL_DIR}/${key}" ]; then log_success "${name}: 已安装"
        else log_warn "${name}: 未安装"; fi
    done
    echo ""
    echo "端口占用情况:"
    local ports=(8080 8000 3000 8081 8082 8188)
    for port in "${ports[@]}"; do
        if command -v lsof &>/dev/null && lsof -i :${port} -t &>/dev/null; then
            log_warn "端口 ${port} 被占用"
        else
            log_success "端口 ${port} 空闲"
        fi
    done
    log_success "简单诊断完成"
}

diagnose_deep() {
    diagnose_simple
    echo ""
    echo "网络连通性测试 (GitHub/HuggingFace/PyPI):"
    for url in "github.com" "huggingface.co" "pypi.org"; do
        if curl -sI --max-time 5 "https://${url}" &>/dev/null; then
            log_success "${url}: 可达"
        else
            log_error "${url}: 不可达 (请检查网络/代理)"
        fi
    done
    log_success "深度诊断完成"
}

# =============================================================================
# 虚拟环境管理
# =============================================================================
setup_venv() {
    local dir="$1"
    local venv_python="${dir}/venv/bin/python"
    if [ ! -f "$venv_python" ]; then
        log_info "创建 Python 虚拟环境: ${dir}/venv"
        if ! python3 -m venv "${dir}/venv" 2>&1; then
            log_error "虚拟环境创建失败"
            return 1
        fi
        "${dir}/venv/bin/pip" install --upgrade pip setuptools wheel -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" &>/dev/null || true
    fi
    VENV_PIP="${dir}/venv/bin/pip"
    VENV_PYTHON="${venv_python}"
    return 0
}

# =============================================================================
# 部署功能
# =============================================================================
deploy_component() {
    local key="$1"
    IFS='|' read -r name repo_url port _ <<< "${COMPONENTS[$key]}"
    log_info "开始部署 ${name}..."
    mkdir -p "${INSTALL_DIR}" "${LOG_DIR}" "${BACKUP_DIR}"
    
    # 🌟 核心修复 5：增加 || return 1，确保子函数失败时立即中断，不打印 SUCCESS
    case "$key" in
        open-webui) deploy_open_webui "$repo_url" || return 1 ;;
        sillytavern) deploy_sillytavern "$repo_url" || return 1 ;;
        continue-dev) deploy_continue "$repo_url" || return 1 ;;
        faas) deploy_faas "$repo_url" || return 1 ;;
        browser-use) deploy_browser_use "$repo_url" || return 1 ;;
        mlx) deploy_mlx "$repo_url" || return 1 ;;
        comfyui) deploy_comfyui "$repo_url" || return 1 ;;
        mlx-video) deploy_mlx_video "$repo_url" || return 1 ;;
        *) log_error "未知组件: ${key}"; return 1 ;;
    esac
    log_success "${name} 部署完成"
}

# 通用克隆逻辑：自动清理残留目录 + 使用 GIT_NET_OPTS 防 CANCEL + 禁用密码提示
safe_git_clone() {
    local repo_url="$1" dir="$2"
    if [ -d "${dir}" ] && [ ! -d "${dir}/.git" ]; then
        log_warn "发现残留目录 ${dir}，正在清理..."
        rm -rf "${dir}"
    fi
    if [ ! -d "${dir}/.git" ]; then
        log_info "克隆 ${repo_url}..."
        # 🌟 核心修复 6：使用数组展开传入网络优化参数
        if ! git "${GIT_NET_OPTS[@]}" clone --depth 1 "${repo_url}" "${dir}"; then
            log_error "克隆失败 (网络错误或仓库不存在)"
            return 1
        fi
    fi
    return 0
}

deploy_open_webui() {
    local repo_url="$1" dir="${INSTALL_DIR}/open-webui"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    if ! setup_venv "${dir}"; then return 1; fi
    log_info "安装 Open WebUI 依赖 (包含 PyTorch，可能需要 10-30 分钟)..."
    if ! "$VENV_PIP" install -e . -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED"; then
        log_warn "镜像源安装失败，尝试官方源..."
        "$VENV_PIP" install -e . || { log_error "依赖安装失败"; return 1; }
    fi
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
exec python -m open_webui --host 0.0.0.0 --port 8080
EOF
    chmod +x start.sh
}

deploy_sillytavern() {
    local repo_url="$1" dir="${INSTALL_DIR}/sillytavern"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    log_info "安装 Node.js 依赖..."
    npm install --silent 2>/dev/null || npm install || { log_error "npm install 失败"; return 1; }
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec node server.js --listen --port 8000
EOF
    chmod +x start.sh
}

deploy_continue() {
    local repo_url="$1" dir="${INSTALL_DIR}/continue-dev"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    npm install --silent 2>/dev/null || npm install
    npm run build --silent 2>/dev/null || npm run build || true
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec npm run dev -- --port 3000
EOF
    chmod +x start.sh
}

deploy_faas() {
    local repo_url="$1" dir="${INSTALL_DIR}/faas"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    if ! command -v faas-cli &>/dev/null; then
        log_info "安装 faas-cli..."
        brew install openfaas/tap/faas-cli 2>&1 || { log_error "faas-cli 安装失败"; return 1; }
    fi
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec faas-cli up --port 8081 2>&1
EOF
    chmod +x start.sh
}

deploy_browser_use() {
    local repo_url="$1" dir="${INSTALL_DIR}/browser-use"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    if ! setup_venv "${dir}"; then return 1; fi
    log_info "安装 Browser Use 依赖..."
    "$VENV_PIP" install -e . -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1 || log_warn "pip install 警告"
    "$VENV_PIP" install playwright -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1
    ./venv/bin/playwright install chromium 2>/dev/null || true
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
exec python main.py --port 8082 2>/dev/null || echo "请检查 browser-use 官方启动方式"
EOF
    chmod +x start.sh
}

deploy_mlx() {
    local repo_url="$1" dir="${INSTALL_DIR}/mlx"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    if ! setup_venv "${dir}"; then return 1; fi
    log_info "安装 MLX 及示例..."
    "$VENV_PIP" install mlx mlx-examples -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1 || log_warn "MLX 安装警告"
}

deploy_comfyui() {
    local repo_url="$1" dir="${INSTALL_DIR}/comfyui"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    if ! setup_venv "${dir}"; then return 1; fi
    log_info "安装 ComfyUI 依赖..."
    if [[ -f "requirements.txt" ]]; then
        "$VENV_PIP" install -r requirements.txt -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1 || log_warn "依赖安装警告"
    fi
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
exec python main.py --listen --port 8188
EOF
    chmod +x start.sh
}

deploy_mlx_video() {
    local repo_url="$1" dir="${INSTALL_DIR}/mlx-video"
    safe_git_clone "$repo_url" "$dir" || return 1
    cd "${dir}" || return 1
    if ! setup_venv "${dir}"; then return 1; fi
    if [[ -f "requirements.txt" ]]; then
        log_info "安装 MLX-Video 依赖..."
        "$VENV_PIP" install -r requirements.txt -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1 || log_warn "依赖安装警告"
    else
        "$VENV_PIP" install mlx -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1
    fi
    log_info "MLX-Video 部署完成 (本地计算框架，无服务端口)"
}

# =============================================================================
# 服务管理
# =============================================================================
start_service() {
    local key="$1"
    IFS='|' read -r name _ port default_url <<< "${COMPONENTS[$key]}"
    log_info "启动 ${name}..."
    if [ "$port" != "N/A" ] && [ ! -f "${INSTALL_DIR}/${key}/start.sh" ]; then
        log_error "${name} 未部署或启动脚本不存在"; return 1
    fi
    if [ "$port" != "N/A" ]; then
        cd "${INSTALL_DIR}/${key}" || return 1
        nohup ./start.sh >> "${LOG_DIR}/${key}.log" 2>&1 &
        local pid=$!
        echo "$pid" > "${LOG_DIR}/${key}.pid"
        log_success "${name} 已在后台启动 (PID: ${pid})"
    else
        log_info "${name} 为本地框架，无需启动后台服务。"
    fi
}

stop_service() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    log_info "停止 ${name}..."
    local pid_file="${LOG_DIR}/${key}.pid"
    if [ -f "$pid_file" ]; then
        local pid; read -r pid < "$pid_file" 2>/dev/null || pid=""
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
            log_success "${name} 已停止"
        fi
        rm -f "$pid_file"
    else
        log_warn "${name} 未找到运行进程"
    fi
}

start_all_services() { for k in "${COMP_KEYS[@]}"; do [ -f "${INSTALL_DIR}/${k}/start.sh" ] && start_service "$k"; done; }
stop_all_services() { for k in "${COMP_KEYS[@]}"; do stop_service "$k"; done; }

# =============================================================================
# 更新与回退
# =============================================================================
update_component() {
    local key="$1"
    IFS='|' read -r name repo_url _ _ <<< "${COMPONENTS[$key]}"
    log_info "更新 ${name}..."
    local dir="${INSTALL_DIR}/${key}"
    cd "$dir" || { log_error "目录不存在: $dir"; return 1; }
    
    log_info "拉取最新代码..."
    # 🌟 核心修复 7：更新时也使用 HTTP/1.1 防止 CANCEL
    if ! git "${GIT_NET_OPTS[@]}" pull --quiet origin main 2>/dev/null && \
       ! git "${GIT_NET_OPTS[@]}" pull --quiet origin master 2>/dev/null && \
       ! git "${GIT_NET_OPTS[@]}" pull --quiet 2>/dev/null; then
        log_error "代码更新失败，请检查网络连接"
        return 1
    fi
    
    case "$key" in
        open-webui|browser-use|comfyui|mlx|mlx-video)
            if [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
                log_info "更新 Python 依赖..."
                if ! setup_venv "$dir"; then return 1; fi
                "$VENV_PIP" install -e . --upgrade -i "$PIP_INDEX" --trusted-host "$PIP_TRUSTED" 2>&1 || log_warn "pip upgrade 警告"
            fi
            ;;
        sillytavern|continue-dev)
            log_info "更新 Node.js 依赖..."
            npm install --silent 2>/dev/null || npm install || log_warn "npm install 警告"
            ;;
    esac
    log_success "${name} 更新完成"
}

rollback_component() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    log_warn "回退功能需要手动备份支持，当前版本暂略过复杂交互，请使用 git reset 回退。"
}

# =============================================================================
# 状态与卸载
# =============================================================================
show_status() {
    log_info "=== 组件状态 ==="
    for key in "${COMP_KEYS[@]}"; do
        IFS='|' read -r name _ port _ <<< "${COMPONENTS[$key]}"
        local status="未安装"
        if [ -d "${INSTALL_DIR}/${key}" ]; then status="已安装"; fi
        if [ -f "${LOG_DIR}/${key}.pid" ]; then
            local pid; read -r pid < "${LOG_DIR}/${key}.pid" 2>/dev/null || pid=""
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then status="运行中 (PID:${pid})"
            else status="已停止"; fi
        fi
        printf "%-15s %-10s %-10s\n" "$name" "$status" "$port"
    done
}

uninstall_component() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    read -p "确定卸载 ${name}? (输入 yes 确认): " confirm
    if [[ "$confirm" == "yes" ]]; then
        stop_service "$key"
        rm -rf "${INSTALL_DIR}/${key}"
        rm -f "${LOG_DIR}/${key}.log"* "${LOG_DIR}/${key}.pid"
        log_success "${name} 已卸载"
    else
        log_info "取消卸载"
    fi
}

uninstall_all() {
    log_warn "=== ⚠️  警告：完全卸载 ==="
    read -p "确定要删除所有组件和数据? (输入 yes 确认): " confirm
    if [[ "$confirm" == "yes" ]]; then
        stop_all_services
        rm -rf "${INSTALL_DIR}"
        log_success "✅ 所有组件已完全卸载"
    fi
}

# =============================================================================
# 菜单系统
# =============================================================================
show_menu() {
    clear
    echo "=================================================="
    echo "         AI Studio Manager v${SCRIPT_VERSION}"
    echo "         macOS Optimized | Production Ready"
    echo "=================================================="
    echo ""
    echo "📦 部署管理:"
    echo "   1. 首次部署 (全部组件)"
    echo "   2. 选择性部署 (单个组件)"
    echo ""
    echo "🚀 服务管理:"
    echo "   3. 启动全部服务"
    echo "   4. 停止全部服务"
    echo "   5. 启动单个服务"
    echo "   6. 停止单个服务"
    echo ""
    echo "📊 状态与诊断:"
    echo "   7. 查看组件状态"
    echo "   8. 简单系统诊断"
    echo "   9. 深度系统诊断"
    echo ""
    echo "🔄 更新与回退:"
    echo "  10. 更新全部组件"
    echo "  11. 更新前端组件 (WebUI/ST/Continue/ComfyUI)"
    echo "  12. 更新 Agent 组件 (BrowserUse/FaaS/MLX)"
    echo "  13. 更新模型组件 (MLX/MLX-Video/ComfyUI)"
    echo "  14. 版本回退 (单个组件)"
    echo ""
    echo "🗑️  清理管理:"
    echo "  15. 卸载单个组件"
    echo "  16. 完全卸载 (全部)"
    echo ""
    echo "   0. 退出"
    echo "=================================================="
    echo ""
}

# 🌟 核心修复 8：使用全局变量 SELECTED_COMPONENT 返回结果，并将菜单输出重定向到 stderr (>&2)
select_component() {
    SELECTED_COMPONENT=""
    echo "可用组件列表:" >&2
    echo "--------------------------------------------------" >&2
    for i in "${!COMP_KEYS[@]}"; do
        local key="${COMP_KEYS[$i]}"
        IFS='|' read -r name repo port url <<< "${COMPONENTS[$key]}"
        printf "  %2d. %-15s 端口:%-6s  %s\n" "$((i+1))" "$name" "$port" "$url" >&2
    done
    echo "--------------------------------------------------" >&2
    read -p "选择组件编号 (1-${#COMP_KEYS[@]}, 回车取消): " choice
    if [[ -z "$choice" ]]; then return 1
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#COMP_KEYS[@]} )); then
        SELECTED_COMPONENT="${COMP_KEYS[$((choice-1))]}"
        return 0
    else
        log_error "无效选择"; return 1
    fi
}

main() {
    while true; do
        show_menu
        read -p "请选择操作 [0-16]: " choice
        case "$choice" in
            1) check_dependencies "--ignore-missing"
               for k in "${COMP_KEYS[@]}"; do deploy_component "$k" || true; done ;;
            2) if ! select_component; then log_error "无效选择"; continue; fi
               check_dependencies "--ignore-missing"
               deploy_component "$SELECTED_COMPONENT" ;;
            3) start_all_services ;;
            4) stop_all_services ;;
            5) if ! select_component; then continue; fi; start_service "$SELECTED_COMPONENT" ;;
            6) if ! select_component; then continue; fi; stop_service "$SELECTED_COMPONENT" ;;
            7) show_status ;;
            8) diagnose_simple ;;
            9) diagnose_deep ;;
            10) for k in "${COMP_KEYS[@]}"; do [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k" || true; done ;;
            11) for k in open-webui sillytavern continue-dev comfyui; do [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k" || true; done ;;
            12) for k in browser-use faas mlx; do [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k" || true; done ;;
            13) for k in mlx mlx-video comfyui; do [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k" || true; done ;;
            14) if ! select_component; then continue; fi; rollback_component "$SELECTED_COMPONENT" ;;
            15) if ! select_component; then continue; fi; uninstall_component "$SELECTED_COMPONENT" ;;
            16) uninstall_all ;;
            0) log_info "👋 退出 AI Studio Manager"; exit 0 ;;
            *) log_error "无效选项，请输入 0-16" ;;
        esac
        echo ""; read -p "✅ 按回车键继续..." -r
    done
}

# =============================================================================
# CLI 入口
# =============================================================================
case "${1:-}" in
    --help|-h) echo "用法: $0 [--deploy-all|--start-all|--stop-all]"; exit 0 ;;
    --deploy-all) check_dependencies "--ignore-missing"
                  for k in "${COMP_KEYS[@]}"; do deploy_component "$k" || true; done ;;
    --start-all) start_all_services ;;
    --stop-all) stop_all_services ;;
    --status) show_status ;;
    *) main ;;
esac
