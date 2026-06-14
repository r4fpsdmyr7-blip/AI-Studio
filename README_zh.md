# AI Studio

**macOS 一站式 AI 工具自动化部署与管理平台**

AI Studio 是一个专为 macOS（特别是 Apple Silicon）设计的自动化部署与管理工具集。它旨在解决 AI 开发者、创作者和研究者在本地部署复杂 AI 工具链时面临的环境配置繁琐、依赖冲突、管理分散等痛点。通过高度模块化和标准化的脚本，AI Studio 让从“零环境”起步到日常运维变得前所未有的简单。

---

## ✨ 核心特性

- 🚀 **零环境起步**：自动检测 macOS 系统环境。若不符合要求，将自动安装缺失的依赖（如 Homebrew, Python, Node.js, Git, Ollama 等）；若符合，则无缝继续部署。
- 🌐 **自动唤起浏览器**：服务启动成功后，脚本会自动检测运行端口，并调用系统默认浏览器打开对应的 Web UI。
- 🧩 **高度模块化**：9 大主流 AI 组件完全独立。支持单独安装、启动、更新和卸载，组件之间互不干扰。
- 🩺 **内置自我诊断**：提供“简单诊断”与“深入诊断”两级机制，自动排查端口冲突、依赖缺失、进程僵死等问题，并支持一键自动修复 (`--fix`)。
- 📈 **渐进式披露**：从最简单的 `start/stop` 到高级的 `--target models` 更新和 `--deep` 诊断，按需展示复杂度，降低新手学习门槛。
- 🔄 **细粒度更新**：支持针对前端代码、Agent 逻辑、底层架构和模型权重进行独立更新，避免全量更新带来的时间浪费。

---

## 🛠️ 支持的组件

| 组件名称 | 描述 | 默认端口 |
| :--- | :--- | :---: |
| **Open WebUI** | 强大且美观的本地 LLM Web 交互界面 | `3000` |
| **SillyTavern** | 专注于角色扮演和高级 LLM 交互的前端 | `8000` |
| **Continue.dev** | VS Code / JetBrains 中的 AI 编程助手插件 | N/A |
| **Fazm** | macOS 原生 AI 桌面代理 (Desktop Agent) | N/A |
| **Browser Use** | AI 驱动的浏览器自动化操作工具 | `7788` |
| **MLX** | Apple 针对 Apple Silicon 优化的机器学习框架 | N/A |
| **ComfyUI** | 强大的节点式图像生成 UI (完美支持 SDXL/FLUX) | `8188` |
| **MLX-Video** | 基于 MLX 框架的高效本地视频生成工具 | N/A |
| **QWen3 Uncensored** | 无审查版 QWen3 大语言模型 (通过 Ollama 运行) | `11434` |

---

## 💻 系统要求

- **操作系统**: macOS 13.0 (Ventura) 或更高版本
- **硬件架构**: 
  - 通用组件：Intel 或 Apple Silicon (M1/M2/M3/M4)
  - **MLX / MLX-Video / ComfyUI**：**强烈推荐使用 Apple Silicon** 以获得最佳硬件加速性能
- **内存**: 最低 16GB（运行大型 LLM 或 FLUX 模型推荐 32GB 或以上）
- **磁盘空间**: 至少 50GB 可用空间（模型文件较大，建议预留 100GB+）
- **网络**: 首次安装和下载模型时需要稳定的互联网连接

---

## 🚀 快速开始

对于第一次使用且**没有任何预装环境**的用户，只需以下 4 步即可完成环境准备和首个组件的启动：

```bash
# 1. 克隆项目到本地
git clone https://github.com/r4fpsdmyr7-blip/Ai-Studio-Docs.git
cd ai-studio-docs

# 2. 赋予主脚本执行权限
chmod +x ai-studio.sh

# 3. 检测并安装系统环境 (自动安装 Homebrew, Python, Node 等缺失依赖)
./ai-studio.sh env check
./ai-studio.sh env install

# 4. 首次部署并启动 Open WebUI (启动后会自动打开浏览器)
./ai-studio.sh install open-webui
./ai-studio.sh start open-webui
```

---

## 📖 详细使用指南

AI Studio 采用**渐进式披露**设计。以下是按使用场景分类的详细命令指南。

### 1. 环境管理 (Environment)
```bash
./ai-studio.sh env check      # 仅检测系统环境是否符合要求，不执行安装
./ai-studio.sh env install    # 自动安装所有缺失的系统级依赖
./ai-studio.sh env status     # 查看当前系统环境状态概览
```

### 2. 部署与卸载 (Deployment & Uninstall)
```bash
# 首次部署 / 单独部署
./ai-studio.sh install <component>       # 单独部署指定组件 (如: comfyui)
./ai-studio.sh install all               # 首次部署所有支持的组件

# 停止及卸载
./ai-studio.sh uninstall <component>     # 卸载指定组件
./ai-studio.sh uninstall <component> --keep-data  # 卸载组件，但保留用户数据和已下载的模型
./ai-studio.sh uninstall <component> --force      # 强制卸载（忽略残留进程警告）
```

