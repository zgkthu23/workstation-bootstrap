# workstation-bootstrap

以声明式方式定义并重建 Windows、Ubuntu 和 macOS 开发机的目录布局、软件包计划、
dotfiles 接口和 Git 项目结构。当前仓库既是人类可维护的基础设施配置，也是 Agent
可发现、可组合、可解析执行的控制平面。

Agent 从 [`AGENTS.md`](AGENTS.md) 开始；机器契约和完整执行图位于
[`MANIFEST.yaml`](MANIFEST.yaml)。人类可直接使用根目录的 `run.ps1` 或 `run.sh`，
原有 `scripts/<platform>/bootstrap.*` 路径继续兼容。

## 快速开始

PowerShell 7+：

```powershell
.\run.ps1 -ListTasks
.\run.ps1 -DryRun
.\run.ps1 -Task create-directories -DryRun
.\run.ps1 -DryRun -OutputFormat json
```

Ubuntu / macOS：

```bash
bash ./run.sh --list-tasks
bash ./run.sh --dry-run
bash ./run.sh --task create-directories --dry-run
bash ./run.sh --dry-run --output-format json
```

每个任务仍可直接运行，具体接口通过 `--help` / `-Help` 自描述；任务与平台映射见
[`scripts/README.md`](scripts/README.md)。

## 稳定执行契约

- `MANIFEST.yaml` 的 `bootstrap_steps` 是唯一执行顺序来源。
- 文本输出固定为 `[LEVEL] ISO-8601 [COMPONENT] MESSAGE`。
- JSON 输出为 NDJSON；每行包含 `schema_version`、`timestamp`、`level`、
  `component` 和 `message`。
- `INFO`、`WARN`、`SUCCESS` 写 stdout，`ERROR` 写 stderr。
- 退出码 `0` 表示成功，`1` 表示失败，`2` 表示跳过或当前不适用。
- 完整流程会记录子任务的 `2` 并继续；单任务模式会原样返回 `2`。

## 管理边界与当前功能

当前已实现并保持原有行为：

- 按 inventory 幂等创建 workspace、data、cloud、scratch 与工作区子目录；
- 校验 inventory、Git、包管理器、仓库清单和潜在密钥；
- 通过 dry-run 安全预览目录变更；
- 软件包安装和仓库克隆仍是 Phase 1 占位实现，不会执行实际变更。

本仓库不管理个人文件、云盘内容、大型数据集、应用数据、密钥、操作系统安装或磁盘分区。
inventory 和模板中的 `PUT_YOUR_*` 值必须在使用前按目标机器调整，但不得写入密钥。

## 验证

```powershell
uv run --quiet python tests/validate_manifests.py
uv run --quiet python tests/test_no_secrets.py
```

架构、引导、恢复和安全细节见 [`docs/architecture.md`](docs/architecture.md)、
[`docs/bootstrap.md`](docs/bootstrap.md)、[`docs/recovery.md`](docs/recovery.md) 和
[`docs/security.md`](docs/security.md)。
