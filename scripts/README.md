# Script contract

所有可执行脚本都满足同一运行契约：顶部 `SCRIPT-METADATA` 描述用途和接口，
`--help` / `-Help` 可独立发现参数，日志通过平台共享运行库输出，退出码只使用
`0`、`1`、`2`。

## 分层

```text
run.sh / run.ps1                         canonical launchers
└── scripts/<platform>/orchestrate.*     manifest-driven orchestration
    ├── create-directories.*             implemented, idempotent task
    ├── install-packages.*               Phase-1 non-mutating placeholder
    ├── clone-repositories.*             Phase-1 non-mutating placeholder
    └── verify.*                         implemented verification task

scripts/<platform>/bootstrap.*           legacy compatibility launchers
scripts/lib/common.bash                  Unix runtime module
scripts/lib/Bootstrap.Common.psm1        PowerShell runtime module
```

## 对等接口

| 概念 | Bash | PowerShell |
|---|---|---|
| inventory | `--inventory PATH` | `-Inventory PATH` |
| manifest | `--manifest PATH` | `-Manifest PATH` |
| 单任务 | `--task ID` | `-Task ID` |
| dry-run | `--dry-run` | `-DryRun` |
| Agent 输出 | `--output-format json` | `-OutputFormat json` |
| 发现任务 | `--list-tasks` | `-ListTasks` |
| 帮助 | `--help` | `-Help` |

任务脚本不接受与自身无关的选项。编排器只转发 `MANIFEST.yaml` 中每步 `forwards`
明确声明的参数，因此任务可直接运行，也可安全串联。

## 独立运行示例

```bash
bash scripts/unix/create-directories.sh \
  --inventory inventory/ubuntu-main.yaml --dry-run --output-format json
```

```powershell
.\scripts\windows\create-directories.ps1 `
  -Inventory .\inventory\windows-main.yaml -DryRun -OutputFormat json
```

占位任务独立运行时返回 `2`。这不是失败；它表示该阶段尚未适用。完整编排器会记录
这一状态并继续后续验证。
