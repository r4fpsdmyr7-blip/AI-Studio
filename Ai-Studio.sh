#!/usr/bin/env bash
# =============================================================================
# AI Studio Manager for macOS (Production Ready)
# =============================================================================
# 功能：管理 Open WebUI, SillyTavern, Continue.dev, FaaS, Browser Use,
#       MLX, ComfyUI (SDXL/FLUX), MLX-Video 的部署、更新、诊断与卸载
# 作者：AI Assistant
# 日期：2026-06-01
# 版本：1.3.0 (Production Ready - All Critical Fixes Applied)
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

readonly SCRIPT_VERSION="1.3.0"
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

# 全局变量：用于 setup_venv 返回路径（避免 echo 污染输出）
VENV_PIP=""
VENV_PYTHON=""

# =============================================================================
# 工具函数
# =============================================================================
log_info()    { echo -e "\033[0;34m[INFO]\033[0m $1" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1" >&2; }
log_warn()    { echo -e "\033[0;33m[WARN]\033[0m $1" >&2; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

# 安全执行命令，带重试
safe_exec() {
    local cmd="$1"
    local retries="${2:-3}"
    local delay="${3:-2}"
    
    for ((i=1; i<=retries; i++)); do
        if eval "$cmd" &>/dev/null; then
            return 0
        fi
        if (( i < retries )); then
            sleep "$delay"
        fi
    done
    return 1
}

check_dependencies() {
    log_info "检查系统依赖..."
    local deps=("git" "python3" "node" "npm" "curl" "brew")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
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
    echo "依赖检查:"
    local deps=("brew" "git" "python3" "node" "docker")
    for dep in "${deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            if [[ "$dep" == "docker" ]]; then
                if docker info &>/dev/null 2>&1; then
                    log_success "$dep: 运行中"
                else
                    log_warn "$dep: 已安装但未运行 (请启动 Docker Desktop)"
                fi
            else
                local ver
                ver=$("$dep" --version 2>/dev/null | head -1 || echo "Installed")
                log_success "$dep: $ver"
            fi
        else
            log_error "$dep: 未安装"
        fi
    done
    echo ""
    echo "组件安装状态:"
    for key in "${COMP_KEYS[@]}"; do
        IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
        if [ -d "${INSTALL_DIR}/${key}" ]; then
            log_success "${name}: 已安装"
        else
            log_warn "${name}: 未安装"
        fi
    done
    echo ""
    echo "端口占用情况:"
    local ports=(8080 8000 3000 8081 8082 8188)
    for port in "${ports[@]}"; do
        if command -v lsof &>/dev/null && lsof -i :${port} -t &>/dev/null; then
            local pid
            pid=$(lsof -i :${port} -t 2>/dev/null | head -1)
            log_warn "端口 ${port} 被占用 (PID: ${pid:-unknown})"
        else
            log_success "端口 ${port} 空闲"
        fi
    done
    echo ""
    echo "磁盘空间:"
    df -h / 2>/dev/null | awk 'NR==2 {printf "可用空间: %s (已用 %s)\n", $4, $5}'
    echo ""
    log_success "简单诊断完成"
}

diagnose_deep() {
    log_info "=== 深度诊断 ==="
    diagnose_simple
    
    echo "详细系统信息:"
    echo "  CPU核心数: $(sysctl -n hw.ncpu 2>/dev/null || echo 'N/A')"
    echo "  GPU: $(system_profiler SPDisplaysDataType 2>/dev/null | grep -m1 "Chipset Model" | awk -F': ' '{print $2}' || echo 'N/A')"
    echo ""
    
    echo "Python环境:"
    if command -v python3 &> /dev/null; then
        python3 -c "
import sys, platform
print(f'  Python路径: {sys.executable}')
print(f'  Python版本: {sys.version.split()[0]}')
print(f'  平台: {platform.machine()}')
try:
    import mlx
    print(f'  MLX版本: {mlx.__version__}')
except ImportError:
    print('  MLX: 未安装 (可用: pip install mlx)')
" 2>/dev/null || echo "  Python环境检查失败"
    else
        log_error "python3 未安装"
    fi
    echo ""
    
    echo "Node.js环境:"
    if command -v node &> /dev/null; then
        echo "  Node版本: $(node --version 2>/dev/null)"
        echo "  NPM版本: $(npm --version 2>/dev/null)"
    else
        log_error "node 未安装"
    fi
    echo ""
    
    echo "网络连通性测试:"
    for url in "github.com" "huggingface.co" "pypi.org"; do
        if curl -sI --max-time 5 --retry 2 "https://${url}" &>/dev/null; then
            log_success "${url}: 可达 (HTTPS)"
        elif curl -sI --max-time 3 "http://${url}" &>/dev/null; then
            log_warn "${url}: 仅 HTTP 可达 (建议检查 HTTPS/代理设置)"
        else
            log_error "${url}: 不可达 (检查: ping ${url} / 代理 / 防火墙)"
        fi
    done
    echo ""
    
    echo "Docker状态 (如使用 OpenFaaS):"
    if command -v docker &>/dev/null; then
        if docker info &>/dev/null 2>&1; then
            log_success "Docker: 运行正常"
            echo "  版本: $(docker --version 2>/dev/null | head -1)"
        else
            log_warn "Docker: 已安装但未运行 (请启动 Docker Desktop)"
        fi
    else
        log_warn "Docker: 未安装 (OpenFaaS 需要)"
    fi
    echo ""
    
    log_success "深度诊断完成"
}

# =============================================================================
# 虚拟环境管理 (修复: 使用全局变量替代 echo 返回)
# =============================================================================
setup_venv() {
    local dir="$1"
    local venv_python="${dir}/venv/bin/python"
    
    if [ ! -f "$venv_python" ]; then
        log_info "创建 Python 虚拟环境: ${dir}/venv"
        if ! python3 -m venv "${dir}/venv" 2>&1; then
            log_error "虚拟环境创建失败"
            log_info "尝试修复: python3 -m pip install --user --upgrade pip setuptools venv"
            return 1
        fi
        # 升级 pip
        "${dir}/venv/bin/pip" install --upgrade pip setuptools wheel &>/dev/null || true
    fi
    
    # 通过全局变量返回路径 (避免 echo 污染输出)
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
    chmod 700 "${INSTALL_DIR}" "${LOG_DIR}" "${BACKUP_DIR}" 2>/dev/null || true
    
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

deploy_open_webui() {
    local repo_url="$1" dir="${INSTALL_DIR}/open-webui"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 Open WebUI..."
        git clone --depth 1 "${repo_url}" "${dir}" || { log_error "克隆失败"; return 1; }
    fi
    
    cd "${dir}" || return 1
    
    # 创建/加载持久化配置
    local config_file="${dir}/.ai-studio.env"
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
# AI Studio 管理的配置，勿手动修改
WEBUI_SECRET_KEY=
OLLAMA_BASE_URL=http://localhost:11434
EOF
        # 生成安全密钥
        local secret_key
        secret_key=$(openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")
        sed -i.bak "s|^WEBUI_SECRET_KEY=.*|WEBUI_SECRET_KEY=${secret_key}|" "$config_file"
        rm -f "${config_file}.bak"
        chmod 600 "$config_file"
    fi
    
    # 设置虚拟环境
    if ! setup_venv "${dir}"; then return 1; fi
    
    log_info "安装 Open WebUI 依赖..."
    if ! "$VENV_PIP" install -e . --quiet 2>&1; then
        log_warn "pip install 警告 (可能已安装)"
    fi
    
    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate

# 加载持久化配置
if [[ -f ".ai-studio.env" ]]; then
    set -a
    source .ai-studio.env
    set +a
fi

# 确保密钥存在
if [[ -z "${WEBUI_SECRET_KEY}" ]]; then
    export WEBUI_SECRET_KEY=$(openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")
fi

exec python -m open_webui --host 0.0.0.0 --port 8080
EOF
    chmod +x start.sh
}

deploy_sillytavern() {
    local repo_url="$1" dir="${INSTALL_DIR}/sillytavern"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 SillyTavern..."
        git clone --depth 1 "${repo_url}" "${dir}" || { log_error "克隆失败"; return 1; }
    fi
    
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
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 Continue.dev..."
        git clone --depth 1 "${repo_url}" "${dir}" || { log_error "克隆失败"; return 1; }
    fi
    
    cd "${dir}" || return 1
    
    log_info "安装 Node.js 依赖并构建..."
    npm install --silent 2>/dev/null || npm install
    npm run build --silent 2>/dev/null || npm run build || log_warn "构建警告 (可能已构建)"
    
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
exec npm run dev -- --port 3000
EOF
    chmod +x start.sh
    log_warn "注意: Continue.dev 主要是 VS Code 扩展。独立服务器模式功能可能受限。"
}

deploy_faas() {
    local repo_url="$1" dir="${INSTALL_DIR}/faas"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 OpenFaaS..."
        git clone --depth 1 "${repo_url}" "${dir}" || { log_error "克隆失败"; return 1; }
    fi
    
    cd "${dir}" || return 1
    
    # 检查 Docker
    if ! command -v docker &>/dev/null || ! docker info &>/dev/null 2>&1; then
        log_warn "OpenFaaS 需要 Docker 运行环境。请确保 Docker Desktop 已启动。"
    fi
    
    # 安装 faas-cli
    if ! command -v faas-cli &>/dev/null; then
        log_info "安装 faas-cli..."
        if ! brew install openfaas/tap/faas-cli 2>&1; then
            log_error "faas-cli 安装失败，请手动安装: https://docs.openfaas.com/cli/install/"
            return 1
        fi
    fi
    
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
# 注意: 需确保目录内存在有效的 stack.yml 文件
# 首次运行建议: faas-cli template pull && faas-cli build && faas-cli deploy
exec faas-cli up --port 8081 2>&1
EOF
    chmod +x start.sh
}

deploy_browser_use() {
    local repo_url="$1" dir="${INSTALL_DIR}/browser-use"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 Browser Use..."
        git clone --depth 1 "${repo_url}" "${dir}" || { log_error "克隆失败"; return 1; }
    fi
    
    cd "${dir}" || return 1
    
    if ! setup_venv "${dir}"; then return 1; fi
    
    log_info "安装 Browser Use 依赖..."
    "$VENV_PIP" install -e . --quiet 2>&1 || log_warn "pip install 警告"
    "$VENV_PIP" install playwright --quiet 2>&1
    
    log_info "安装 Playwright 浏览器..."
    ./venv/bin/playwright install --with-deps chromium 2>/dev/null || \
    ./venv/bin/playwright install chromium 2>/dev/null || true
    
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
# 尝试多种启动方式
if [[ -f "browser_use/server.py" ]]; then
    exec python -m browser_use.server --host 0.0.0.0 --port 8082
elif [[ -f "main.py" ]]; then
    exec python main.py --port 8082
else
    echo "错误: 未找到可执行入口" >&2
    exit 1
fi
EOF
    chmod +x start.sh
}

deploy_mlx() {
    local repo_url="$1" dir="${INSTALL_DIR}/mlx"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 MLX..."
        git clone --depth 1 "${repo_url}" "${dir}" || { log_error "克隆失败"; return 1; }
    fi
    
    cd "${dir}" || return 1
    
    if ! setup_venv "${dir}"; then return 1; fi
    
    log_info "安装 MLX 及示例..."
    "$VENV_PIP" install mlx mlx-examples --quiet 2>&1 || log_warn "MLX 安装警告"
    
    log_info "MLX 部署完成 (本地计算框架，无服务端口)"
    log_info "使用示例: cd ${dir} && source venv/bin/activate && python -m mlx.examples.llama"
}

deploy_comfyui() {
    local repo_url="$1" dir="${INSTALL_DIR}/comfyui"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 ComfyUI..."
        git clone --depth 1 "${repo_url}" "${dir}" || { log_error "克隆失败"; return 1; }
    fi
    
    cd "${dir}" || return 1
    
    if ! setup_venv "${dir}"; then return 1; fi
    
    log_info "安装 ComfyUI 依赖..."
    if [[ -f "requirements.txt" ]]; then
        "$VENV_PIP" install -r requirements.txt --quiet 2>&1 || log_warn "依赖安装警告"
    fi
    
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
exec python main.py --listen --port 8188 --front-end-version Comfy-Org/ComfyUI_frontend@latest
EOF
    chmod +x start.sh
    
    log_info "ComfyUI 部署完成"
    log_info "首次启动后请访问: http://localhost:8188 安装自定义节点"
}

deploy_mlx_video() {
    local repo_url="$1" dir="${INSTALL_DIR}/mlx-video"
    
    if [ ! -d "${dir}" ]; then
        log_info "克隆 MLX-Video..."
        git clone --depth 1 "${repo_url}" "${dir}" || { log_error "克隆失败"; return 1; }
    fi
    
    cd "${dir}" || return 1
    
    if ! setup_venv "${dir}"; then return 1; fi
    
    if [[ -f "requirements.txt" ]]; then
        log_info "安装 MLX-Video 依赖..."
        "$VENV_PIP" install -r requirements.txt --quiet 2>&1 || log_warn "依赖安装警告"
    else
        "$VENV_PIP" install mlx --quiet 2>&1
    fi
    
    log_info "MLX-Video 部署完成 (示例/本地库，无服务端口)"
    log_info "查看 README.md 获取使用示例"
}

# =============================================================================
# 服务管理 (修复: 日志追加 + 安全进程管理)
# =============================================================================
wait_for_service() {
    local port="$1"
    local retries=0 max_retries=20
    
    while (( retries < max_retries )); do
        # 优先使用 HTTP 状态码检测 (严格匹配)
        if command -v curl &>/dev/null; then
            local http_code
            http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "http://localhost:${port}" 2>/dev/null)
            if [[ "$http_code" =~ ^(200|301|302|303|307|401|403|404)$ ]]; then
                return 0
            fi
        fi
        
        # 降级: 检查端口监听 (需额外等待确保服务就绪)
        if command -v lsof &>/dev/null && lsof -i :${port} -t &>/dev/null; then
            sleep 2
            return 0
        fi
        
        sleep 1
        ((retries++))
    done
    return 1
}

start_service() {
    local key="$1"
    IFS='|' read -r name _ port default_url <<< "${COMPONENTS[$key]}"
    log_info "启动 ${name}..."
    
    # N/A 端口组件跳过 start.sh 检查
    if [ "$port" != "N/A" ] && [ ! -f "${INSTALL_DIR}/${key}/start.sh" ]; then
        log_error "${name} 未部署或启动脚本不存在"
        return 1
    fi

    if [ "$port" != "N/A" ]; then
        cd "${INSTALL_DIR}/${key}" || return 1
        
        # 日志轮转: 超过 10MB 自动备份
        local log_file="${LOG_DIR}/${key}.log"
        if [[ -f "$log_file" ]]; then
            local log_size
            if [[ "$OSTYPE" == "darwin"* ]]; then
                log_size=$(stat -f%z "$log_file" 2>/dev/null || echo 0)
            else
                log_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
            fi
            if (( log_size > 10485760 )); then
                mv "$log_file" "${log_file}.$(date +%Y%m%d%H%M%S).bak"
                log_info "日志轮转: $(basename "${log_file}.bak")"
            fi
        fi
        
        # 使用追加模式启动
        nohup ./start.sh >> "${LOG_DIR}/${key}.log" 2>&1 &
        local pid=$!
        echo "$pid" > "${LOG_DIR}/${key}.pid"
        
        log_info "等待服务就绪 (最多 20s)..."
        if wait_for_service "$port"; then
            log_success "${name} 已在端口 ${port} 启动 (PID: ${pid})"
            # 尝试打开浏览器 (macOS)
            if command -v open &>/dev/null; then
                open "${default_url}" 2>/dev/null || true
            fi
        else
            log_error "${name} 启动超时，请查看日志: ${LOG_DIR}/${key}.log"
            log_warn "调试: tail -50 ${LOG_DIR}/${key}.log"
        fi
    else
        log_info "${name} 为本地计算框架/示例库，无需启动后台服务。"
        log_info "请进入 ${INSTALL_DIR}/${key} 参考官方文档运行示例。"
    fi
}

stop_service() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    log_info "停止 ${name}..."
    
    local pid_file="${LOG_DIR}/${key}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid
        read -r pid < "$pid_file" 2>/dev/null || pid=""
        
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            # 验证进程是否属于预期组件
            local cmd
            cmd=$(ps -p "$pid" -o command= 2>/dev/null || echo "")
            if [[ -n "$cmd" ]] && [[ "$cmd" != *"${key}"* ]] && [[ "$cmd" != *"start.sh"* ]] && [[ "$cmd" != *"${name}"* ]]; then
                log_warn "PID $pid 命令: $cmd"
                log_warn "可能不属于 ${name}，谨慎终止"
            fi
            
            # 优雅终止
            log_info "发送 TERM 信号到 PID ${pid}..."
            kill -TERM "$pid" 2>/dev/null || true
            
            # 等待进程退出 (最多 10 秒)
            local w=0
            while kill -0 "$pid" 2>/dev/null && (( w < 10 )); do
                sleep 1
                ((w++))
            done
            
            # 强制终止 (如必要)
            if kill -0 "$pid" 2>/dev/null; then
                log_warn "${name} 未响应 TERM，发送 KILL"
                kill -9 "$pid" 2>/dev/null || true
                sleep 1
            fi
            
            log_success "${name} 已停止 (PID: ${pid})"
        else
            log_warn "${name} 进程已不存在 (PID: ${pid:-unknown})"
        fi
        rm -f "$pid_file"
    else
        # 备用方案: 通过端口查找进程
        local port
        IFS='|' read -r _ _ port _ <<< "${COMPONENTS[$key]}"
        if [[ "$port" != "N/A" ]] && command -v lsof &>/dev/null; then
            local pid_by_port
            pid_by_port=$(lsof -t -i :${port} 2>/dev/null | head -1)
            if [[ -n "$pid_by_port" ]]; then
                log_info "通过端口 ${port} 找到进程 ${pid_by_port}，尝试终止"
                kill -TERM "$pid_by_port" 2>/dev/null || true
                sleep 2
                kill -9 "$pid_by_port" 2>/dev/null || true
                log_success "${name} 已通过端口检测停止"
            else
                log_warn "${name} 未找到运行进程 (无 PID 文件且端口 ${port} 空闲)"
            fi
        else
            log_warn "${name} PID 文件不存在，且无法通过端口检测"
        fi
    fi
}

start_all_services() {
    log_info "启动所有已部署的服务..."
    local started=0
    for key in "${COMP_KEYS[@]}"; do
        if [ -d "${INSTALL_DIR}/${key}" ] && [ -f "${INSTALL_DIR}/${key}/start.sh" ]; then
            start_service "$key" && ((started++))
        fi
    done
    log_success "启动完成: ${started} 个服务"
}

stop_all_services() {
    log_info "停止所有运行中的服务..."
    local stopped=0
    for key in "${COMP_KEYS[@]}"; do
        if [ -f "${LOG_DIR}/${key}.pid" ] || { IFS='|' read -r _ _ port _ <<< "${COMPONENTS[$key]}"; [[ "$port" != "N/A" ]]; }; then
            stop_service "$key" && ((stopped++))
        fi
    done
    log_success "停止完成: ${stopped} 个服务"
}

# =============================================================================
# 更新与回退 (修复: 备份增强 + 错误处理)
# =============================================================================
update_component() {
    local key="$1"
    IFS='|' read -r name repo_url _ _ <<< "${COMPONENTS[$key]}"
    log_info "更新 ${name}..."
    
    local dir="${INSTALL_DIR}/${key}"
    cd "$dir" || { log_error "目录不存在: $dir"; return 1; }
    
    # 处理脏工作区
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warn "发现未提交的修改，自动暂存..."
        git stash push -m "ai-studio-auto-$(date +%s)" --quiet 2>/dev/null || \
        log_warn "git stash 失败，可能无权限或冲突"
    fi

    # 创建更新前备份
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${key}_pre-update_${timestamp}.tar.gz"
    log_info "创建备份: $(basename "$backup_file")"
    
    tar -czf "$backup_file" \
        --exclude='venv' --exclude='node_modules' --exclude='__pycache__' \
        --exclude='models' --exclude='*.pth' --exclude='*.ckpt' --exclude='*.safetensors' \
        -C "${INSTALL_DIR}" "${key}" 2>/dev/null || \
        log_warn "备份创建警告 (可能文件过大)"
    
    # 拉取最新代码
    log_info "拉取最新代码..."
    if ! git pull --quiet origin main 2>/dev/null && \
       ! git pull --quiet origin master 2>/dev/null && \
       ! git pull --quiet 2>/dev/null; then
        log_error "代码更新失败，请检查网络连接或本地修改"
        return 1
    fi

    # 更新依赖
    case "$key" in
        open-webui|browser-use|comfyui|mlx|mlx-video)
            if [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
                log_info "更新 Python 依赖..."
                if ! setup_venv "$dir"; then
                    log_warn "虚拟环境异常，尝试重新创建"
                    rm -rf "${dir}/venv"
                    setup_venv "$dir" || { log_error "虚拟环境修复失败"; return 1; }
                fi
                "$VENV_PIP" install -e . --upgrade --quiet 2>&1 || log_warn "pip upgrade 警告"
            fi
            ;;
        sillytavern|continue-dev)
            log_info "更新 Node.js 依赖..."
            npm install --silent 2>/dev/null || npm install || log_warn "npm install 警告"
            ;;
        faas)
            log_info "更新 faas-cli (如通过 brew 安装)..."
            brew upgrade openfaas/tap/faas-cli 2>/dev/null || true
            ;;
    esac
    
    log_success "${name} 更新完成"
    log_info "建议重启服务以应用更新: ./ai-studio.sh --stop-all && ./ai-studio.sh --start-all"
}

create_backup() {
    local key="$1"
    local dir="${INSTALL_DIR}/${key}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${key}_manual_${timestamp}.tar.gz"
    
    log_info "创建手动备份: $(basename "$backup_file")"
    tar -czf "$backup_file" \
        --exclude='venv' --exclude='node_modules' --exclude='__pycache__' \
        --exclude='models' --exclude='*.pth' --exclude='*.ckpt' --exclude='*.safetensors' \
        -C "${INSTALL_DIR}" "${key}" 2>/dev/null && \
        log_success "备份完成: $backup_file" || \
        log_error "备份失败"
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
        log_info "提示: 更新操作会自动创建备份，也可手动创建: ./ai-studio.sh 选择组件后使用备份功能"
        return 1
    fi
    
    echo "可用备份 (按时间倒序):"
    # 按文件名排序 (时间戳)
    local sorted_backups
    mapfile -t sorted_backups < <(printf '%s\n' "${backups[@]}" | sort -r)
    
    for i in "${!sorted_backups[@]}"; do
        local bname
        bname=$(basename "${sorted_backups[$i]}")
        echo "  $((i+1)). ${bname}"
    done
    echo ""
    
    read -p "选择要回退的版本编号 (1-${#sorted_backups[@]}, 回车取消): " choice
    if [[ -z "$choice" ]]; then
        log_info "取消回退"
        return 0
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#sorted_backups[@]} )); then
        # ⚠️ 回滚前先备份当前状态
        local pre_rollback="${BACKUP_DIR}/${key}_pre-rollback_$(date +%Y%m%d_%H%M%S).tar.gz"
        log_info "创建回滚前备份: $(basename "$pre_rollback")"
        tar -czf "$pre_rollback" \
            --exclude='venv' --exclude='node_modules' --exclude='__pycache__' \
            --exclude='models' --exclude='*.pth' \
            -C "${INSTALL_DIR}" "${key}" 2>/dev/null || true
        
        stop_service "$key"
        
        local target_dir="${INSTALL_DIR}/${key}"
        cd "$target_dir" || return 1
        
        # 安全清理: 保留 .git 和配置文件
        log_info "清理当前文件 (保留 .git 和配置)..."
        find . -mindepth 1 -maxdepth 1 \
            -not -name '.git' -not -name '.gitignore' \
            -not -name '.ai-studio.env' -not -name 'start.sh' \
            -exec rm -rf {} + 2>/dev/null || true
        
        # 解压备份
        log_info "恢复备份文件..."
        tar -xzf "${sorted_backups[$((choice-1))]}" -C "$target_dir" || {
            log_error "解压失败"
            return 1
        }
        
        log_success "${name} 已回退到备份版本"
        log_info "请重新启动服务: ./ai-studio.sh --start-single 选择 ${name}"
    else
        log_error "无效选择"
        return 1
    fi
}

# =============================================================================
# 状态与卸载 (修复: 安全确认 + macOS 兼容)
# =============================================================================
show_status() {
    log_info "=== 组件状态 ==="
    echo ""
    printf "%-20s %-10s %-10s %-15s\n" "组件" "状态" "端口" "进程"
    printf "%-20s %-10s %-10s %-15s\n" "--------------------" "----------" "----------" "---------------"
    
    for key in "${COMP_KEYS[@]}"; do
        IFS='|' read -r name _ port _ <<< "${COMPONENTS[$key]}"
        local status="未安装" pid_info="-"
        
        if [ -d "${INSTALL_DIR}/${key}" ]; then 
            status="已安装"
        fi
        
        if [ -f "${LOG_DIR}/${key}.pid" ]; then
            local pid
            read -r pid < "${LOG_DIR}/${key}.pid" 2>/dev/null || pid=""
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then 
                status="运行中"
                pid_info="PID:${pid}"
            else 
                status="已停止"
            fi
        elif [[ "$port" != "N/A" ]] && command -v lsof &>/dev/null && lsof -i :${port} -t &>/dev/null; then
            status="运行中 (检测)"
            pid_info="端口:${port}"
        fi
        
        printf "%-20s %-10s %-10s %-15s\n" "$name" "$status" "$port" "$pid_info"
    done
    echo ""
    
    echo "Python/Node 进程内存占用 (Top 5):"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: ps -eo pid,rss,command
        ps -eo pid,rss,command 2>/dev/null | \
            grep -E '[n]ode|[p]ython' | \
            grep -v 'grep' | \
            awk '{
                rss_mb = $2 / 1024;
                cmd = "";
                for(i=3; i<=NF; i++) cmd = cmd " " $i;
                if (length(cmd) > 40) cmd = substr(cmd, 1, 37) "...";
                printf "  %-40s %7.1f MB\n", cmd, rss_mb
            }' | sort -k2 -rn | head -5
    else
        # Linux 备用
        ps aux --sort=-%mem 2>/dev/null | \
            grep -E '[n]ode|[p]ython' | \
            grep -v 'grep' | \
            awk '{
                cmd = "";
                for(i=11; i<=NF; i++) cmd = cmd " " $i;
                if (length(cmd) > 40) cmd = substr(cmd, 1, 37) "...";
                printf "  %-40s %7.1f MB\n", cmd, $6/1024
            }' | head -5
    fi
    echo ""
    
    # 磁盘使用概览
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "AI Studio 目录大小:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            du -sh "${INSTALL_DIR}" 2>/dev/null | awk '{print "  " $1 " - " $2}'
        else
            du -sh "${INSTALL_DIR}" 2>/dev/null
        fi
    fi
    echo ""
}