### 3. 日常使用与查看状态 (Daily Usage & Status)
```bash
# 启动与停止
./ai-studio.sh start <component>         # 启动服务（成功后自动调用浏览器打开）
./ai-studio.sh stop <component>          # 优雅停止服务
./ai-studio.sh restart <component>       # 重启服务

# 查看状态
./ai-studio.sh status                    # 查看所有组件的运行状态和端口占用
./ai-studio.sh status <component>        # 查看单个组件的详细运行状态
./ai-studio.sh list                      # 列出所有可用组件及其元数据
```

### 4. 细粒度更新 (Granular Update)
支持针对组件的不同部分进行独立更新，节省时间和带宽：
```bash
./ai-studio.sh update <component>                      # 全量更新组件
./ai-studio.sh update <component> --target frontend    # 仅更新前端代码
./ai-studio.sh update <component> --target agent       # 仅更新 Agent 逻辑
./ai-studio.sh update <component> --target architecture# 仅更新底层架构或系统依赖
./ai-studio.sh update <component> --target models      # 仅拉取/更新模型权重文件
```

### 5. 自我诊断 (Self-Diagnosis)
当服务启动失败或运行异常时，请使用诊断功能：
```bash
./ai-studio.sh diagnose <component>          # 简单诊断 (检查进程、端口、基础日志)
./ai-studio.sh diagnose <component> --deep   # 深入诊断 (检查依赖版本、配置文件、显存/内存占用)
./ai-studio.sh diagnose <component> --deep --fix  # 深入诊断并尝试自动修复发现的问题
```

---

## 🏗️ 架构与设计原则

1. **渐进式披露 (Progressive Disclosure)**
   - **Level 0 (极简)**: `start`, `stop`, `status` —— 满足 90% 的日常使用。
   - **Level 1 (标准)**: `install`, `update`, `diagnose` —— 满足部署和维护需求。
   - **Level 2 (高级)**: `--target`, `--deep`, `--keep-data` —— 满足精细化控制需求。
   - **Level 3 (专家)**: 直接修改 `config/` 目录下的配置文件或编辑组件脚本。

2. **标准化 (Standardization)**
   每个组件在 `components/<name>/` 目录下都严格包含 8 个标准脚本：`metadata.sh`, `install.sh`, `start.sh`, `stop.sh`, `status.sh`, `update.sh`, `diagnose.sh`, `uninstall.sh`。主脚本通过统一接口调用，无需记忆不同组件的特殊命令。

3. **模块化 (Modularization)**
   - **核心库 (`lib/`)**: 提供日志、颜色、进程管理、浏览器控制等底层通用能力。
   - **注册表 (`registry.sh`)**: 集中管理所有组件的元数据（名称、端口、描述）。
   - **组件 (`components/`)**: 业务逻辑完全隔离，删除某个组件目录绝不会影响其他组件。

4. **通用化 (Universality)**
   无论是基于 Python 的 ComfyUI，基于 Node.js 的 SillyTavern，还是基于 Ollama 的 QWen3，主脚本都通过抽象层屏蔽了底层语言差异，对外提供完全一致的 CLI 体验。

---

## 📂 目录结构

