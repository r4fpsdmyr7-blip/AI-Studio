#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Stop Script
# File: components/open-webui/stop.sh
# 
# Handles the graceful shutdown of the Open WebUI background daemon.
# It utilizes the centralized process management library for safe termination.
# ============================================================================

set -u # Prevent unbound variable errors

# 1. Determine component directory and project root
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$(cd "$COMPONENT_DIR/../.." && pwd)"

# 2. Source core libraries and component metadata
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$COMPONENT_DIR/metadata.sh"

# ============================================================================
# 3. Core Stop Logic
# ============================================================================

main() {
    print_separator
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}  Stopping: ${COMPONENT_NAME}${COLOR_RESET}"
    print_separator
    echo ""

    # Pre-flight check: Verify if the component is actually running
    if ! is_daemon_running "$COMPONENT_NAME"; then
        log_info "${COMPONENT_NAME} is not currently running."
        # Clean up any potential stale PID files just in case
        _clear_pid "$COMPONENT_NAME"
        echo ""
        print_separator
        exit 0
    fi

    # Execute graceful stop via the process library
    # stop_daemon handles:
    # 1. Sending SIGTERM for graceful shutdown (saving state, closing DB connections)
    # 2. Waiting up to 15 seconds for the process to exit
    # 3. Sending SIGKILL if it fails to respond (preventing zombie processes)
    # 4. Cleaning up the PID file
    if stop_daemon "$COMPONENT_NAME" 15; then
        echo ""
        print_separator
        log_success "${COMPONENT_NAME} has been stopped successfully."
        log_info "Port ${COMPONENT_PORT} is now released."
        echo ""
        echo -e "${COLOR_CYAN}Next Steps:${COLOR_RESET}"
        echo "  • To start it again: ./ai-studio.sh start ${COMPONENT_NAME}"
        echo "  • To check detailed status: ./ai-studio.sh status ${COMPONENT_NAME}"
        print_separator
        exit 0
    else
        echo ""
        print_separator
        log_error "Failed to stop ${COMPONENT_NAME} cleanly."
        log_info "The process might be stuck. You can try:"
        log_info "  1. Check the logs: ${COLOR_GRAY}${AI_STUDIO_ROOT}/logs/${COMPONENT_NAME}.log${COLOR_RESET}"
        log_info "  2. Force kill the port manually: lsof -ti :${COMPONENT_PORT} | xargs kill -9"
        log_info "  3. Run deep diagnosis: ./ai-studio.sh diagnose ${COMPONENT_NAME} --deep --fix"
        print_separator
        exit 1
    fi
}

# Execute main function
main "$@"
