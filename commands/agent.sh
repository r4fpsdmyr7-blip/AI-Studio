#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"; load_libs; load_all_components
cmd_agent() {
    local action="${1:-list}"
    log_info "===== AI-Studio Agent 管理 ====="; echo ""
    case "$action" in
        list)
            info_box "已注册 Agent"
            echo -e "  ${CLR_CYAN}名称${CLR_RESET}              ${CLR_CYAN}类型${CLR_RESET}          ${CLR_CYAN}状态${CLR_RESET}"
            show_separator "-"
            echo -e "  open-webui-agent    Open WebUI      $(is_running open-webui && echo -e "${CLR_GREEN}活跃${CLR_RESET}" || echo -e "${CLR_RED}离线${CLR_RESET}")"
            echo -e "  sillytavern-agent   SillyTavern     $(is_running sillytavern && echo -e "${CLR_GREEN}活跃${CLR_RESET}" || echo -e "${CLR_RED}离线${CLR_RESET}")"
            echo -e "  browser-use-agent   Browser Use     $(is_running browser-use && echo -e "${CLR_GREEN}活跃${CLR_RESET}" || echo -e "${CLR_RED}离线${CLR_RESET}")"
            echo -e "  continue-dev-agent  Continue.dev    已配置"
            ;;
        config)
            local agent="${2:-}"; [[ -z "$agent" ]] && { log_error "用法: agent config <name>"; return 1; }
            info_box "Agent 配置: $agent"
            echo -e "  编辑: $AI_STUDIO_CONFIG_DIR/${agent}-agent.conf"
            ;;
        status)
            local agent="${2:-all}"
            [[ "$agent" == "all" ]] && { cmd_agent list; return; }
            comp_do "$agent" agent_status 2>/dev/null || log_warn "Agent $agent 无状态接口"
            ;;
        *)
            echo -e "${CLR_BOLD}Agent 子命令:${CLR_RESET}"
            echo -e "  list    - 列出所有 Agent"
            echo -e "  config  - 配置 Agent"
            echo -e "  status  - Agent 状态"
            ;;
    esac
}
cmd_agent "$@"
