# AI Studio

**A Unified, Modular, and Automated AI Tool Deployment & Management Platform for macOS**
**专为 macOS 设计的统一、模块化、自动化 AI 工具部署与管理平台**

AI Studio is a comprehensive bash-script-based toolkit designed to simplify the deployment, management, and maintenance of local AI tools on macOS. Assuming a "zero-environment" starting point, it automatically detects system requirements, installs missing dependencies, and provides a standardized interface for daily operations, granular updates, and self-diagnosis.
AI Studio 是一个基于 Bash 脚本的综合工具集，旨在简化 macOS 上本地 AI 工具的部署、管理和维护。它假设用户处于“零环境”起点，会自动检测系统要求、安装缺失的依赖，并为日常操作、细粒度更新和自我诊断提供标准化的接口。

---

## 🌟 Features / 核心特性

- **🚀 Zero-Configuration Start (零环境起步)**: Automatically detects macOS environment. If requirements are not met, it installs them (Homebrew, Python, Node.js, Git, Ollama, etc.) before proceeding. / 自动检测 macOS 环境，若不符合要求则自动安装依赖，符合则继续部署。
- **🌐 Auto-Open Browser (自动唤起浏览器)**: Services automatically trigger the system default browser to open the Web UI upon successful startup. / 服务启动成功后，自动调用系统默认浏览器打开 Web 界面。
- **🧩 Modular & Independent (高度模块化)**: All 9 components are deployed and managed independently. Installing or uninstalling one does not affect others. / 所有组件独立部署和管理，互不干扰。
- **🩺 Self-Diagnosis (自我诊断)**: Built-in simple and deep diagnostic modes to identify port conflicts, missing dependencies, or process issues, with an optional auto-fix feature. / 内置简单和深入两级诊断模式，排查端口冲突、依赖缺失或进程问题，并支持自动修复。
- **🔄 Granular Updates (细粒度更新)**: Update specific targets independently: `frontend`, `agent`, `architecture`, or `models`. / 支持针对前端、Agent、底层架构或模型进行独立更新，避免全量更新的时间浪费。
- **📈 Progressive Disclosure (渐进式披露)**: Commands are designed from simple daily operations to advanced expert configurations, revealing complexity only when needed. / 命令设计从简单的日常操作到高级专家配置，按需展示复杂度。

---

## 🛠️ Supported Components / 支持的组件

| Component / 组件 | Description / 描述 | Default Port / 默认端口 |
| :--- | :--- | :---: |
| **Open WebUI** | Powerful Web UI for LLMs / 强大的 LLM Web 交互界面 | `3000` |
| **SillyTavern** | Advanced frontend for LLM roleplay and chatting / 专注于角色扮演的高级 LLM 前端 | `8000` |
| **Continue.dev** | AI coding assistant for VS Code / JetBrains / VS Code 的 AI 编程助手 | N/A |
| **Fazm** | Native macOS AI Desktop Agent / macOS 原生 AI 桌面代理 | N/A |
| **Browser Use** | AI-driven browser automation tool / AI 驱动的浏览器自动化工具 | `7788` |
| **MLX** | Apple's machine learning framework for Apple Silicon / Apple Silicon 优化的 ML 框架 | N/A |
| **ComfyUI** | Node-based image generation UI (SDXL/FLUX support) / 节点式图像生成 UI (支持 SDXL/FLUX) | `8188` |
| **MLX-Video** | Efficient video generation tool powered by MLX / 基于 MLX 的高效视频生成工具 | N/A |
| **QWen3 Uncensored**| Uncensored QWen3 LLM running via Ollama / 通过 Ollama 运行的无审查版 QWen3 模型 | `11434` |

---

## 💻 System Requirements / 系统要求

- **OS**: macOS 13.0 (Ventura) or later.
- **Hardware**: 
  - General components: Intel or Apple Silicon (M1/M2/M3/M4).
  - **MLX / MLX-Video / ComfyUI**: **Requires Apple Silicon** for optimal performance.
- **RAM**: Minimum 16GB (32GB+ recommended for large LLMs or FLUX models).
- **Storage**: At least 50GB free space (100GB+ recommended for model weights).
- **Network**: Stable internet connection required for initial deployment and model downloads.

---

## 🚀 Quick Start / 快速开始

```bash
# 1. Clone the repository / 克隆仓库
git clone https://github.com/r4fpsdmyr7-blip/AI-Studio-Docs.git
cd ai-studio-docs

# 2. Make the main script executable / 赋予主脚本执行权限
chmod +x ai-studio.sh

# 3. Check and install system environment (auto-installs missing dependencies) 
#    检测并安装系统环境（自动安装缺失的依赖）
./ai-studio.sh env check
./ai-studio.sh env install

# 4. Install and start a component (e.g., Open WebUI). Browser will open automatically.
#    安装并启动组件（例如 Open WebUI），启动后会自动打开浏览器。
./ai-studio.sh install open-webui
./ai-studio.sh start open-webui
```

---

## 📖 Detailed Usage Guide / 详细使用指南

### 1. Environment Management / 环境管理
```bash
./ai-studio.sh env check      # Check system requirements only / 仅检测系统环境
./ai-studio.sh env install    # Install all missing dependencies / 安装所有缺失的依赖
./ai-studio.sh env status     # View current environment status / 查看当前环境状态
```

