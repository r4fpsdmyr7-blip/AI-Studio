# AI Studio

**A Unified, Modular, and Automated AI Tool Deployment & Management Platform for macOS**

AI Studio is a comprehensive, bash-based toolkit designed to simplify the deployment, management, and maintenance of local AI tools on macOS. Assuming a "zero-environment" starting point, it automatically detects system requirements, installs missing dependencies, and provides a standardized, unified interface for daily operations, granular updates, and self-diagnosis.

---

## 📑 Table of Contents

- [✨ Core Features](#-core-features)
- [🛠️ Supported Components](#️-supported-components)
- [💻 System Requirements](#-system-requirements)
- [🚀 Quick Start](#-quick-start)
- [📖 Detailed Usage Guide](#-detailed-usage-guide)
- [🏗️ Architecture & Design Principles](#️-architecture--design-principles)
- [📂 Directory Structure](#-directory-structure)
- [⚖️ License](#️-license)

---

## ✨ Core Features

- 🚀 **Zero-Configuration Start**: Automatically detects the macOS environment. If requirements are not met, it seamlessly installs missing dependencies (Homebrew, Python, Node.js, Git, Ollama, etc.) before proceeding with deployment.
- 🌐 **Auto-Open Browser**: Upon successful service startup, the script automatically detects the running port and invokes the system's default browser to open the corresponding Web UI.
- 🧩 **Highly Modular**: All 9 major AI components are deployed and managed completely independently. Installing, updating, or uninstalling one component will not interfere with others.
- 🩺 **Built-in Self-Diagnosis**: Features both "Simple" and "Deep" diagnostic modes to automatically identify port conflicts, missing dependencies, or zombie processes, with an optional one-click auto-fix (`--fix`) capability.
- 📈 **Progressive Disclosure**: Commands are layered from simple daily operations (`start`/`stop`) to advanced expert configurations (`--target`, `--deep`), revealing complexity only when needed to lower the learning curve.
- 🔄 **Granular Updates**: Supports independent updates for specific targets: `frontend`, `agent`, `architecture`, or `models`, saving time and bandwidth by avoiding full re-downloads.

---

## 🛠️ Supported Components

| Component Name | Description | Default Port |
| :--- | :--- | :---: |
| **Open WebUI** | A powerful and beautiful local LLM Web interaction interface. | `3000` |
| **SillyTavern** | Advanced frontend focused on LLM roleplay and complex chatting. | `8000` |
| **Continue.dev** | Open-source AI coding assistant for VS Code / JetBrains. | N/A |
| **Fazm** | Native macOS AI Desktop Agent. | N/A |
| **Browser Use** | AI-driven browser automation and web scraping tool. | `7788` |
| **MLX** | Apple's machine learning framework optimized for Apple Silicon. | N/A |
| **ComfyUI** | Powerful node-based image generation UI (Full SDXL/FLUX support). | `8188` |
| **MLX-Video** | Efficient local video generation tool powered by the MLX framework. | N/A |
| **QWen3 Uncensored**| Uncensored QWen3 Large Language Model (runs via Ollama). | `11434` |

---

## 💻 System Requirements

- **Operating System**: macOS 13.0 (Ventura) or later.
- **Hardware Architecture**: 
  - General components: Intel or Apple Silicon (M1/M2/M3/M4).
  - **MLX / MLX-Video / ComfyUI**: **Strongly recommended to use Apple Silicon** for optimal hardware acceleration and performance.
- **RAM**: Minimum 16GB (32GB or more is highly recommended for running large LLMs or FLUX image generation models).
- **Storage**: At least 50GB of free space (100GB+ is recommended to accommodate large model weights).
- **Network**: A stable internet connection is required for the initial deployment and model downloads.

---

## 🚀 Quick Start

For first-time users starting with **no pre-existing environment**, follow these 4 simple steps to prepare your system and launch your first component:

```bash
# 1. Clone the repository to your local machine
git clone https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs.git
cd ai-studio

# 2. Grant execution permissions to the main script
chmod +x ai-studio.sh

# 3. Check and install the system environment 
# (This will automatically install missing dependencies like Homebrew, Python, Node, etc.)
./ai-studio.sh env check
./ai-studio.sh env install

# 4. Deploy and start Open WebUI 
# (The browser will automatically open upon successful startup)
./ai-studio.sh install open-webui
./ai-studio.sh start open-webui
```

---

## 📖 Detailed Usage Guide

AI Studio employs a **Progressive Disclosure** design. Below is the detailed command guide categorized by usage scenarios.

### 1. Environment Management
```bash
./ai-studio.sh env check      # Only check if the system environment meets requirements (no installation)
./ai-studio.sh env install    # Automatically install all missing system-level dependencies
./ai-studio.sh env status     # View a summary of the current system environment status
```

### 2. Component Lifecycle (Deployment & Uninstall)
```bash
# Initial / Individual Deployment
./ai-studio.sh install <component>       # Deploy a single specific component (e.g., comfyui)
./ai-studio.sh install all               # Initial deployment of all supported components

# Stop & Uninstall
./ai-studio.sh uninstall <component>     # Uninstall the specified component
./ai-studio.sh uninstall <component> --keep-data  # Uninstall the component but retain user data and downloaded models
./ai-studio.sh uninstall <component> --force      # Force uninstall (ignores warnings about residual processes)
```

### 3. Daily Usage & Status
```bash
# Start & Stop
./ai-studio.sh start <component>         # Start the service (automatically opens the browser upon success)
./ai-studio.sh stop <component>          # Gracefully stop the service
./ai-studio.sh restart <component>       # Restart the service

# View Status
./ai-studio.sh status                    # View the running status and port usage of all components
./ai-studio.sh status <component>        # View detailed running status of a single component
./ai-studio.sh list                      # List all available components and their metadata
```

### 4. Granular Updates
Supports independent updates for different parts of a component to save time and bandwidth:
```bash
./ai-studio.sh update <component>                      # Full update of the component
./ai-studio.sh update <component> --target frontend    # Update frontend code only
./ai-studio.sh update <component> --target agent       # Update Agent logic only
./ai-studio.sh update <component> --target architecture# Update underlying architecture or system dependencies only
./ai-studio.sh update <component> --target models      # Pull/update model weight files only
```

### 5. Self-Diagnosis
Use the diagnostic features when a service fails to start or behaves abnormally:
```bash
./ai-studio.sh diagnose <component>          # Simple diagnosis (checks processes, ports, basic logs)
./ai-studio.sh diagnose <component> --deep   # Deep diagnosis (checks dependency versions, config files, RAM/VRAM usage)
./ai-studio.sh diagnose <component> --deep --fix  # Deep diagnosis and attempt to automatically fix identified issues
```

---

## 🏗️ Architecture & Design Principles

1. **Progressive Disclosure**
   - **Level 0 (Minimal)**: `start`, `stop`, `status` — Covers 90% of daily usage.
   - **Level 1 (Standard)**: `install`, `update`, `diagnose` — Covers deployment and maintenance needs.
   - **Level 2 (Advanced)**: `--target`, `--deep`, `--keep-data` — Covers fine-grained control requirements.
   - **Level 3 (Expert)**: Directly modifying configuration files in the `config/` directory or editing component scripts.

2. **Standardization**
   Every component in the `components/<name>/` directory strictly contains 8 standard scripts: `metadata.sh`, `install.sh`, `start.sh`, `stop.sh`, `status.sh`, `update.sh`, `diagnose.sh`, and `uninstall.sh`. The main script calls them through a unified interface, eliminating the need to memorize unique commands for different tools.

3. **Modularization**
   - **Core Libraries (`lib/`)**: Provide universal underlying capabilities such as logging, color output, process management, and browser control.
   - **Registry (`registry.sh`)**: Centrally manages metadata for all components (names, ports, descriptions).
   - **Components (`components/`)**: Business logic is completely isolated. Deleting a component directory will never affect other components.

4. **Universality**
   Whether it is a Python-based ComfyUI, a Node.js-based SillyTavern, or an Ollama-based QWen3, the main script abstracts away the underlying language differences through an abstraction layer, providing a perfectly consistent CLI experience to the user.

---

## 📂 Directory Structure

```text
ai-studio/
├── ai-studio.sh              # Main entry point script (CLI routing and scheduling)
├── README.md                 # Project documentation (this file)
├── LICENSE                   # GNU GPL v3 License file
├── lib/                      # Core functional libraries
│   ├── common.sh             # Universal tools (logging, colors, helper functions)
│   ├── config.sh             # Global configuration management
│   ├── env-check.sh          # System environment detection logic
│   ├── env-install.sh        # System environment installation logic
│   ├── browser.sh            # Browser auto-open control
│   ├── process.sh            # Background process and PID management
│   ├── diagnose.sh           # Universal diagnostic functions
│   └── ui.sh                 # Terminal UI rendering (progress bars, tables)
├── components/               # Component directories
│   ├── registry.sh           # Component registry
│   ├── open-webui/           # Open WebUI script set (8 standard scripts)
│   ├── sillytavern/          # SillyTavern script set
│   ├── continue-dev/         # Continue.dev script set
│   ├── fazm/                 # Fazm script set
│   ├── browser-use/          # Browser Use script set
│   ├── mlx/                  # MLX script set
│   ├── comfyui/              # ComfyUI script set
│   ├── mlx-video/            # MLX-Video script set
│   └── qwen3/                # QWen3 script set
├── config/                   # Runtime-generated global configuration files
└── logs/                     # Directory for runtime logs and diagnostic reports
```

---

## ⚖️ License

This project is licensed under the **GNU General Public License v3.0 (GNU GPL v3)**.

This means you are free to run, copy, modify, and distribute this software. However, any derivative work or modified version based on this project must also be distributed under the same GPL v3 license (adhering to the Copyleft spirit).

**The core spirit guarantees your four essential freedoms:**
- 🏃 **Freedom to Run**: You can run the program for any purpose.
- 🔍 **Freedom to Study**: You can study how the program works and change it to make it do what you wish.
- 📦 **Freedom to Distribute**: You can redistribute copies so you can help others.
- 🛠️ **Freedom to Improve**: You can distribute copies of your modified versions to others, giving the whole community a chance to benefit from your changes.

For the full legal text, please refer to the [`LICENSE`](./LICENSE) file in the root directory of this project, or visit the official GNU website: [https://www.gnu.org/licenses/gpl-3.0.html](https://www.gnu.org/licenses/gpl-3.0.html)

---
*Made with ❤️ for the macOS AI Community.*
