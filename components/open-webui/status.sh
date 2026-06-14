#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Status Script
# File: components/open-webui/status.sh
# 
# Provides a comprehensive, structured overview of the component's current 
# state, including process health, port binding, and recent activity.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Status Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Status: ${COMPONENT_NAME}${COLOR_RESET}"
    print_separator
    echo ""

    # --- Check 1: Installation Status ---
    if [[ ! -d "${COMPONENT_DIR}/${COMPONENT_VENV_DIR}" ]]; then
        echo -e "  [${COLOR_RED}NOT INSTALLED${COLOR_RESET}]"
        echo ""
        echo "  The component has not been installed yet."
        echo "  Run: ${COLOR_CYAN}./ai-studio.sh install ${COMPONENT_NAME}${COLOR_RESET}"
        echo ""
        print_separator
        exit 1
    fi

    # --- Check 2: Process & Port Status ---
    local port_offset
    port_offset=$(get_config "DEFAULT_PORT_OFFSET" "global")
    port_offset=${port_offset:-0}
    local final_port=$((COMPONENT_PORT + port_offset))

    local status_line=""
    local info_items=()

    info_items+=("Component: ${COMPONENT_NAME}")
    info_items+=("Target Port: ${final_port}")
    info_items+=("Data Directory: ${COMPONENT_DATA_DIR}")

    if is_daemon_running "$COMPONENT_NAME"; then
        # Component is running
        local proc_info
        proc_info=$(get_daemon_info "$COMPONENT_NAME")
        
        if [[ "$proc_info" == "zombie_or_orphaned" ]]; then
            status_line="${COLOR_YELLOW}[WARNING]${COLOR_RESET} Process exists but appears orphaned/zombie."
            info_items+=("Status: Orphaned/Zombie")
        else
            # proc_info format: PID ELAPSED %CPU %MEM COMMAND
            local pid uptime cpu mem cmd
            read -r pid uptime cpu mem cmd <<< "$proc_info"
            
            status_line="${COLOR_GREEN}[RUNNING]${COLOR_RESET} Healthy"
            info_items+=("PID: ${pid}")
            info_items+=("Uptime: ${uptime}")
            info_items+=("Resources: ${cpu}% CPU, ${mem}% MEM")
            
            # Verify port is actually listening
            if is_port_in_use "$final_port"; then
                info_items+=("Port Status: ${COLOR_GREEN}Listening on ${final_port}${COLOR_RESET}")
            else
                info_items+=("Port Status: ${COLOR_YELLOW}Process running, but port ${final_port} is NOT listening${COLOR_RESET}")
            fi
        fi
    else
        # Component is stopped
        status_line="${COLOR_GRAY}[STOPPED]${COLOR_RESET} Not currently running"
        info_items+=("Status: Stopped")
        
        # Check for port conflicts even when stopped
        if is_port_in_use "$final_port"; then
            info_items+=("Port Status: ${COLOR_RED}WARNING - Port ${final_port} is occupied by another process!${COLOR_RESET}")
        else
            info_items+=("Port Status: ${COLOR_GREEN}Available${COLOR_RESET}")
        fi
    fi

    # --- Output Formatted Status ---
    echo -e "  ${status_line}"
    echo ""
    
    # Use the UI library to print a clean key-value block
    print_info_block "Configuration & State" "${info_items[@]}"

    # --- Check 3: Recent Log Activity (Progressive Disclosure: Level 1) ---
    local log_file="${AI_STUDIO_ROOT}/logs/${COMPONENT_NAME}.log"
    echo -e "${COLOR_BOLD}Recent Log Activity:${COLOR_RESET}"
    if [[ -f "$log_file" ]]; then
        # Show last 5 lines, suppress empty lines
        local recent_logs
        recent_logs=$(tail -n 5 "$log_file" | grep -v '^$' | sed 's/^/    /')
        if [[ -n "$recent_logs" ]]; then
            echo -e "${COLOR_GRAY}${recent_logs}${COLOR_RESET}"
        else
            echo "    ${COLOR_GRAY}(Log file is empty or contains no recent text)${COLOR_RESET}"
        fi
    else
        echo "    ${COLOR_GRAY}(No log file generated yet)${COLOR_RESET}"
    fi

    echo ""
    print_separator
    
    # --- Actionable Next Steps ---
    if is_daemon_running "$COMPONENT_NAME"; then
        echo -e "  ${COLOR_CYAN}Actions:${COLOR_RESET}"
        echo "    • Stop service:   ${COLOR_GRAY}./ai-studio.sh stop ${COMPONENT_NAME}${COLOR_RESET}"
        echo "    • View full logs: ${COLOR_GRAY}cat ${AI_STUDIO_ROOT}/logs/${COMPONENT_NAME}.log${COLOR_RESET}"
        echo "    • Open browser:   ${COLOR_GRAY}open http://localhost:${final_port}${COLOR_RESET}"
    else
        echo -e "  ${COLOR_CYAN}Actions:${COLOR_RESET}"
        echo "    • Start service:  ${COLOR_GRAY}./ai-studio.sh start ${COMPONENT_NAME}${COLOR_RESET}"
        echo "    • Run diagnosis:  ${COLOR_GRAY}./ai-studio.sh diagnose ${COMPONENT_NAME}${COLOR_RESET}"
    fi
    echo ""
    print_separator
    
    exit 0
}

# Execute main function
main "$@"
