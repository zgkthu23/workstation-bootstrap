# workstation-bootstrap

声明式、由 Agent 执行的工作站配置。仓库描述“要什么”，没有安装脚本、resolver 或 validator；Agent 按 [AGENTS.md](AGENTS.md) 的确定性规则展示完整计划并执行。

## 使用

```bash
git clone git@github.com:zgkthu23/workstation-bootstrap.git ~/workstation-bootstrap
```

然后告诉 Claude Code 或 Codex：

```text
Read ~/workstation-bootstrap/AGENTS.md and configure this machine.
```

未知或重复 hostname 不会被猜测，Agent 会停止并要求选择或补充 host。

macOS 有多个名称来源；本仓库使用 `scutil --get LocalHostName` 并追加 `.local` 作为规范 hostname。`hostname` 的输出可能随系统或网络状态变化，`ComputerName` 只作为隔空投送、蓝牙和共享界面的展示名称，不参与 host 匹配。

## 结构

```text
MANIFEST.yaml                 schema v2 入口、默认路径、读取和合并规则
hosts/<machine-id>.yaml       可自动选择的真实机器及本机例外
profiles/<profile-id>.yaml    可组合角色
catalog/tools.yaml            逻辑工具及平台 provider
catalog/bundles.yaml          required/optional 工具组
catalog/repository-groups.yaml 顶层仓库分组及 README 内容
catalog/repositories.yaml     按 project group 选择的仓库
repository-groups/<group>/     各顶层仓库分组的 README source
templates/                    未完成主机和配置示例（不参与解析）
AGENTS.md                     Agent 执行协议
README.md                     人类入口
```

活动 YAML 都使用 `schema_version: 2` 和小写 kebab-case ID。默认路径为 `~/workspace`、`~/data`、`~/scratch`，仓库默认克隆到 `~/workspace/repos/<group>/<directory>`。

## 解析模型

Host 选择 profiles；profiles 选择 bundles 和 project groups；bundles 引用逻辑 tools；每个 tool 再按 host platform 选择最具体的 provider target。

- profile 按 host 中的顺序做稳定并集。
- host include 在 profile 之后加入，exclude 最后应用且获胜。
- required 与 optional 重复时 required 获胜。
- tool target 按 `when` 字段数选择最具体匹配，并列报错。
- 先用 `verify` hint 或平台存在性检测已有工具；可用即满足，不要求来自声明的 provider。
- provider 只用于安装缺失工具；版本输出仅报告，channel 只指导缺失工具的新安装，不触发现有工具升级、降级或重装。
- required 无映射、未知引用、依赖环和仓库目标冲突都在修改机器前停止。
- optional 无映射、显式 `unsupported` 和 `PUT_YOUR_*` URL 会显示并跳过。

仓库根目录使用五个稳定 group：`personal`、`learning`、`tools`、`work`、`research`。每个 group 的 README 由 `catalog/repository-groups.yaml` 声明，只在目标 README 缺失时创建，不覆盖用户已有内容。

完整规范见 [MANIFEST.yaml](MANIFEST.yaml) 和 [AGENTS.md](AGENTS.md)。

## Secrets 与凭据

仓库只声明 secret 的存储 backend、查找标识、consumer 和进程环境变量名，永远不保存 token、密码、API key 或私钥。macOS secret 存在 Keychain 中，仅在指定 consumer 进程启动时注入；不全局导出到 shell，不写入 `.env` 或另一个 credential store。

```yaml
secrets:
  github-cli-token:
    backend: macos-keychain
    service: github-cli-gh-token
    required: true
    expose_as: GH_TOKEN
    exposure: process-only
    consumers: [github-cli]
```

## 添加真实主机

从 `templates/*-host.example.yaml` 的字段结构手工创建新文件，不要把仍含占位符的文件放入 `hosts/`：

```yaml
schema_version: 2
id: lab-ubuntu
match:
  hostnames: [lab-01]
platform:
  os: linux
  distro: ubuntu
  arch: x86_64
  environment: native
profiles: [gfw-network, base, developer, server]
paths: {}
overrides:
  bundles: {include: [], exclude: [desktop-development]}
  tools: {include: [], exclude: [gdb]}
  projects: {include: [], exclude: [dotfiles]}
  settings: {}
```

只有非默认路径才写入 `paths`。hostname 必须使用对应平台的规范来源，且不能与其他 active host 重叠。

## 添加工具或平台映射

逻辑工具只定义一次。新增 Linux distro 只给相关工具追加 target，不创建新的 OS-wide package 文件：

```yaml
- id: example-tool
  description: Example CLI
  targets:
    - when: {os: macos}
      install: {provider: brew-formula, package: example-tool}
      verify: {command: example-tool, version_argument: --version}
    - when: {os: linux, distro: ubuntu}
      install: {provider: apt, package: example-tool}
    - when: {os: linux, distro: fedora}
      install: {provider: manual, source: https://example.org/releases, documentation: https://example.org/install}
    - when: {os: windows}
      unsupported: upstream does not publish a Windows build
```

每个 target 必须恰好有一个 `install` 或 `unsupported`。不要嵌入 `curl | sh`、PowerShell 管道或其他 shell command。

## 添加 profile

在 `profiles/<id>.yaml` 中只组合共享选择和非敏感 setting：

```yaml
schema_version: 2
id: data-science
description: Shared data science role
bundles: [base-cli, python-development, research-cli]
project_groups: [research]
settings: {}
```

机器特有例外留在 host overrides，不复制 profile。

## 添加仓库

```yaml
- id: simulation-tools
  url: git@github.com:example/simulation-tools.git
  group: research
  directory: simulation-tools
  optional: false
  description: Simulation utilities
```

不要添加 host 数组。通过 profile project group 选择，再用 host project include/exclude 处理少数例外。

## 迁移说明

schema v1 的 macOS、Ubuntu、Windows 有效意图已记录在 `templates/migration-baseline.yaml`，用于对比 schema v2。Ubuntu 和 Windows 原文件含未知 hostname/用户名，因此已变成不参与解析的模板；没有为尚未提供的机器编造身份。

迁移只做归一化：Node、Python、CMake、Claude Code 和 Codex 各自归入唯一 bundle；Ubuntu Zotero 改为官方手动来源；Windows diagrams.net 使用当前 `JGraph.Draw` ID；v2rayN 的 macOS/Ubuntu 映射改用官方 release 来源。Python 3.12 与 Node LTS 是缺失 runtime 的新安装偏好，不用于替换本机已有的可用版本；其余新安装跟随 provider stable。

## 不管理的内容

- 个人文件、云盘内容、大型数据集
- 密钥、Token、API Key
- 操作系统安装和磁盘分区
