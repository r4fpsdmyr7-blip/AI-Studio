#!/bin/bash

# ============================================================================
# AI Studio - User Interface Library (lib/ui.sh)
# Provides lightweight, pure-Bash terminal UI components (progress bars, 
# menus, tables, and prompts) compatible with macOS default environments.
# ============================================================================

# Ensure common functions (colors, logging) are available
# This script expects to be sourced after lib/common.sh

# ============================================================================
# 1. Progress & Loading Indicators
# ============================================================================

# Display a text-based progress bar
# Usage: show_progress 50 100 "Installing dependencies..."
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"
    local width=40
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    # Build bar strings
    local bar_filled=""
    local bar_empty=""
    for ((i=0; i<filled; i++)); do bar_filled+="#"; done
    for ((i=0; i<empty; i++)); do bar_empty+="-"; done
    
    # Print on the same line, overwriting previous output
    printf "\r${COLOR_CYAN}[%s]${COLOR_RESET} %3d%% | ${COLOR_BOLD}%s${COLOR_RESET}" \
        "${bar_filled}${bar_empty}" "$percent" "$message"
    
    # If complete, print a newline
    if [[ "$current" -ge "$total" ]]; then
        echo ""
    fi
}

# Show a simple spinning loader (runs in background, requires caller to kill it)
# Usage: show_spinner "Loading" & SPINNER_PID=$!; sleep 5; kill $SPINNER_PID 2>/dev/null; echo "Done"
show_spinner() {
    local message="${1:-Working}"
    local spinstr='|/-\'
    local temp
    
    while true; do
        for (( i=0; i<${#spinstr}; i++ )); do
            temp=${spinstr:$i:1}
            printf "\r${COLOR_CYAN}[%s]${COLOR_RESET} %s..." "$temp" "$message"
            sleep 0.1
        done
    done
}

# ============================================================================
# 2. User Prompts & Confirmations
# ============================================================================

# Ask for user confirmation with a default option
# Usage: if confirm_action "Are you sure you want to uninstall?" "Y"; then ...
# Returns: 0 for Yes, 1 for No
confirm_action() {
    local prompt="$1"
    local default="${2:-N}" # Default to 'N' for safety on destructive actions
    local response
    
    # Format prompt based on default
    if [[ "${default^^}" == "Y" ]]; then
        prompt="${prompt} [Y/n]: "
    else
        prompt="${prompt} [y/N]: "
    fi
    
    # Read input (timeout can be added with -t if needed, e.g., read -t 10)
    read -r -p "$(echo -e "${COLOR_YELLOW}${prompt}${COLOR_RESET}")" response
    
    # Normalize response
    response="${response:-$default}"
    response="${response^^}" # Convert to uppercase
    
    if [[ "$response" == "Y" || "$response" == "YES" ]]; then
        return 0
    else
        return 1
    fi
}

# Prompt user to enter a value with validation
# Usage: user_input "Enter port number: " "^[0-9]+$" "8080"
user_input() {
    local prompt="$1"
    local regex="${2:-}"
    local default="${3:-}"
    local input
    
    while true; do
        local display_prompt="$prompt"
        if [[ -n "$default" ]]; then
            display_prompt="${prompt} (default: $default): "
        fi
        
        read -r -p "$(echo -e "${COLOR_CYAN}${display_prompt}${COLOR_RESET}")" input
        
        # Use default if empty
        if [[ -z "$input" ]] && [[ -n "$default" ]]; then
            input="$default"
        fi
        
        # Validate against regex if provided
        if [[ -n "$regex" ]]; then
            if [[ "$input" =~ $regex ]]; then
                echo "$input"
                return 0
            else
                log_error "Invalid input. Please match the required format."
            fi
        else
            echo "$input"
            return 0
        fi
    done
}

# ============================================================================
# 3. Selection Menus
# ============================================================================

# Display a numbered list and let the user select an item
# Usage: select_from_list "Choose a component:" "open-webui" "sillytavern" "comfyui"
# Returns: The selected string via stdout, or empty if cancelled
select_from_list() {
    local prompt="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    
    if [[ $count -eq 0 ]]; then
        log_error "No options provided to select_from_list."
        return 1
    fi
    
    echo ""
    echo -e "${COLOR_BOLD}${prompt}${COLOR_RESET}"
    echo "----------------------------------------"
    
    for ((i=0; i<count; i++)); do
        printf "  %2d) %s\n" "$((i+1))" "${options[$i]}"
    done
    echo "   0) Cancel"
    echo "----------------------------------------"
    
    local choice
    while true; do
        read -r -p "$(echo -e "${COLOR_CYAN}Enter your choice (0-$count): ${COLOR_RESET}")" choice
        
        # Validate input is a number
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 0 ]] && [[ "$choice" -le "$count" ]]; then
            if [[ "$choice" -eq 0 ]]; then
                echo "" # Return empty
                return 1
            else
                echo "${options[$((choice-1))]}"
                return 0
            fi
        else
            log_error "Invalid selection. Please enter a number between 0 and $count."
        fi
    done
}

# ============================================================================
# 4. Formatting & Tables
# ============================================================================

# Print a formatted table from newline-separated, space-delimited data
# Usage: print_table "Name\tPort\tStatus\nopen-webui\t3000\tRunning"
print_table() {
    local data="$1"
    
    if [[ -z "$data" ]]; then
        log_warn "No data provided for table."
        return 0
    fi
    
    # macOS BSD 'column' command is perfect for this. 
    # -t: determine the number of columns, -s: separator (default is whitespace)
    echo "$data" | column -t -s $'\t' | sed "s/^/  /" # Indent by 2 spaces
}

# Print a key-value info block (useful for component metadata or status)
# Usage: print_info_block "Component Info" "Name: Open WebUI" "Port: 3000" "Status: Running"
print_info_block() {
    local title="$1"
    shift
    local items=("$@")
    
    echo ""
    echo -e "${COLOR_BOLD}=== ${title} ===${COLOR_RESET}"
    for item in "${items[@]}"; do
        # Split by first colon for alignment
        local key="${item%%:*}"
        local value="${item#*:}"
        printf "  ${COLOR_CYAN}%-15s${COLOR_RESET} : %s\n" "$key" "$value"
    done
    echo "========================="
    echo ""
}

# ============================================================================
# 5. Utility Wrappers for Progressive Disclosure
# ============================================================================

# Pause execution and wait for user to press Enter
# Usage: pause_for_user "Press Enter to continue..."
pause_for_user() {
    local msg="${1:-Press Enter to continue...}"
    read -r -s -p "$(echo -e "${COLOR_GRAY}${msg}${COLOR_RESET}")"
    echo ""
}

# Clear the terminal screen safely
clear_screen() {
    clear
    # Optional: print a welcome banner here if desired
}
