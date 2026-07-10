# 引导流程

## 概述

顶层 `run.sh` / `run.ps1` 选择本机编排器。编排器读取 `MANIFEST.yaml`，按
`bootstrap_steps` 的显式顺序运行任务。原有 `scripts/<platform>/bootstrap.*`
继续作为兼容入口。

## 操作顺序

1. **预检** —— 检测操作系统、确认 Git 已安装、找到清单文件
2. **创建目录** —— 逻辑根目录和工作空间布局
3. **安装软件包** —— 操作系统软件包和开发工具链
4. **克隆仓库** —— 来自 `projects/repos.yaml` 的 Git 项目
5. **验证** —— 引导后校验

使用 `--task ID` / `-Task ID` 可以只运行一个步骤；使用 `--list-tasks` /
`-ListTasks` 可以从清单发现当前任务。直接任务和完整工作流调用同一任务实现。

## 试运行模式

所有会修改状态的脚本支持试运行。在试运行模式下：
- 不会修改文件系统
- 不会安装软件包
- 不会执行 git clone 操作
- 输出为 Agent 可解析的 `[INFO]` / `[WARN]` / `[SUCCESS]` 记录

## 幂等性

脚本设计为可安全多次执行：
- 目录创建：`mkdir -p`（已存在则跳过）
- 软件包安装：已安装则跳过（第二阶段实现）
- Git 克隆：目录已存在且是 git 仓库则跳过（第二阶段实现）
- Dotfiles：目标已存在则跳过（第三阶段实现）

## 错误处理

- `failure_policy: stop` 的步骤失败时立即停止
- `failure_policy: continue` 的步骤失败后继续验证，但最终整体返回 `1`
- 返回 `2` 的任务记录为跳过/不适用，不计为工作流失败
- 所有 `[ERROR]` 写入 stderr；其他结构化记录写入 stdout

## Agent 输出

默认文本记录形如：

```text
[INFO] 2026-01-01T00:00:00Z [create-directories] Inventory: ...
```

指定 `--output-format json` / `-OutputFormat json` 后，每行都是独立 JSON 对象，
可作为 NDJSON 流解析。两种格式都使用同一 level、component、message 语义。

## 引导后操作

引导完成后：
1. 运行 `verify` 脚本
2. 从密码管理器恢复密钥
3. 恢复云盘内容
4. 从备份恢复大型数据
5. 检查并安装只能手动安装的软件
