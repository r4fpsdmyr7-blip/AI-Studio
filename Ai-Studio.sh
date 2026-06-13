#!/usr/bin/env bash
# =============================================================================
# AI Studio Manager for macOS (Optimized & Fixed)
# =============================================================================
# 功能：管理 Open WebUI, SillyTavern, Continue.dev, FaaS, Browser Use,
#       MLX, ComfyUI (SDXL/FLUX), MLX-Video 的部署、更新、诊断与卸载
# 作者：AI Assistant
# 日期：2026-06-01
# 版本：1.1.1 (Fixed stability, macOS compatibility & interactive safety)
# =============================================================================
set -uo pipefail

# =============================================================================
# 前置检查
# =============================================================================
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo -e "\033[0;31m[ERROR]\033[0m 此脚本需要 Bash 4.0 或更高版本。macOS 默认 Bash 为 3.2。"
    echo "请执行以下命令升级 Bash，并使用新版本运行："
    echo "  brew install bash"
    echo "  /opt/homebrew/bin/bash ai-studio.sh  (Apple Silicon)"
    echo "  /usr/local/bin/bash ai-studio.sh     (Intel)"
    exit 1
fi

readonly SCRIPT_VERSION="1.1.1"
readonly INSTALL_DIR="${HOME}/ai-studio"
readonly LOG_DIR="${INSTALL_DIR}/logs"
readonly BACKUP_DIR="${INSTALL_DIR}/backups"

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
[mlx-video]="MLX-Video|https://github.com/ml-explore/mlx-video.git|N/A|local"
)

# =============================================================================
# 工具函数 (日志输出至 stderr 避免污染返回值)
# =============================================================================
log_info()    { echo -e "\033[0;34m[INFO]\033[0m $1" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1" >&2; }
log_warn()    { echo -e "\033[0;33m[WARN]\033[0m $1" >&2; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

check_dependencies() {
    log_info "检查系统依赖..."
    local deps=("git" "python3" "node" "npm" "curl")
    local missing=()
    for dep in "${deps[@]}"; do
        command -v "$dep" &> /dev/null || missing+=("$dep")
    done

    if [ ${#missing[@]} -eq 0 ]; then
        log_success "所有基础依赖已满足"
        return 0
    fi

    log_warn "发现缺失依赖: ${missing[*]}"
    log_info "请运行以下命令安装缺失依赖后重试："
    echo -e "\033[0;36m  brew install ${missing[*]} \033[0m"
    
    # 非交互模式下直接退出，避免后续命令连锁失败
    if [[ "${1:-}" != "--ignore-missing" ]]; then
        exit 1
    fi
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
    echo "  内存: $(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f GB", $1/1073741824}')"
    echo ""
    echo "依赖检查:"
    local deps=("brew" "git" "python3" "node")
    for dep in "${deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_success "$dep: $($dep --version 2>/dev/null | head -1 || echo 'Installed')"
        else
            log_error "$dep: 未安装"
        fi
    done
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
        if lsof -i :${port} -t &> /dev/null; then
            log_warn "端口 ${port} 被占用 (PID: $(lsof -i :${port} -t | head -1))"
        else
            log_success "端口 ${port} 空闲"
        fi
    done
    echo ""
    echo "磁盘空间:"
    df -h / | awk 'NR==2 {printf "可用空间: %s (已用 %s)\n", $4, $5}'
    echo ""
    log_success "简单诊断完成"
}

diagnose_deep() {
    log_info "=== 深度诊断 ==="
    diagnose_simple
    echo "详细系统信息:"
    echo "  CPU核心数: $(sysctl -n hw.ncpu)"
    echo "  GPU: $(system_profiler SPDisplaysDataType 2>/dev/null | grep -m1 "Chipset Model" | awk -F': ' '{print $2}' || echo 'N/A')"
    echo ""
    echo "Python环境:"
    if command -v python3 &> /dev/null; then
        python3 -c "
import sys
print(f'  Python路径: {sys.executable}')
print(f'  Python版本: {sys.version.split()[0]}')
try:
    import mlx
    print(f'  MLX版本: {mlx.__version__}')
except ImportError:
    print('  MLX: 未安装')
" 2>/dev/null || echo "  Python环境检查失败"
    fi
    echo ""
    echo "网络连通性测试:"
    for url in "github.com" "huggingface.co" "pypi.org"; do
        if curl -s --head --max-time 3 "https://${url}" &> /dev/null; then
            log_success "${url}: 可达"
        else
            log_error "${url}: 不可达 (请检查网络代理)"
        fi
    done
    echo ""
    log_success "深度诊断完成"
}

# =============================================================================
# 部署功能
# =============================================================================
deploy_component() {
    local key="$1"
    IFS='|' read -r name repo_url port _ <<< "${COMPONENTS[$key]}"
    log_info "开始部署 ${name}..."
    mkdir -p "${INSTALL_DIR}" "${LOG_DIR}" "${BACKUP_DIR}"
    
    case "$key" in
        open-webui) deploy_open_webui "$repo_url" ;;
        sillytavern) deploy_sillytavern "$repo_url" ;;
        continue-dev) deploy_continue "$repo_url" ;;
        faas) deploy_faas "$repo_url" ;;
        browser-use) deploy_browser_use "$repo_url" ;;
        mlx) deploy_mlx "$repo_url" ;;
        comfyui) deploy_comfyui "$repo_url" ;;
        mlx-video) deploy_mlx_video "$repo_url" ;;
        *) log_error "未知组件: ${key}"; return 1 ;;
    esac
    log_success "${name} 部署完成"
}

