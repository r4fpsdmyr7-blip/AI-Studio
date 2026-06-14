#!/bin/bash

# ============================================================================
# AI Studio - Open WebUI Component Metadata
# File: components/open-webui/metadata.sh
# 
# This file defines the static properties and requirements for the Open WebUI 
# component. It should be sourced by other component scripts (install.sh, 
# start.sh, etc.) and the main registry. It contains NO execution logic.
# ============================================================================

# 1. Basic Identification
readonly COMPONENT_NAME="open-webui"
readonly COMPONENT_DESCRIPTION="Powerful and feature-rich local LLM Web UI"
readonly COMPONENT_TYPE="python" # Deployment type: python, node, docker, binary

# 2. Network Configuration
# The default port this service will attempt to bind to.
# If occupied, the start script should handle fallback or error reporting.
readonly COMPONENT_PORT="3000"

# 3. Source & Versioning
readonly COMPONENT_REPO="https://github.com/open-webui/open-webui.git"
readonly COMPONENT_BRANCH="main" # Stable branch to track
# Optional: Pin to a specific release tag if needed for stability
# readonly COMPONENT_TAG="v0.3.0" 

# 4. System & Environment Dependencies
# Space-separated list of commands/tools required to install and run this component.
# The main env-install.sh or component install.sh will verify these.
readonly COMPONENT_REQUIRED_DEPS="python3 git curl wget"

# 5. Runtime Configuration Paths (Relative to component directory)
# These paths help other scripts locate logs, virtual environments, or data.
readonly COMPONENT_VENV_DIR=".venv"
readonly COMPONENT_DATA_DIR="./data" # For SQLite database and uploaded files
readonly COMPONENT_LOG_FILE="${AI_STUDIO_ROOT:-.}/logs/open-webui.log"

# 6. Update Strategy
# Defines what targets are valid for the `--target` update flag for this specific component.
# Valid options: frontend, backend, architecture, models, all
readonly COMPONENT_UPDATE_TARGETS="backend architecture all"

# ============================================================================
# Export variables (Optional but recommended for subshells)
# ============================================================================
export COMPONENT_NAME
export COMPONENT_DESCRIPTION
export COMPONENT_TYPE
export COMPONENT_PORT
export COMPONENT_REPO
export COMPONENT_BRANCH
export COMPONENT_REQUIRED_DEPS
export COMPONENT_VENV_DIR
export COMPONENT_DATA_DIR
export COMPONENT_LOG_FILE
export COMPONENT_UPDATE_TARGETS
