#!/bin/bash

# ============================================================================
# AI Studio - ComfyUI Component Metadata
# File: components/comfyui/metadata.sh
# 
# This file defines the static properties and requirements for the ComfyUI 
# component (Node-based image generation UI). It should be sourced by other 
# component scripts (install.sh, start.sh, etc.) and the main registry. 
# It contains NO execution logic.
# ============================================================================

# 1. Basic Identification
readonly COMPONENT_NAME="comfyui"
readonly COMPONENT_DESCRIPTION="Powerful node-based image generation UI (SDXL/FLUX support)"
readonly COMPONENT_TYPE="python" # Deployment type: python, node, docker, binary

# 2. Network Configuration
# The default port this service will attempt to bind to.
readonly COMPONENT_PORT="8188"

# 3. Source & Versioning
readonly COMPONENT_REPO="https://github.com/comfyanonymous/ComfyUI.git"
# ComfyUI development is highly active; 'master' is the recommended stable branch
readonly COMPONENT_BRANCH="master" 

# 4. System & Environment Dependencies
# Space-separated list of commands/tools required to install and run this component.
# cmake is often required for building custom nodes (e.g., certain diffusion samplers)
readonly COMPONENT_REQUIRED_DEPS="python3 git wget curl cmake"

# 5. Runtime Configuration Paths (Relative to component directory)
readonly COMPONENT_VENV_DIR=".venv"
# ComfyUI stores large model weights (.safetensors, .ckpt) in the 'models' directory.
# This is the most critical data to preserve during updates or uninstalls.
readonly COMPONENT_DATA_DIR="./models"
readonly COMPONENT_LOG_FILE="${AI_STUDIO_ROOT:-.}/logs/comfyui.log"

# 6. Update Strategy
# Defines what targets are valid for the `--target` update flag for this specific component.
# ComfyUI has distinct frontend (web) and backend (python) parts, plus heavy dependencies.
readonly COMPONENT_UPDATE_TARGETS="frontend backend architecture all"

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
export COMPONENT_VENV_DIR
export COMPONENT_DATA_DIR
export COMPONENT_LOG_FILE
export COMPONENT_UPDATE_TARGETS