setup_venv() {
    local dir="$1"
    local venv_python="${dir}/venv/bin/python"
    local venv_pip="${dir}/venv/bin/pip"
    if [ ! -f "$venv_python" ]; then
        log_info "创建 Python 虚拟环境..."
        python3 -m venv "${dir}/venv"
    fi
    # 仅输出路径，日志已重定向至 stderr
    echo "${venv_pip}"
}

deploy_open_webui() {
    local repo_url="$1" dir="${INSTALL_DIR}/open-webui"
    [ -d "${dir}" ] || { log_info "克隆 Open WebUI..."; git clone "${repo_url}" "${dir}"; }
    cd "${dir}"
    local pip=$(setup_venv "${dir}")
    "$pip" install -e . --quiet
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://localhost:11434} \
WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-$(openssl rand -hex 32)} \
python -m open_webui --host 0.0.0.0 --port 8080
EOF
    chmod +x start.sh
}

deploy_sillytavern() {
    local repo_url="$1" dir="${INSTALL_DIR}/sillytavern"
    [ -d "${dir}" ] || { log_info "克隆 SillyTavern..."; git clone "${repo_url}" "${dir}"; }
    cd "${dir}"
    npm install --quiet
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
node server.js --listen --port 8000
EOF
    chmod +x start.sh
}

deploy_continue() {
    local repo_url="$1" dir="${INSTALL_DIR}/continue-dev"
    [ -d "${dir}" ] || { log_info "克隆 Continue.dev..."; git clone "${repo_url}" "${dir}"; }
    cd "${dir}"
    npm install --quiet && npm run build --quiet
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
npm run dev -- --port 3000
EOF
    chmod +x start.sh
    log_warn "注意: Continue.dev 主要是 VS Code 扩展。独立服务器模式可能功能受限。"
}

deploy_faas() {
    local repo_url="$1" dir="${INSTALL_DIR}/faas"
    [ -d "${dir}" ] || { log_info "克隆 FaaS..."; git clone "${repo_url}" "${dir}"; }
    cd "${dir}"
    if ! command -v faas-cli &> /dev/null; then
        log_info "安装 faas-cli (需 sudo 权限)..."
        brew install openfaas/tap/faas-cli || { log_error "faas-cli 安装失败，请手动运行: brew install openfaas/tap/faas-cli"; return 1; }
    fi
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
faas-cli up --port 8081
EOF
    chmod +x start.sh
}

