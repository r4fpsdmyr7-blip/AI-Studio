#!/usr/bin/env bash
show_banner() {
    echo -e "${CLR_CYAN}${CLR_BOLD}"
    echo "     _   ___    _____ _             _ _      "
    echo "    / | / / |  / ____(_)           | | |     "
    echo "   /  |/ /| | | (___  _ _ __   __ _| | |     "
    echo "  / /|  / | |  \___ \| | '_ \ / _  | | |     "
    echo " / / | /  | |  ____) | | | | | (_| | | |     "
    echo "/_/  |/   |_| |_____/|_|_| |_|\__,_|_|_|     "
    echo -e "${CLR_RESET}"
    echo -e "${CLR_DIM}    AI Tools Unified Management Platform${CLR_RESET}"; echo ""
}
show_separator() { printf '%*s\n' "${2:-60}" '' | tr ' ' "${1:--}"; }
show_main_menu() {
    show_banner; show_separator "="
    echo -e "  ${CLR_BOLD}请选择操作:${CLR_RESET}\n"
    echo -e "  ${CLR_GREEN}1)${CLR_RESET}  deploy     - 首次部署"
    echo -e "  ${CLR_GREEN}2)${CLR_RESET}  start      - 日常启动"
    echo -e "  ${CLR_GREEN}3)${CLR_RESET}  stop       - 停止服务"
    echo -e "  ${CLR_GREEN}4)${CLR_RESET}  status     - 查看状态"
    echo -e "  ${CLR_GREEN}5)${CLR_RESET}  update     - 更新前端"
    echo -e "  ${CLR_GREEN}6)${CLR_RESET}  agent      - Agent 管理"
    echo -e "  ${CLR_GREEN}7)${CLR_RESET}  model      - 架构及模型"
    echo -e "  ${CLR_GREEN}8)${CLR_RESET}  diagnose   - 自我诊断"
    echo -e "  ${CLR_GREEN}9)${CLR_RESET}  uninstall  - 卸载"
    echo -e "  ${CLR_GREEN}0)${CLR_RESET}  log        - 查看日志\n"
    echo -e "  ${CLR_DIM}用法: ./ai-studio.sh <command> [component]${CLR_RESET}"
    show_separator "="
}
info_box() {
    local title="$1"; shift
    show_separator "-"; echo -e "  ${CLR_BOLD}${CLR_CYAN}$title${CLR_RESET}"; show_separator "-"
    for line in "$@"; do echo -e "  $line"; done; show_separator "-"
}
success_box() { echo -e "\n  ${CLR_GREEN}${CLR_BOLD}✓ $1${CLR_RESET}\n"; }
error_box() { echo -e "\n  ${CLR_RED}${CLR_BOLD}✗ $1${CLR_RESET}\n"; }
print_table_row() { printf "  ${CLR_BOLD}%-18s${CLR_RESET} %-12s %-20s %s\n" "$1" "$2" "$3" "$4"; }
