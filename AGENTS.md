# Agent 入口

本仓库是声明式工作站配置。**没有任何脚本需要执行**——你（Agent）读取这些文件，理解目标，然后直接在操作系统上执行。

## 工作流程

按顺序读取：

1. **`hosts/<hostname>.yaml`** — 我是谁：主机名、OS、路径、启用的功能、要克隆的项目组
2. **`packages/common.yaml`** — 所有 OS 通用的核心工具
3. **`packages/<os>.yaml`** — 当前 OS 的专属包（按功能分组）
4. **`repositories.yaml`** — 要克隆的 Git 仓库

## 执行规则

- **先检测后操作**：先 `uname -s` 确定 OS，缺失的包管理器先装（macOS 装 brew，Windows 确认 winget）
- **网络优先**：如果 `features` 里有 `networking`，先配置代理（GFW 环境）
- **幂等**：包已安装就跳过，目录已存在就跳过，仓库已克隆就跳过
- **不猜测**：`PUT_YOUR_*` 占位符是未填项，跳过后提醒用户
- **不写入密钥**：不要在仓库文件中写入任何 token、密码、API key
- **报告结果**：每步完成或失败都向用户报告

## 引导顺序

```
1. configure-network   ← 配置代理（GFW 环境，必须先做）
2. install-package-manager ← 确保 brew / winget / apt 可用
3. create-directories  ← 创建 workspace 目录结构
4. install-packages    ← 按 features 安装软件包
5. clone-repositories  ← 克隆 Git 仓库
6. verify              ← 检查关键工具可用
```

## 功能组 → 安装动作

| feature | 做什么 |
|---------|--------|
| `networking` | 安装 v2rayN，写入 `HTTP_PROXY`/`HTTPS_PROXY` 到 shell rc |
| `common` | 安装 git、curl、node、python、VS Code 等核心工具 |
| `c-development` | 安装 C/C++ 工具链 |
| `python-development` | 安装 Python 3.12 + uv |
| `node-development` | 安装 Node.js LTS + pnpm |
| `ai-tools` | 安装 Claude Code（native installer） + Codex CLI |
| `shell` | 安装 zsh 插件（zsh-autosuggestions、zsh-syntax-highlighting） |
| `docker` | 安装 Docker |
| `office` | 安装 LibreOffice 等办公工具 |
| `research` | 安装 LaTeX、pandoc、Zotero、R、Julia |
| `optional` | 安装 VLC、GIMP、Thunderbird 等可选工具 |

## 仓库克隆

`repositories.yaml` 中 `hosts` 包含当前主机名的仓库才克隆。`optional: true` 的仓库克隆失败不中断。

## 模板文件

`templates/` 下的示例文件是给用户参考的，不要直接复制到实际路径。提示用户按需修改后使用。