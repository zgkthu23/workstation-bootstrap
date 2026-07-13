# workstation-bootstrap

声明式工作站配置。**没有安装脚本，Agent 直接读取声明文件并执行。**

## 安装

```bash
git clone git@github.com:zgkthu23/workstation-bootstrap.git ~/workstation-bootstrap
```

然后告诉 Claude Code 或 Codex：

```
Read ~/workstation-bootstrap/AGENTS.md and configure this machine.
```

Agent 会检测操作系统、安装依赖、配置代理、安装软件包、克隆仓库。

## 仓库结构

```
workstation-bootstrap/
├── AGENTS.md              ← Agent 入口（Agent 先读这个）
├── README.md              ← 人类入口
├── hosts/                 ← 主机定义
│   ├── macos-main.yaml
│   ├── ubuntu-main.yaml
│   └── windows-main.yaml
├── packages/              ← 软件包声明
│   ├── common.yaml        ← 所有 OS 通用
│   ├── macos.yaml
│   ├── ubuntu.yaml
│   └── windows.yaml
├── repositories.yaml      ← Git 仓库声明
├── templates/             ← 配置模板（示例）
└── .gitignore
```

## 主机配置

`hosts/<name>.yaml` 定义了一台机器：

```yaml
host: macos-main
os: macos
hostname: My-MacBook.local
workspace_root: /Users/zgk/workspace
features:
  - networking
  - common
  - python-development
  - node-development
  - ai-tools
project_groups:
  - personal
  - work
```

## 功能组

`packages/<os>.yaml` 按功能组声明软件包。Agent 读取 `features` 列表，安装对应包。

## 仓库克隆

`repositories.yaml` 声明要克隆的 Git 仓库。只有 `hosts` 列表包含当前主机名的仓库才会克隆。

## 更新配置

编辑声明文件，提交，推送。在其他机器上拉取后重新告诉 Agent 配置即可。

## 不管理的内容

- 个人文件、云盘内容、大型数据集
- 密钥、Token、API Key（这些只存在于系统环境变量中）
- 操作系统安装、磁盘分区