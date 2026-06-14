#!/bin/bash

# ============================================================================
# AI Studio - Main Entry Script
# A unified platform for managing and deploying AI tools
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AI_STUDIO_ROOT="$SCRIPT_DIR"

# Import core libraries
source "$AI_STUDIO_ROOT/lib/common.sh"
source "$AI_STUDIO_ROOT/lib/config.sh"
source "$AI_STUDIO_ROOT/lib/env-check.sh"
source "$AI_STUDIO_ROOT/lib/env-install.sh"
source "$AI_STUDIO_ROOT/lib/browser.sh"
source "$AI_STUDIO_ROOT/lib/process.sh"
source "$AI_STUDIO_ROOT/lib/diagnose.sh"
source "$AI_STUDIO_ROOT/lib/ui.sh"
source "$AI_STUDIO_ROOT/components/registry.sh"

VERSION="1.0.0"
VERSION_DATE="2026-06-13"

show_help() {
    cat << EOF
AI Studio v${VERSION}
A unified platform for managing and deploying AI tools

Usage:
  $(basename "$0") <command> [arguments] [options]

Core Commands:
  env check|install|status       Environment management
  install <component|all>        Install component(s)
  start <component|all>          Start service(s) (auto-open browser)
  stop <component|all>           Stop service(s)
  restart <component|all>        Restart service(s)
  status [component]             View status
  update <component|all>         Update component(s)
    --target <type>              Update target: frontend|agent|architecture|models
  uninstall <component>          Uninstall component
    --keep-data                  Keep user data
    --force                      Force uninstall
  diagnose <component>           Diagnose component
    --deep                       Deep diagnosis
    --fix                        Diagnose and auto-fix
  list                           List all available components
  help                           Show this help
  version                        Show version

Available Components:
  open-webui, sillytavern, continue-dev, fazm, browser-use,
  mlx, comfyui, mlx-video, qwen3

Examples:
  $(basename "$0") env check
  $(basename "$0") install open-webui
  $(basename "$0") start open-webui
  $(basename "$0") status
  $(basename "$0") update comfyui --target models
  $(basename "$0") diagnose sillytavern --deep

EOF
}

show_version() {
    echo "AI Studio v${VERSION} (${VERSION_DATE})"
}

handle_env_command() {
    local subcommand="$1"
    
    if [[ "$subcommand" == "check" ]]; then
        log_info "Starting environment check..."
        check_all_requirements
    elif [[ "$subcommand" == "install" ]]; then
        log_info "Installing environment dependencies..."
        install_all_dependencies
    elif [[ "$subcommand" == "status" ]]; then
        log_info "Environment status:"
        show_environment_status
    else
        log_error "Unknown env subcommand: $subcommand"
        show_help
        exit 1
    fi
}