deploy_browser_use() {
    local repo_url="$1" dir="${INSTALL_DIR}/browser-use"
    [ -d "${dir}" ] || { log_info "克隆 Browser Use..."; git clone "${repo_url}" "${dir}"; }
    cd "${dir}"
    local pip=$(setup_venv "${dir}")
    "$pip" install -e . --quiet
    "$pip" install playwright --quiet
    ./venv/bin/playwright install --with-deps 2>/dev/null || true
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python -m browser_use.server --host 0.0.0.0 --port 8082
EOF
    chmod +x start.sh
}

deploy_mlx() {
    local repo_url="$1" dir="${INSTALL_DIR}/mlx"
    [ -d "${dir}" ] || { log_info "克隆 MLX..."; git clone "${repo_url}" "${dir}"; }
    cd "${dir}"
    local pip=$(setup_venv "${dir}")
    "$pip" install mlx mlx-examples --quiet
    log_info "MLX 部署完成 (本地计算框架，无服务端口)"
}

deploy_comfyui() {
    local repo_url="$1" dir="${INSTALL_DIR}/comfyui"
    [ -d "${dir}" ] || { log_info "克隆 ComfyUI..."; git clone "${repo_url}" "${dir}"; }
    cd "${dir}"
    local pip=$(setup_venv "${dir}")
    "$pip" install -r requirements.txt --quiet
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python main.py --listen --port 8188 --front-end-version Comfy-Org/ComfyUI_frontend@latest
EOF
    chmod +x start.sh
}

deploy_mlx_video() {
    local repo_url="$1" dir="${INSTALL_DIR}/mlx-video"
    [ -d "${dir}" ] || { log_info "克隆 MLX-Video..."; git clone "${repo_url}" "${dir}"; }
    cd "${dir}"
    local pip=$(setup_venv "${dir}")
    if [ -f "requirements.txt" ]; then
        "$pip" install -r requirements.txt --quiet
    else
        "$pip" install mlx --quiet
    fi
    log_info "MLX-Video 部署完成 (示例/本地库，无服务端口)"
}

# =============================================================================
# 服务管理
# =============================================================================
wait_for_service() {
    local port="$1"
    local retries=0 max_retries=20
    while (( retries < max_retries )); do
        if lsof -i :${port} -t &> /dev/null; then return 0; fi
        sleep 1
        ((retries++))
    done
    return 1
}

start_service() {
    local key="$1"
    IFS='|' read -r name _ port default_url <<< "${COMPONENTS[$key]}"
    log_info "启动 ${name}..."
    if [ ! -f "${INSTALL_DIR}/${key}/start.sh" ]; then
        log_error "${name} 未部署或启动脚本不存在"
        return 1
    fi
    cd "${INSTALL_DIR}/${key}"
    nohup ./start.sh > "${LOG_DIR}/${key}.log" 2>&1 &
    local pid=$!
    echo "$pid" > "${LOG_DIR}/${key}.pid"
    
    log_info "等待服务就绪 (最多 20s)..."
    if [ "$port" != "N/A" ]; then
        if wait_for_service "$port"; then
            log_success "${name} 已在端口 ${port} 启动"
            open "${default_url}" 2>/dev/null || true
        else
            log_error "${name} 启动超时，请查看日志: ${LOG_DIR}/${key}.log"
        fi
    else
        sleep 2
        log_success "${name} 已就绪 (本地库)"
    fi
}

stop_service() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    log_info "停止 ${name}..."
    if [ -f "${LOG_DIR}/${key}.pid" ]; then
        local pid
        read -r pid < "${LOG_DIR}/${key}.pid"
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
            pkill -P "$pid" 2>/dev/null || true
            local w=0
            while kill -0 "$pid" 2>/dev/null && (( w < 5 )); do sleep 1; ((w++)); done
            if kill -0 "$pid" 2>/dev/null; then kill -9 "$pid" 2>/dev/null || true; fi
            log_success "${name} 已停止 (PID: ${pid})"
        else
            log_warn "${name} 进程已不存在"
        fi
        rm -f "${LOG_DIR}/${key}.pid"
    else
        log_warn "${name} PID 文件不存在"
    fi
}

start_all_services() {
    log_info "启动所有已部署的服务..."
    for key in "${COMP_KEYS[@]}"; do
        [ -f "${INSTALL_DIR}/${key}/start.sh" ] && start_service "$key"
    done
}

