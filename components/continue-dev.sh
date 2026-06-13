#!/usr/bin/env bash
CONTINUE_DEV_COMP_NAME="continue-dev"
CONTINUE_DEV_COMP_PORT=""
CONTINUE_DEV_COMP_DEPS="node,npm"
CONTINUE_DEV_COMP_DESC="AI 代码助手 (IDE 扩展)"
comp_install() {
    log_info "安装 Continue.dev..."
    if check_command code; then
        log_info "安装 VS Code 扩展..."
        code --install-extension continue.continue 2>/dev/null || code --install-extension Continue.continue 2>/dev/null || true
    fi
    local config_dir="$AI_STUDIO_CONFIG_DIR/continue-dev"; mkdir -p "$config_dir"
    cat > "$config_dir/config.json" << 'CEOF'
{
  "models": [{"title": "Ollama", "provider": "ollama", "model": "qwen2.5:latest", "apiBase": "http://localhost:11434"}],
  "tabAutocompleteModel": {"title": "Ollama Autocomplete", "provider": "ollama", "model": "qwen2.5-coder:1.5b"}
}
CEOF
    set_comp_config continue-dev CONFIG_DIR "$config_dir"
    log_success "Continue.dev 安装完成"; log_info "请在 VS Code 中配置: ~/.continue/config.json"
}
comp_start() { log_info "Continue.dev 是 IDE 扩展, 无需独立启动"; return 0; }
comp_stop() { log_info "Continue.dev 随 IDE 关闭而停止"; return 0; }
comp_status() {
    if check_command code; then
        code --list-extensions 2>/dev/null | grep -qi continue && echo -e "  VS Code 扩展: ${CLR_GREEN}已安装${CLR_RESET}" || echo -e "  VS Code 扩展: ${CLR_YELLOW}未安装${CLR_RESET}"
    else echo -e "  VS Code: ${CLR_DIM}未安装${CLR_RESET}"; fi
}
comp_update() { check_command code && { code --update-extensions 2>/dev/null || true; log_success "Continue.dev 已更新"; }; }
comp_uninstall() {
    check_command code && { code --uninstall-extension continue.continue 2>/dev/null || code --uninstall-extension Continue.continue 2>/dev/null || true; }
    rm -rf "$AI_STUDIO_CONFIG_DIR/continue-dev"; log_success "Continue.dev 已卸载"
}