uninstall_component() {
    local key="$1"
    IFS='|' read -r name _ _ _ <<< "${COMPONENTS[$key]}"
    
    log_warn "⚠️  卸载 ${name} 将删除:"
    echo "   - 代码: ${INSTALL_DIR}/${key}"
    echo "   - 日志: ${LOG_DIR}/${key}.*"
    echo "   - ⚠️  模型/配置/数据 (如未单独备份)"
    echo ""
    
    read -p "确定继续卸载 ${name}? (输入 yes 确认): " confirm
    if [[ "$confirm" != "yes" ]]; then 
        log_info "取消卸载"
        return 0
    fi
    
    # 额外备份确认
    read -p "是否先备份数据到 ${BACKUP_DIR}? (yes/no): " backup_confirm
    if [[ "$backup_confirm" == "yes" ]]; then
        create_backup "$key"
    fi
    
    log_info "正在卸载 ${name}..."
    stop_service "$key"
    
    # 安全删除
    rm -rf "${INSTALL_DIR}/${key}"
    rm -f "${LOG_DIR}/${key}.log"* "${LOG_DIR}/${key}.pid"
    
    log_success "${name} 已卸载"
}

uninstall_all() {
    log_warn "=== ⚠️  警告：完全卸载 ==="
    echo "这将删除:"
    echo "  - 所有组件代码: ${INSTALL_DIR}/*"
    echo "  - 所有日志: ${LOG_DIR}/*"
    echo "  - ⚠️  所有模型/配置/用户数据 (除非已备份)"
    echo ""
    
    read -p "确定要继续完全卸载? (输入 yes 确认): " confirm
    if [[ "$confirm" == "yes" ]]; then
        # 创建完整备份选项
        read -p "是否先创建完整备份到 ${BACKUP_DIR}? (yes/no): " full_backup
        if [[ "$full_backup" == "yes" ]]; then
            log_info "创建完整备份 (可能较大)..."
            mkdir -p "${BACKUP_DIR}"
            tar -czf "${BACKUP_DIR}/ai-studio-full_$(date +%Y%m%d_%H%M%S).tar.gz" \
                -C "${HOME}" "$(basename "${INSTALL_DIR}")" 2>/dev/null && \
                log_success "完整备份完成" || \
                log_warn "备份失败 (可能空间不足)"
        fi
        
        stop_all_services
        for key in "${COMP_KEYS[@]}"; do
            uninstall_component "$key" 2>/dev/null || true
        done
        rm -rf "${INSTALL_DIR}"
        log_success "✅ 所有组件已完全卸载"
        log_info "如需重新安装: 运行此脚本选择 '首次部署'"
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

select_component() {
    echo "可用组件列表:"
    echo "--------------------------------------------------"
    for i in "${!COMP_KEYS[@]}"; do
        local key="${COMP_KEYS[$i]}"
        IFS='|' read -r name repo port url <<< "${COMPONENTS[$key]}"
        printf "  %2d. %-15s 端口:%-6s  %s\n" "$((i+1))" "$name" "$port" "$url"
    done
    echo "--------------------------------------------------"
    echo ""
    read -p "选择组件编号 (1-${#COMP_KEYS[@]}, 回车取消): " choice
    
    if [[ -z "$choice" ]]; then
        return 1
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#COMP_KEYS[@]} )); then
        echo "${COMP_KEYS[$((choice-1))]}"
        return 0
    else
        log_error "无效选择"
        return 1
    fi
}

main() {
    while true; do
        show_menu
        read -p "请选择操作 [0-16]: " choice
        
        case "$choice" in
            1)
                check_dependencies "--ignore-missing"
                local success=0 failed=0
                for k in "${COMP_KEYS[@]}"; do
                    if deploy_component "$k"; then
                        ((success++))
                    else
                        ((failed++))
                        log_warn "${k} 部署失败，继续下一个..."
                    fi
                done
                log_success "部署完成: 成功 ${success}, 失败 ${failed}"
                ;;
            2)
                local k
                k=$(select_component) || { log_error "无效选择"; break; }
                check_dependencies "--ignore-missing"
                deploy_component "$k"
                ;;
            3) start_all_services ;;
            4) stop_all_services ;;
            5)
                local k
                k=$(select_component) || { log_error "无效选择"; break; }
                start_service "$k"
                ;;
            6)
                local k
                k=$(select_component) || { log_error "无效选择"; break; }
                stop_service "$k"
                ;;
            7) show_status ;;
            8) diagnose_simple ;;
            9) diagnose_deep ;;
            10)
                log_info "批量更新全部组件..."
                for k in "${COMP_KEYS[@]}"; do
                    [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k" || true
                done
                ;;
            11)
                log_info "更新前端组件..."
                for k in open-webui sillytavern continue-dev comfyui; do
                    [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k" || true
                done
                ;;
            12)
                log_info "更新 Agent 组件..."
                for k in browser-use faas mlx; do
                    [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k" || true
                done
                ;;
            13)
                log_info "更新模型组件..."
                for k in mlx mlx-video comfyui; do
                    [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k" || true
                done
                ;;
            14)
                local k
                k=$(select_component) || { log_error "无效选择"; break; }
                rollback_component "$k"
                ;;
            15)
                local k
                k=$(select_component) || { log_error "无效选择"; break; }
                uninstall_component "$k"
                ;;
            16) uninstall_all ;;
            0)
                log_info "👋 退出 AI Studio Manager"
                exit 0
                ;;
            *)
                log_error "无效选项，请输入 0-16"
                ;;
        esac
        
        echo ""
        read -p "✅ 按回车键继续..." -r
    done
}