handle_component_command() {
    local command="$1"
    local component="$2"
    shift 2
    local args=("$@")
    
    # Validate component name
    if [[ "$component" != "all" ]] && ! is_valid_component "$component"; then
        log_error "Unknown component: $component"
        log_info "Use '$(basename "$0") list' to see all available components"
        exit 1
    fi
    
    # Get component script path
    local component_dir="$AI_STUDIO_ROOT/components/$component"
    local script_path="$component_dir/${command}.sh"
    
    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        log_error "Component $component does not support $command operation"
        exit 1
    fi
    
    # Execute component script based on command
    if [[ "$command" == "install" ]]; then
        if [[ "$component" == "all" ]]; then
            log_info "Installing all components..."
            for comp in $(get_all_components); do
                log_info "Installing $comp..."
                "$AI_STUDIO_ROOT/components/$comp/install.sh" "${args[@]}"
            done
        else
            log_info "Installing $component..."
            "$script_path" "${args[@]}"
        fi
        
    elif [[ "$command" == "start" ]]; then
        if [[ "$component" == "all" ]]; then
            log_info "Starting all components..."
            for comp in $(get_all_components); do
                log_info "Starting $comp..."
                "$AI_STUDIO_ROOT/components/$comp/start.sh" "${args[@]}"
            done
        else
            log_info "Starting $component..."
            "$script_path" "${args[@]}"
            
            # Auto-open browser
            local port=$(get_component_port "$component")
            if [[ -n "$port" ]]; then
                log_info "Service started, opening browser..."
                open_browser "http://localhost:$port"
            fi
        fi
        
    elif [[ "$command" == "stop" ]]; then
        if [[ "$component" == "all" ]]; then
            log_info "Stopping all components..."
            for comp in $(get_all_components); do
                log_info "Stopping $comp..."
                "$AI_STUDIO_ROOT/components/$comp/stop.sh" "${args[@]}"
            done
        else
            log_info "Stopping $component..."
            "$script_path" "${args[@]}"
        fi
        
    elif [[ "$command" == "restart" ]]; then
        log_info "Restarting $component..."
        "$AI_STUDIO_ROOT/components/$component/stop.sh" "${args[@]}"
        sleep 2
        "$AI_STUDIO_ROOT/components/$component/start.sh" "${args[@]}"
        
    elif [[ "$command" == "status" ]]; then
        if [[ -z "$component" ]] || [[ "$component" == "all" ]]; then
            show_all_components_status
        else
            "$script_path" "${args[@]}"
        fi
        
    elif [[ "$command" == "update" ]]; then
        if [[ "$component" == "all" ]]; then
            log_info "Updating all components..."
            for comp in $(get_all_components); do
                log_info "Updating $comp..."
                "$AI_STUDIO_ROOT/components/$comp/update.sh" "${args[@]}"
            done
        else
            log_info "Updating $component..."
            "$script_path" "${args[@]}"
        fi
        
    elif [[ "$command" == "uninstall" ]]; then
        log_info "Uninstalling $component..."
        "$script_path" "${args[@]}"
        
    elif [[ "$command" == "diagnose" ]]; then
        log_info "Diagnosing $component..."
        "$script_path" "${args[@]}"
        
    else
        log_error "Unknown command: $command"
        exit 1
    fi
}

list_components() {
    echo ""
    echo "Available Components:"
    echo ""
    
    for comp in $(get_all_components); do
        local desc=$(get_component_description "$comp")
        local port=$(get_component_port "$comp")
        local status_icon="[ ]"
        
        # Check if installed
        if is_component_installed "$comp"; then
            # Check if running
            if is_component_running "$comp"; then
                status_icon="[R]"
            else
                status_icon="[I]"
            fi
        fi
        
        printf "  %s %-20s %s" "$status_icon" "$comp" "$desc"
        if [[ -n "$port" ]]; then
            printf " (port: %s)" "$port"
        fi
        echo ""
    done
    
    echo ""
    echo "Status Legend:"
    echo "  [R] Running  [I] Installed but not running  [ ] Not installed"
    echo ""
}

main() {
    # Initialize logging
    init_logging
    
    # Check arguments
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    local command="$1"
    shift
    
    # Command routing
    if [[ "$command" == "help" ]] || [[ "$command" == "--help" ]] || [[ "$command" == "-h" ]]; then
        show_help
    elif [[ "$command" == "version" ]] || [[ "$command" == "--version" ]] || [[ "$command" == "-v" ]]; then
        show_version
    elif [[ "$command" == "env" ]]; then
        handle_env_command "$@"
    elif [[ "$command" == "list" ]]; then
        list_components
    elif [[ "$command" == "install" ]] || [[ "$command" == "start" ]] || [[ "$command" == "stop" ]] || [[ "$command" == "restart" ]] || [[ "$command" == "status" ]] || [[ "$command" == "update" ]] || [[ "$command" == "uninstall" ]] || [[ "$command" == "diagnose" ]]; then
        if [[ $# -eq 0 ]]; then
            log_error "Missing component name argument"
            show_help
            exit 1
        fi
        handle_component_command "$command" "$@"
    else
        log_error "Unknown command: $command"
        show_help
        exit 1
    fi
}

# Execute main function
main "$@"
