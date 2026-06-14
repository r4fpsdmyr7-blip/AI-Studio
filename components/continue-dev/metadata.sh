#!/bin/bash

# ============================================================================
# AI Studio - Continue.dev Component Metadata
# File: components/continue-dev/metadata.sh
# 
# This file defines the static properties and requirements for the Continue.dev 
# component. It should be sourced by other component scripts and the main registry.
# Note: Continue.dev is an IDE extension, not a standalone background service.
# ============================================================================

# 1. Basic Identification
readonly COMPONENT_NAME="continue-dev"
readonly COMPONENT_DESCRIPTION="Open-source AI coding assistant for VS Code / JetBrains"
readonly COMPONENT_TYPE="ide-extension" # Deployment type: python, node, docker, binary, ide-extension

# 2. Network Configuration
# Continue.dev runs inside the IDE and connects to local/remote backends.
# It does not expose a standalone network port for this deployment.
readonly COMPONENT_PORT=""

# 3. Source & Versioning
# Used for fetching configuration templates or documentation, not for running a server.
readonly COMPONENT_REPO="https://github.com/continuedev/continue.git"
readonly COMPONENT_BRANCH="main"

# 4. System & Environment Dependencies
# Requires Git (for fetching configs) and ideally an IDE CLI (like 'code' for VS Code)
# We keep it minimal as the primary dependency is the user's IDE.
readonly COMPONENT_REQUIRED_DEPS="git"

# 5. Runtime Configuration Paths
# Continue.dev stores its global configuration (config.json, models, history) in the user's home directory.
# We point to the standard macOS path for Continue.
readonly COMPONENT_DATA_DIR="$HOME/.continue"
readonly COMPONENT_LOG_FILE="${AI_STUDIO_ROOT:-.}/logs/continue-dev.log"

# 6. Update Strategy
# Since it's an extension, updates primarily involve updating the extension via the IDE 
# or updating local configuration templates provided by AI Studio.
# Valid options: architecture (config/templates), all
readonly COMPONENT_UPDATE_TARGETS="architecture all"

# ============================================================================
# Export variables (Recommended for subshells)
# ============================================================================
export COMPONENT_NAME
export COMPONENT_DESCRIPTION
export COMPONENT_TYPE
export COMPONENT_PORT
export COMPONENT_REPO
export COMPONENT_BRANCH
export COMPONENT_REQUIRED_DEPS
export COMPONENT_DATA_DIR
export COMPONENT_LOG_FILE
export COMPONENT_UPDATE_TARGETS