stop_all_services() {
    log_info "停止所有运行中的服务..."
    for key in "${COMP_KEYS[@]}"; do
        [ -f "${LOG_DIR}/${key}.pid" ] && stop_service "$key"
    done
}

# =============================================================================
# 更新与回退
# =============================================================================
update_component() {
    local key="$1"
    IFS='|' read -r name repo_url _ _ <<< "${COMPONENTS[$key]}"
    log_info "更新 ${name}..."
    cd "${INSTALL_DIR}/${key}" || return 1
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    # 排除重型目录加速备份
    tar -czf "${BACKUP_DIR}/${key}_${timestamp}.tar.gz" \
        --exclude='venv' --exclude='node_modules' --exclude='__pycache__' --exclude='models' --exclude='*.pth' . 2>/dev/null || true
        
    if ! git pull --quiet origin main 2>/dev/null; then
        log_warn "git pull 失败，尝试拉取当前跟踪分支..."
        git pull --quiet 2>/dev/null || log_error "代码更新失败，请检查网络连接或本地修改"
    fi
    
    case "$key" in
        open-webui|browser-use|comfyui|mlx|mlx-video)
            ./venv/bin/pip install -e . --upgrade --quiet
            ;;
        sillytavern|continue-dev)
            npm install --quiet
            ;;
        faas)
            brew upgrade openfaas/tap/faas-cli 2>/dev/null || true
            ;;
    esac
    log_success "${name} 更新完成"
}

