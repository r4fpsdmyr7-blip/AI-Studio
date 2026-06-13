#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_deploy() {
    local targets=("$@")
    log_info "===== AI-Studio 首次部署 ====="; echo ""
    detect_platform; log_success "系统: $AI_STUDIO_OS / $AI_STUDIO_ARCH"
    init_config
    for dep in git curl; do
        check_command "$dep" || { log_warn "缺少: $dep"; [[ "$AI_STUDIO_OS" == "macos" ]] && check_command brew && confirm "安装 $dep?" && brew install "$dep"; }
    done
    check_command python3 || { log_warn "缺少 Python3"; [[ "$AI_STUDIO_OS" == "macos" ]] && check_command brew && confirm "安装 Python3?" && brew install python; }
    check_command node || { log_warn "缺少 Node.js"; [[ "$AI_STUDIO_OS" == "macos" ]] && check_command brew && confirm "安装 Node.js?" && brew install node; }
    setup_proxy; setup_hf_mirror; setup_pip_mirror; setup_npm_mirror
    if [[ ${#targets[@]} -eq 0 ]]; then
        echo -e "${CLR_BOLD}选择组件:${CLR_RESET}"
        echo -e "  ${CLR_YELLOW}1)${CLR_RESET} 全部"; local i=2
        for comp in "${REGISTERED_COMPONENTS[@]}"; do printf "  ${CLR_YELLOW}%d)${CLR_RESET} %s\n" "$i" "$comp"; ((i++)); done
        echo -en "${CLR_CYAN}请选择: ${CLR_RESET}"; read -r choice
        if [[ "$choice" == "1" ]]; then targets=("${REGISTERED_COMPONENTS[@]}")
        elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice>=2 && choice<=${#REGISTERED_COMPONENTS[@]}+1)); then targets=("${REGISTERED_COMPONENTS[$((choice-2))]}")
        else log_error "无效"; return 1; fi
    fi
    local total=${#targets[@]} current=0 failed=0
    for comp in "${targets[@]}"; do
        ((current++)); echo ""; show_separator "="; echo -e "${CLR_BOLD}[$current/$total] 部署: $comp${CLR_RESET}"; show_separator "="
        is_comp_installed "$comp" && { log_warn "已安装"; confirm "重装?" || continue; comp_do "$comp" uninstall || true; }
        install_comp_deps "$comp"
        comp_do "$comp" install && { mark_comp_installed "$comp"; log_success "$comp 成功"; } || { log_error "$comp 失败"; ((failed++)); }
    done
    echo ""; ((failed==0)) && success_box "部署完成! ($total 个)" || log_warn "完成, $failed 个失败"
    log_info "执行 './ai-studio.sh start' 启动"
}
cmd_deploy "$@"
