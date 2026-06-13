#!/usr/bin/env bash
SILLYTAVERN_COMP_NAME="sillytavern"
SILLYTAVERN_COMP_PORT="8000"
SILLYTAVERN_COMP_DEPS="node,npm,git"
SILLYTAVERN_COMP_DESC="角色扮演 AI 前端"
SILLYTAVERN_COMP_DIR="$AI_STUDIO_DATA_DIR/sillytavern"
comp_install() {
    log_info "安装 SillyTavern..."
    require_command node "brew install node" || return 1; require_command git || return 1
    mkdir -p "$(dirname "$SILLYTAVERN_COMP_DIR")"
    git clone "$(gh_url https://github.com/SillyTavern/SillyTavern.git)" "$SILLYTAVERN_COMP_DIR" || return 1
    cd "$SILLYTAVERN_COMP_DIR"; npm install
    set_comp_config sillytavern PORT "$(get_config SILLYTAVERN_PORT 8000)"
    set_comp_config sillytavern DIR "$SILLYTAVERN_COMP_DIR"
    [[ -f "config.yaml" ]] && { sed -i.bak 's/whitelistMode: true/whitelistMode: false/' config.yaml 2>/dev/null || true; sed -i.bak 's/listen: false/listen: true/' config.yaml 2>/dev/null || true; }
    cd - >/dev/null; log_success "SillyTavern 安装完成"
}
comp_start() {
    local port; port="$(get_comp_config sillytavern PORT 8000)"
    local dir; dir="$(get_comp_config sillytavern DIR "$SILLYTAVERN_COMP_DIR")"
    log_info "启动 SillyTavern (端口: $port)..."; cd "$dir"
    nohup node server.js --port "$port" > "$AI_STUDIO_LOG_DIR/sillytavern.log" 2>&1 &
    local pid=$!; cd - >/dev/null; save_pid sillytavern "$pid"
    log_success "SillyTavern 已启动 (PID: $pid)"; auto_open_browser sillytavern "$port"
}
comp_stop() { kill_service sillytavern; }
comp_status() { is_running sillytavern && { local port; port="$(get_comp_config sillytavern PORT 8000)"; echo -e "  Web UI: http://localhost:$port"; }; }
comp_update() {
    local dir; dir="$(get_comp_config sillytavern DIR "$SILLYTAVERN_COMP_DIR")"
    log_info "更新 SillyTavern..."; cd "$dir"; git pull; npm install; cd - >/dev/null; log_success "SillyTavern 已更新"
}
comp_uninstall() {
    log_info "卸载 SillyTavern..."; is_running sillytavern && kill_service sillytavern
    rm -rf "$SILLYTAVERN_COMP_DIR"; log_success "SillyTavern 已卸载"
}
