# 架构

## Agent 控制入口

仓库采用“导航、契约、执行、任务、数据”五层结构：

```text
AGENTS.md                 Agent 阅读顺序与安全规则
└── MANIFEST.yaml         结构、接口、执行图、脚本目录
    ├── run.sh / run.ps1  跨平台规范入口
    └── orchestrate.*     按 bootstrap_steps 选择和串联任务
        └── task.*        可独立运行的幂等任务或显式占位任务

inventory/ + manifests/ + projects/   声明式数据
scripts/lib/                         双平台统一运行契约
```

Agent 不需要扫描整个仓库来推断入口或顺序。读取 `AGENTS.md` 和
`MANIFEST.yaml` 后即可发现目标 inventory、平台脚本、参数转发、输出格式和退出码。
脚本文件名不决定顺序，`bootstrap_steps.order` 才是执行顺序的唯一来源。

## 控制平面 vs 数据平面

```
┌─────────────────────────────────────────────────┐
│                控制平面                           │
│        （本仓库：workstation-bootstrap）           │
│                                                  │
│  inventory/   manifests/   scripts/   dotfiles/  │
│  ─────────   ──────────   ────────   ─────────  │
│  主机定义     功能组        引导        配置      │
│                           自动化       模板      │
└─────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌─────────────────────────────┐
│    数据平面      │  │       数据平面               │
│   (workspace)   │  │   (cloud / data / scratch)   │
│                 │  │                              │
│  repos/         │  │  OneDrive、Google Drive、    │
│  artifacts/     │  │  iCloud 文档                 │
│  shared/        │  │                              │
│                 │  │  大型数据集、模型             │
│  各项目独立      │  │  备份（restic）              │
│  Git 管理       │  │                              │
└─────────────────┘  └─────────────────────────────┘
```

本仓库是**控制平面**。它描述应该存在什么。
**数据平面**是磁盘上的实际文件 —— 仓库、文档、数据集。
控制平面永远不包含数据平面的内容。

## 逻辑目录模型

所有主机共享相同的逻辑模型，通过清单文件映射到各主机专属的绝对路径。

| 逻辑根目录 | 用途 | Windows 默认路径 | Unix 默认路径 |
|-----------|------|-----------------|--------------|
| `WORKSPACE_ROOT` | Git 仓库、开发项目 | `C:\Users\zgk23\workspace` | `$HOME/workspace` |
| `DATA_ROOT` | 大型数据、模型、数据集 | `C:\Users\zgk23\data` | `$HOME/data` |
| `CLOUD_ROOT` | 云盘文档 | 清单中定义 | `$HOME/cloud` |
| `SCRATCH_ROOT` | 临时、可丢弃文件 | `C:\Users\zgk23\scratch` | `$HOME/scratch` |

## 工作空间布局

```
WORKSPACE_ROOT/
├── repos/           # 按分类组织的 Git 克隆
│   ├── work/        # 工作项目
│   ├── personal/    # 个人项目
│   ├── research/    # 研究 / 学术
│   ├── tools/       # 第三方工具、实用程序
│   └── experiments/ # 一次性原型
├── artifacts/       # 构建产物，不受版本控制
│   ├── releases/    # 二进制发布
│   ├── reports/     # 生成的报告
│   └── exports/     # 数据导出
└── shared/          # 跨项目共享资源
    ├── templates/   # 项目模板
    └── scripts/     # 共享实用脚本
```

## 主机清单

`inventory/` 中每个主机有一个 YAML 文件，定义：
- 身份信息（主机名、操作系统）
- 物理路径映射
- 启用的功能组
- Git 用户信息模板

清单文件中不含密钥。

## 清单

`manifests/` 定义每个功能组*安装什么*：
- `common.yaml` —— 每台机器都需要的工具
- `windows.yaml` / `ubuntu.yaml` / `macos.yaml` —— 各操作系统专属补充

## 功能组

| 组 | 包含内容 |
|----|---------|
| `common` | Git、Shell、编辑器、基础 CLI 工具 |
| `c-development` | GCC/Clang、CMake、make、调试器 |
| `python-development` | Python、uv、常用库 |
| `node-development` | Node.js、npm、pnpm |
| `docker` | Docker Engine、docker-compose |
| `office` | 文档工具、PDF 阅读器 |
| `research` | LaTeX、Jupyter、科学计算 |
| `optional` | 锦上添花的实用工具 |

## Dotfiles 策略

见下方专门章节。

## Dotfiles：方案对比

### 已评估的方案

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| **chezmoi** | 模板化、diff、试运行、跨平台、密钥管理 | 多一个二进制依赖 | ✅ 推荐 |
| **GNU Stow** | 简单、基于符号链接、无额外依赖 | 无模板、需手动适配各机器 | 仅适用于纯 Unix |
| **符号链接** | 零依赖、透明 | 无模板、Windows 下脆弱、需手动操作 | 极简方案 |
| **直接复制** | 极其简单 | 无版本追踪、有漂移风险 | ❌ 不推荐 |

### 推荐方案：chezmoi

- 单一二进制文件，无运行时依赖
- 使用 Go 模板实现按机器定制
- 内置 diff 和试运行
- `chezmoi apply` 是幂等的
- 密码管理器集成（1Password、Bitwarden 等）
- 支持 Windows、Linux、macOS

阶段 1：集成接口已定义，示例 dotfiles 已创建。
阶段 3：完整 chezmoi 配置。

## 脚本设计

`MANIFEST.yaml` 是 Agent 和编排器共同读取的机器契约：

```
MANIFEST.yaml
    └── run.{sh,ps1}                  # 跨平台入口
        └── scripts/<platform>/orchestrate.*
            ├── create-directories   # 目录结构
            ├── install-packages     # Phase-1 占位，返回 2
            ├── clone-repositories   # Phase-1 占位，返回 2
            └── verify               # 引导后校验

scripts/<platform>/bootstrap.*        # 原路径兼容入口
scripts/lib/                          # 双平台共享运行契约
```

编排器从 `bootstrap_steps` 读取顺序、平台脚本路径、转发参数、跳过选项和失败策略，不在代码中重复定义执行图。旧的 `bootstrap.{ps1,sh}` 保留为兼容入口。

所有脚本都有标准 `SCRIPT-METADATA` 自描述块和 `--help` / `-Help` 接口。
默认文本输出和可选 NDJSON 输出拥有同一字段语义：stdout 使用 `INFO`、`WARN`、
`SUCCESS`，stderr 使用 `ERROR`；退出码 `0` 表示成功、`1` 表示错误、`2` 表示
跳过或不适用。任务既可独立运行，也可通过同一个清单执行图串联。
