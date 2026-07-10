# workstation-bootstrap

个人工作站基础设施即代码 —— 以声明式方式定义并重建开发机目录布局、软件包、dotfiles
和 Git 项目结构，覆盖 Windows、Ubuntu 和 macOS。

## 管理范围

- 目录结构（workspace、data、cloud、scratch 根目录）
- 开发工具包和工具链
- Dotfiles 和 Shell 配置
- Git 项目布局和克隆目标
- 环境变量模板

## 不管理的内容

- 个人文件、文档、照片、媒体
- 云盘内容（OneDrive、Google Drive、iCloud）
- 大型数据集和模型权重（使用 restic / 独立备份）
- 应用数据、浏览器配置文件、聊天记录
- 密钥、Token、SSH 私钥、API 密钥
- 操作系统安装或磁盘分区

## 支持的主机

| 主机 | 操作系统 | 角色 |
|------|---------|------|
| windows-main | Windows 11 | 主力开发桌面 |
| ubuntu-main | Ubuntu LTS | Linux 开发 / 服务器 |
| macos-main | macOS | 移动 / 辅助开发 |

## 快速开始

```powershell
# Windows (PowerShell 7+)
.\scripts\windows\bootstrap.ps1 -DryRun
.\scripts\windows\bootstrap.ps1 -DryRun -WhatIf  # 别名
```

```bash
# Ubuntu / macOS
./scripts/unix/bootstrap.sh --dry-run
```

## 试运行示例

```powershell
# 显示将创建的目录
.\scripts\windows\create-directories.ps1 -DryRun

# 运行完整验证
.\scripts\windows\verify.ps1 -Inventory .\inventory\windows-main.yaml

# 完整试运行（仅创建目录 + 验证）
.\scripts\windows\bootstrap.ps1 -DryRun
```

```bash
# Unix 等效命令
./scripts/unix/create-directories.sh --dry-run --inventory inventory/ubuntu-main.yaml
./scripts/unix/verify.sh --inventory inventory/ubuntu-main.yaml
./scripts/unix/bootstrap.sh --dry-run
```

> 注意：第一阶段中，软件包安装和仓库克隆为占位实现，会输出计划但不会执行实际安装。

## 恢复：从零重建新机器

详见 `docs/recovery.md`。

## 添加新机器

1. 从 `inventory/` 复制现有清单文件
2. 编辑路径、主机名、启用的功能组
3. 将机器专属软件包添加到对应的清单中
4. 试运行 → 验证 → 应用

详见 `docs/adding-a-machine.md`。

## 安全

**此仓库必须保持私有。** 其中包含主机布局、已安装软件清单和项目 URL ——
这些信息对攻击者有价值。

切勿提交：
- API 密钥、Token、密码
- SSH 私钥
- 包含真实值的 `.env` 文件
- 浏览器或 Shell 历史记录
- 云盘访问令牌

详见 `docs/security.md`。

## 状态

阶段 1：框架、清单、试运行、验证 —— **已完成**
阶段 2：实际软件包安装 —— 计划中
阶段 3：Dotfile 部署（chezmoi）—— 计划中
阶段 4：密钥管理集成 —— 计划中