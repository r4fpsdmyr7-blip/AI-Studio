#!/bin/bash

# ============================================================================
# AI Studio - SillyTavern Component Metadata
# File: components/sillytavern/metadata.sh
# 
# This file defines the static properties and requirements for the SillyTavern 
# component. It should be sourced by other component scripts (install.sh, 
# start.sh, etc.) and the main registry. It contains NO execution logic.
# ============================================================================

# 1. Basic Identification
readonly COMPONENT_NAME="sillytavern"
readonly COMPONENT_DESCRIPTION="Advanced LLM roleplay and chatting frontend"
readonly COMPONENT_TYPE="node" # Deployment type: python, node, docker, binary

# 2. Network Configuration
# The default port this service will attempt to bind to.
readonly COMPONENT_PORT="8000"

# 3. Source & Versioning
readonly COMPONENT_REPO="https://github.com/SillyTavern/SillyTavern.git"
# 'release' branch is recommended for stability, 'staging' for latest features
readonly COMPONENT_BRANCH="release" 

# 4. System & Environment Dependencies
# Space-separated list of commands/tools required to install and run this component.
readonly COMPONENT_REQUIRED_DEPS="node npm git"

# 5. Runtime Configuration Paths (Relative to component directory)
# SillyTavern stores user data (characters, worlds, settings, backups) in the 'data' directory (v1.10+)
# and legacy files in 'public'. We point to the modern centralized data directory.
readonly COMPONENT_DATA_DIR="./data"
readonly COMPONENT_LOG_FILE="${AI_STUDIO_ROOT:-.}/logs/sillytavern.log"

# 6. Update Strategy
# Defines what targets are valid for the `--target` update flag for this specific component.
# SillyTavern is primarily a frontend application with Node.js dependencies.
readonly COMPONENT_UPDATE_TARGETS="frontend architecture all"

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