### 2. Component Lifecycle / 组件生命周期管理
```bash
# Installation & Uninstallation / 安装与卸载
./ai-studio.sh install <component>            # Install a single component / 单独部署组件
./ai-studio.sh install all                    # Initial deployment of all components / 首次部署所有组件
./ai-studio.sh uninstall <component>          # Uninstall component / 卸载组件
./ai-studio.sh uninstall <component> --keep-data # Uninstall but keep user data/models / 卸载但保留数据和模型

# Daily Usage / 日常使用
./ai-studio.sh start <component>              # Start service & auto-open browser / 启动服务并自动打开浏览器
./ai-studio.sh stop <component>               # Stop service gracefully / 优雅停止服务
./ai-studio.sh restart <component>            # Restart service / 重启服务

# Status / 查看状态
./ai-studio.sh status                         # View status of all components / 查看所有组件状态
./ai-studio.sh status <component>             # View detailed status of one component / 查看单个组件详细状态
./ai-studio.sh list                           # List all available components / 列出所有可用组件
```

### 3. Granular Updates / 细粒度更新
```bash
./ai-studio.sh update <component>                      # Full update / 全量更新
./ai-studio.sh update <component> --target frontend    # Update frontend only / 仅更新前端
./ai-studio.sh update <component> --target agent       # Update agent logic only / 仅更新 Agent
./ai-studio.sh update <component> --target architecture# Update underlying architecture/deps / 仅更新架构/依赖
./ai-studio.sh update <component> --target models      # Pull/update model weights only / 仅更新模型
```

### 4. Self-Diagnosis / 自我诊断
```bash
./ai-studio.sh diagnose <component>          # Simple diagnosis (process, port, basic logs) / 简单诊断
./ai-studio.sh diagnose <component> --deep   # Deep diagnosis (deps, config, memory/GPU usage) / 深入诊断
./ai-studio.sh diagnose <component> --deep --fix # Deep diagnosis with auto-fix / 深入诊断并尝试自动修复
```

---

## 🏗️ Architecture & Design Principles / 架构与设计原则

1. **Progressive Disclosure (渐进式披露)**: Commands are layered. Level 0 (`start/stop`) for daily use, Level 1 (`install/update`) for maintenance, Level 2 (`--target/--deep`) for advanced control.
2. **Standardization (标准化)**: Every component strictly implements 8 standard scripts: `metadata.sh`, `install.sh`, `start.sh`, `stop.sh`, `status.sh`, `update.sh`, `diagnose.sh`, `uninstall.sh`.
3. **Modularization (模块化)**: Core libraries (`lib/`) handle universal logic (logging, process management). Components (`components/`) contain isolated business logic.
4. **Universality (通用化)**: The main script abstracts away the differences between Python, Node.js, or Rust-based tools, providing a unified CLI experience.

---

## 📂 Directory Structure / 目录结构

```text
ai-studio/
├── ai-studio.sh              # Main entry point / 主入口脚本
├── README.md                 # Bilingual documentation / 中英双语文档
├── LICENSE                   # GNU GPL v3 License / 许可证文件
├── lib/                      # Core libraries / 核心库
│   ├── common.sh             # Logging, colors, helpers / 通用工具
│   ├── config.sh             # Configuration management / 配置管理
│   ├── env-check.sh          # Environment detection / 环境检测
│   ├── env-install.sh        # Dependency installation / 环境安装
│   ├── browser.sh            # Browser auto-open control / 浏览器控制
│   ├── process.sh            # PID and process management / 进程管理
│   ├── diagnose.sh           # Diagnostic functions / 诊断函数
│   └── ui.sh                 # Terminal UI rendering / 终端 UI
├── components/               # Component scripts / 组件脚本
│   ├── registry.sh           # Component registry / 组件注册表
│   ├── open-webui/           # (Contains 8 standard scripts)
│   ├── sillytavern/
│   ├── continue-dev/
│   ├── fazm/
│   ├── browser-use/
│   ├── mlx/
│   ├── comfyui/
│   ├── mlx-video/
│   └── qwen3/
├── config/                   # Runtime configurations / 运行时配置
└── logs/                     # Logs and diagnostic reports / 日志与诊断报告
```

---

## ⚖️ License / 许可证

This project is licensed under the **GNU General Public License v3.0 (GNU GPL v3)**.

**Summary of your rights / 您的权利摘要:**
- **Freedom to Run**: You can run the software for any purpose. / 您可以出于任何目的运行此软件。
- **Freedom to Study**: You can study how the program works and change it. / 您可以研究软件的工作原理并根据需要进行修改。
- **Freedom to Distribute**: You can redistribute copies. / 您可以复制和分发副本。
- **Freedom to Improve**: You can distribute copies of your modified versions to others. / 您可以向公众发布您的改进版本。

**Copyleft Requirement / Copyleft 要求:**
Any derivative work or modified version of this project must also be distributed under the same GNU GPL v3 license, ensuring the software remains free and open source. / 任何基于本项目的衍生作品或修改版本，也必须以相同的 GNU GPL v3 许可证进行分发，以确保软件保持自由和开源。

For the full legal text, please see the [`LICENSE`](./LICENSE) file in the root directory, or visit: [https://www.gnu.org/licenses/gpl-3.0.html](https://www.gnu.org/licenses/gpl-3.0.html)

---