```text
ai-studio/
├── ai-studio.sh                  # 主入口脚本（调度器）
├── LICENSE                       # 协议
├── README.md                     # 使用文档
├── README_en.md                  # 英文使用文档
├── README_zh.md                  # 中文使用文档
│
├── lib/                          # 核心共享库
│   ├── common.sh                 # 通用工具（颜色、日志、权限检查）
│   ├── config.sh                 # 配置管理（读写配置）
│   ├── env-check.sh              # 环境检测（系统、硬件、软件）
│   ├── env-install.sh            # 环境安装（自动安装缺失依赖）
│   ├── browser.sh                # 浏览器自动打开
│   ├── process.sh                # 进程管理（PID、端口、信号）
│   ├── diagnose.sh               # 诊断引擎（简单/深入）
│   └── ui.sh                     # 渐进式披露 UI 层
│
├── env/                          # 环境安装脚本
│   ├── check-system.sh           # 系统级检测（macOS版本、芯片、内存、磁盘）
│   ├── install-homebrew.sh       # Homebrew 安装
│   ├── install-python.sh         # Python 3.11+ 安装
│   ├── install-node.sh           # Node.js 18+ 安装
│   ├── install-ollama.sh         # Ollama 安装
│   ├── install-git-lfs.sh        # Git LFS 安装
│   └── install-xcode-cli.sh      # Xcode CLI Tools 安装
│
├── components/                   # 组件目录
│   ├── registry.sh               # 组件注册表（元数据、依赖关系）
│   │
│   ├── open-webui/               # Open WebUI
│   │   ├── metadata.sh           # 组件元数据
│   │   ├── install.sh            # 首次部署
│   │   ├── start.sh              # 启动服务
│   │   ├── stop.sh               # 停止服务
│   │   ├── status.sh             # 查看状态
│   │   ├── update.sh             # 更新
│   │   ├── diagnose.sh           # 自我诊断
│   │   └── uninstall.sh          # 卸载
│   │
│   ├── sillytavern/              # SillyTavern
│   │   ├── metadata.sh           # 组件元数据
│   │   ├── install.sh            # 首次部署
│   │   ├── start.sh              # 启动服务
│   │   ├── stop.sh               # 停止服务
│   │   ├── status.sh             # 查看状态
│   │   ├── update.sh             # 更新
│   │   ├── diagnose.sh           # 自我诊断
│   │   └── uninstall.sh          # 卸载
│   │
│   ├── continue-dev/             # Continue.dev
│   │   ├── metadata.sh           # 组件元数据
│   │   ├── install.sh            # 首次部署
│   │   ├── start.sh              # 启动服务
│   │   ├── stop.sh               # 停止服务
│   │   ├── status.sh             # 查看状态
│   │   ├── update.sh             # 更新
│   │   ├── diagnose.sh           # 自我诊断
│   │   └── uninstall.sh          # 卸载
│   │
│   ├── fazm/                     # Fazm
│   │   ├── metadata.sh           # 组件元数据
│   │   ├── install.sh            # 首次部署
│   │   ├── start.sh              # 启动服务
│   │   ├── stop.sh               # 停止服务
│   │   ├── status.sh             # 查看状态
│   │   ├── update.sh             # 更新
│   │   ├── diagnose.sh           # 自我诊断
│   │   └── uninstall.sh          # 卸载
│   │
│   ├── browser-use/              # Browser Use
│   │   ├── metadata.sh           # 组件元数据
│   │   ├── install.sh            # 首次部署
│   │   ├── start.sh              # 启动服务
│   │   ├── stop.sh               # 停止服务
│   │   ├── status.sh             # 查看状态
│   │   ├── update.sh             # 更新
│   │   ├── diagnose.sh           # 自我诊断
│   │   └── uninstall.sh          # 卸载
│   │
│   ├── mlx/                      # MLX
│   │   ├── metadata.sh           # 组件元数据
│   │   ├── install.sh            # 首次部署
│   │   ├── start.sh              # 启动服务
│   │   ├── stop.sh               # 停止服务
│   │   ├── status.sh             # 查看状态
│   │   ├── update.sh             # 更新
│   │   ├── diagnose.sh           # 自我诊断
│   │   └── uninstall.sh          # 卸载
│   │
│   ├── comfyui/                  # ComfyUI (SDXL/FLUX)
│   │   ├── metadata.sh           # 组件元数据
│   │   ├── install.sh            # 首次部署
│   │   ├── start.sh              # 启动服务
│   │   ├── stop.sh               # 停止服务
│   │   ├── status.sh             # 查看状态
│   │   ├── update.sh             # 更新
│   │   ├── diagnose.sh           # 自我诊断
│   │   └── uninstall.sh          # 卸载
│   │
│   ├── mlx-video/                # MLX-Video
│   │   ├── metadata.sh           # 组件元数据
│   │   ├── install.sh            # 首次部署
│   │   ├── start.sh              # 启动服务
│   │   ├── stop.sh               # 停止服务
│   │   ├── status.sh             # 查看状态
│   │   ├── update.sh             # 更新
│   │   ├── diagnose.sh           # 自我诊断
│   │   └── uninstall.sh          # 卸载
│   │
│   └── qwen3/                    # QWen3 Uncensored
│   │   ├── metadata.sh           # 组件元数据
│   │   ├── install.sh            # 首次部署
│   │   ├── start.sh              # 启动服务
│   │   ├── stop.sh               # 停止服务
│   │   ├── status.sh             # 查看状态
│   │   ├── update.sh             # 更新
│   │   ├── diagnose.sh           # 自我诊断
│   └── └── uninstall.sh          # 卸载
│
├── config/
│   ├── ai-studio.conf            # 主配置文件
│   └── ports.conf                # 端口分配表
│
└── logs/                         # 日志目录
    └── .gitkeep
```

---

## ⚖️ 许可证 (License)

本项目采用 **GNU General Public License v3.0 (GNU GPL v3)** 许可证进行开源。

这意味着您可以自由地运行、复制、修改和分发本软件，但任何基于本项目的衍生作品也必须以相同的 GPL v3 许可证开源（即 Copyleft 精神）。

**核心精神保障您的四大自由：**
- 🏃 **自由运行**：您可以出于任何目的运行此软件。
- 🔍 **自由研究**：您可以研究软件的工作原理并根据需要进行修改。
- 📦 **自由分发**：您可以复制和分发副本。
- 🛠️ **自由改进**：您可以改进软件，并向公众发布您的改进版本。

详细信息请参阅项目根目录下的 [`LICENSE`](./LICENSE) 文件，或访问 [GNU 官方网站](https://www.gnu.org/licenses/gpl-3.0.html) 查看完整的许可证文本。

---
*Made with ❤️ for the macOS AI Community.*
```
