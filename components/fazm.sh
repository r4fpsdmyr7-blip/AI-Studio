#!/usr/bin/env bash
FAZM_COMP_NAME="fazm"
FAZM_COMP_PORT="8501"
FAZM_COMP_DEPS="python3,pip3,git"
FAZM_COMP_DESC="AI Agent 工作流平台"
FAZM_COMP_DIR="$AI_STUDIO_DATA_DIR/fazm"
comp_install() {
    log_info "安装 Fazm..."; require_command python3 || return 1; require_command git || return 1
    mkdir -p "$FAZM_COMP_DIR"; python3 -m venv "$FAZM_COMP_DIR/venv" || return 1
    source "$FAZM_COMP_DIR/venv/bin/activate"; pip install --upgrade pip
    pip install streamlit fastapi uvicorn
    [[ -n "${FAZM_REPO:-}" ]] && { git clone "$(gh_url "$FAZM_REPO")" "$FAZM_COMP_DIR/app" || true; cd "$FAZM_COMP_DIR/app"; [[ -f "requirements.txt" ]] && pip install -r requirements.txt; cd - >/dev/null; }
    deactivate; set_comp_config fazm PORT "$(get_config FAZM_PORT 8501)"; set_comp_config fazm DIR "$FAZM_COMP_DIR"
    log_success "Fazm 安装完成"
}
comp_start() {
    local port; port="$(get_comp_config fazm PORT 8501)"
    local dir; dir="$(get_comp_config fazm DIR "$FAZM_COMP_DIR")"
    log_info "启动 Fazm (端口: $port)..."; source "$dir/venv/bin/activate"
    if [[ -d "$dir/app" ]]; then cd "$dir/app"; nohup streamlit run main.py --server.port "$port" > "$AI_STUDIO_LOG_DIR/fazm.log" 2>&1 &
    else nohup streamlit run "$dir/main.py" --server.port "$port" > "$AI_STUDIO_LOG_DIR/fazm.log" 2>&1 &; fi
    local pid=$!; deactivate; save_pid fazm "$pid"
    log_success "Fazm 已启动 (PID: $pid)"; auto_open_browser fazm "$port"
}
comp_stop() { kill_service fazm; }
comp_status() { is_running fazm && { local port; port="$(get_comp_config fazm PORT 8501)"; echo -e "  Web UI: http://localhost:$port"; }; }
comp_update() {
    local dir; dir="$(get_comp_config fazm DIR "$FAZM_COMP_DIR")"
    log_info "更新 Fazm..."; source "$dir/venv/bin/activate"; pip install --upgrade streamlit fastapi uvicorn
    [[ -d "$dir/app" ]] && { cd "$dir/app"; git pull; [[ -f requirements.txt ]] && pip install -r requirements.txt; cd - >/dev/null; }
    deactivate; log_success "Fazm 已更新"
}
comp_uninstall() {
    log_info "卸载 Fazm..."; is_running fazm && kill_service fazm
    rm -rf "$FAZM_COMP_DIR"; log_success "Fazm 已卸载"
}