rollback_component() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    log_info "=== ${name} 版本回退 ==="
    shopt -s nullglob
    local backups=("${BACKUP_DIR}/${key}_"*.tar.gz)
    shopt -u nullglob
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_error "没有可用的备份版本"
        return 1
    fi
    
    echo "可用备份:"
    for i in "${!backups[@]}"; do
        echo "  $((i+1)). $(basename "${backups[$i]}")"
    done
    echo ""
    read -p "选择要回退的版本编号 (1-${#backups[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#backups[@]} )); then
        stop_service "$key"
        cd "${INSTALL_DIR}/${key}" || return 1
        # 清理现有文件再解压，避免旧文件残留
        rm -rf ./* ./.[!.]* 2>/dev/null || true
        tar -xzf "${backups[$((choice-1))]}"
        log_success "${name} 已回退到备份版本，请重新启动服务"
    else
        log_error "无效选择"
    fi
}

# =============================================================================
# 状态与卸载
# =============================================================================
show_status() {
    log_info "=== 组件状态 ==="
    echo ""
    printf "%-20s %-10s %-10s %-20s\n" "组件" "状态" "端口" "进程"
    printf "%-20s %-10s %-10s %-20s\n" "--------------------" "----------" "----------" "--------------------"
    for key in "${COMP_KEYS[@]}"; do
        IFS='|' read -r name _ port _ <<< "${COMPONENTS[$key]}"
        local status="未安装" pid_info="-"
        if [ -d "${INSTALL_DIR}/${key}" ]; then status="已安装"; fi
        if [ -f "${LOG_DIR}/${key}.pid" ]; then
            local pid
            read -r pid < "${LOG_DIR}/${key}.pid"
            if kill -0 "$pid" 2>/dev/null; then status="运行中"; pid_info="PID: ${pid}"
            else status="已停止"; fi
        fi
        printf "%-20s %-10s %-10s %-20s\n" "$name" "$status" "$port" "$pid_info"
    done
    echo ""
    echo "Python/Node 内存占用 (Top 5):"
    ps aux | awk '/[n]ode|[p]ython/ {cmd=""; for(i=11;i<=NF;i++) cmd=cmd" "$i; printf "  %-30s %6.1f MB\n", cmd, $6/1024}' | sort -k2 -rn | head -5
    echo ""
}

uninstall_component() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    log_warn "卸载 ${name} 将删除其所有数据（含模型/配置）。"
    read -p "确定继续？(yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then log_info "取消卸载"; return 0; fi
    
    log_info "正在卸载 ${name}..."
    stop_service "$key"
    rm -rf "${INSTALL_DIR}/${key}"
    rm -f "${LOG_DIR}/${key}."*
    log_success "${name} 已卸载"
}

uninstall_all() {
    log_warn "=== 警告：这将卸载所有组件并删除所有数据 ==="
    read -p "确定要继续吗？(yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
        stop_all_services
        for key in "${COMP_KEYS[@]}"; do uninstall_component "$key"; done
        rm -rf "${INSTALL_DIR}"
        log_success "所有组件已卸载"
    else
        log_info "取消卸载"
    fi
}

# =============================================================================
# 菜单系统
# =============================================================================
show_menu() {
    clear
    echo "=================================================="
    echo "         AI Studio Manager v${SCRIPT_VERSION}"
    echo "=================================================="
    echo ""
    echo "📦 部署管理:   1.首次部署(全)   2.选择性部署"
    echo "🚀 服务管理:   3.启动全部       4.停止全部"
    echo "               5.启动单个       6.停止单个"
    echo "📊 状态诊断:   7.查看状态       8.简单诊断"
    echo "               9.深度诊断"
    echo "🔄 更新管理:  10.更新全部      11.更新前端"
    echo "              12.更新 Agent    13.更新模型"
    echo "              14.版本回退"
    echo "🗑️  清理:     15.卸载单个      16.完全卸载"
    echo "              0.退出"
    echo "=================================================="
    echo ""
}

select_component() {
    echo "可用组件:"
    for i in "${!COMP_KEYS[@]}"; do
        local key="${COMP_KEYS[$i]}"
        IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
        echo "  $((i+1)). ${name}"
    done
    echo ""
    read -p "选择组件编号: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#COMP_KEYS[@]} )); then
        echo "${COMP_KEYS[$((choice-1))]}"
    fi
}

main() {
    while true; do
        show_menu
        read -p "请选择操作 [0-16]: " choice
        case "$choice" in
            1) check_dependencies "--ignore-missing"; for k in "${COMP_KEYS[@]}"; do deploy_component "$k"; done; log_success "首次部署完成！" ;;
            2) local k=$(select_component); [ -n "$k" ] && { check_dependencies "--ignore-missing"; deploy_component "$k"; } || log_error "无效选择" ;;
            3) start_all_services ;;
            4) stop_all_services ;;
            5) local k=$(select_component); [ -n "$k" ] && start_service "$k" || log_error "无效选择" ;;
            6) local k=$(select_component); [ -n "$k" ] && stop_service "$k" || log_error "无效选择" ;;
            7) show_status ;;
            8) diagnose_simple ;;
            9) diagnose_deep ;;
            10) for k in "${COMP_KEYS[@]}"; do [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k"; done ;;
            11) for k in open-webui sillytavern continue-dev comfyui; do [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k"; done ;;
            12) for k in browser-use faas mlx; do [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k"; done ;;
            13) for k in mlx mlx-video comfyui; do [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k"; done ;;
            14) local k=$(select_component); [ -n "$k" ] && rollback_component "$k" || log_error "无效选择" ;;
            15) local k=$(select_component); [ -n "$k" ] && uninstall_component "$k" || log_error "无效选择" ;;
            16) uninstall_all ;;
            0) log_info "退出 AI Studio Manager"; exit 0 ;;
            *) log_error "无效选项，请重新选择" ;;
        esac
        echo ""
        read -p "按回车键继续..." -r
    done
}

# CLI 入口
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "用法: $0 [选项]"
    echo "选项: --deploy-all | --start-all | --stop-all | --status | --diagnose-simple | --diagnose-deep"
    exit 0
elif [[ "${1:-}" == "--deploy-all" ]]; then check_dependencies "--ignore-missing"; for k in "${COMP_KEYS[@]}"; do deploy_component "$k"; done
elif [[ "${1:-}" == "--start-all" ]]; then start_all_services
elif [[ "${1:-}" == "--stop-all" ]]; then stop_all_services
elif [[ "${1:-}" == "--status" ]]; then show_status
elif [[ "${1:-}" == "--diagnose-simple" ]]; then diagnose_simple
elif [[ "${1:-}" == "--diagnose-deep" ]]; then diagnose_deep
else
    main
fi
