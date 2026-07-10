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
# 列出将安装的软件包
.\scripts\windows\install-packages.ps1 -DryRun -List

# 显示将创建的目录
.\scripts\windows\create-directories.ps1 -DryRun

# 显示将克隆的仓库
.\scripts\windows\clone-repositories.ps1 -DryRun

# 运行完整验证
.\scripts\windows\verify.ps1
```

```bash
# Unix 等效命令
./scripts/unix/install-packages.sh --dry-run --list
./scripts/unix/create-directories.sh --dry-run
./scripts/unix/clone-repositories.sh --dry-run
./scripts/unix/verify.sh
```

## 恢复：从零重建新机器

1. 安装操作系统
2. 安装 Git
3. 配置 GitHub SSH 或 HTTPS 认证
4. `git clone git@github.com:zgkthu23/workstation-bootstrap.git`
5. 编辑 `inventory/` 中对应你机器的清单文件
6. 试运行：`./scripts/unix/bootstrap.sh --dry-run`
7. 检查输出，确认无误
8. 执行：`./scripts/unix/bootstrap.sh`
9. 从密码管理器恢复密钥
10. 恢复云盘内容
11. 恢复大型数据 / restic 快照
12. 运行 `./scripts/unix/verify.sh`

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

详见 `docs/security.md` 和 `secrets/README.md`。

## 状态

阶段 1：框架、清单、试运行、验证 —— **已完成**
阶段 2：实际软件包安装 —— 计划中
阶段 3：Dotfile 部署（chezmoi）—— 计划中
阶段 4：密钥管理集成 —— 计划中