# =============================================================================
# CLI 入口
# =============================================================================
case "${1:-}" in
    --help|-h)
        echo "AI Studio Manager v${SCRIPT_VERSION} - macOS AI 开发环境管理工具"
        echo ""
        echo "用法: $0 [选项]"
        echo ""
        echo "交互模式 (默认):"
        echo "  $0                    # 启动菜单界面"
        echo ""
        echo "命令行模式:"
        echo "  --deploy-all          # 部署全部组件"
        echo "  --start-all           # 启动全部服务"
        echo "  --stop-all            # 停止全部服务"
        echo "  --status              # 查看组件状态"
        echo "  --diagnose-simple     # 简单系统诊断"
        echo "  --diagnose-deep       # 深度系统诊断"
        echo "  --update-all          # 更新全部组件"
        echo ""
        echo "提示:"
        echo "  - 首次使用建议运行: $0 --diagnose-simple"
        echo "  - 确保已安装: brew, git, python3, node, npm"
        echo "  - 日志位置: ${LOG_DIR}"
        echo "  - 备份位置: ${BACKUP_DIR}"
        exit 0
        ;;
    --deploy-all)
        check_dependencies "--ignore-missing"
        for k in "${COMP_KEYS[@]}"; do deploy_component "$k" || true; done
        log_success "批量部署完成"
        ;;
    --start-all) start_all_services ;;
    --stop-all) stop_all_services ;;
    --status) show_status ;;
    --diagnose-simple) diagnose_simple ;;
    --diagnose-deep) diagnose_deep ;;
    --update-all)
        for k in "${COMP_KEYS[@]}"; do
            [ -d "${INSTALL_DIR}/${k}" ] && update_component "$k" || true
        done
        ;;
    *)
        # 默认进入交互菜单
        main
        ;;
esac
