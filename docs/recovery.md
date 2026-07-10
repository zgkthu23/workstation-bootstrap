# 恢复：从零重建新机器

## 前提条件

- [ ] 操作系统已安装并更新
- [ ] 网络连接正常
- [ ] 可访问 GitHub 账号
- [ ] 可访问密码管理器

## 逐步操作

### 1. 安装操作系统
使用默认设置安装操作系统。创建你的用户账号。

### 2. 安装 Git
```bash
# Ubuntu
sudo apt install git

# macOS
xcode-select --install  # 包含 git
# 或：brew install git

# Windows
winget install Git.Git
```

### 3. 配置 GitHub 访问
```bash
# SSH（推荐）
ssh-keygen -t ed25519 -C "your-email@example.com"
# 将 ~/.ssh/id_ed25519.pub 添加到 GitHub → Settings → SSH Keys
ssh -T git@github.com  # 验证

# 或使用 HTTPS + PAT
git config --global credential.helper store
# 设置 GH_TOKEN 或 GITHUB_TOKEN 环境变量
```

### 4. 克隆本仓库
```bash
git clone git@github.com:zgkthu23/workstation-bootstrap.git
cd workstation-bootstrap
```

### 5. 编辑你的清单文件
编辑 `inventory/<your-machine>.yaml`：
- 设置正确的主机名
- 设置正确的路径
- 启用需要的功能组
- 设置 git 用户信息

### 6. 试运行
```bash
# Unix
./scripts/unix/bootstrap.sh --dry-run

# Windows
.\scripts\windows\bootstrap.ps1 -DryRun
```

### 7. 检查并确认
仔细阅读试运行输出。确认：
- 将创建正确的目录
- 将安装正确的软件包
- 将克隆正确的仓库
- 没有意外的修改

### 8. 执行引导
```bash
# Unix
./scripts/unix/bootstrap.sh

# Windows
.\scripts\windows\bootstrap.ps1
```

### 9. 恢复密钥
从密码管理器中恢复：
- SSH 密钥（如果不使用新生成的）
- API 令牌（GitHub、OpenAI、Claude 等）
- 数据库凭证
- 项目的 `.env` 文件

### 10. 恢复云盘
- 登录 OneDrive / Google Drive / iCloud
- 等待文件同步完成

### 11. 恢复大型数据
- 从 restic / 外部硬盘恢复
- 重新下载数据集和模型

### 12. 验证
```bash
# Unix
./scripts/unix/verify.sh

# Windows
.\scripts\windows\verify.ps1
```

## 预估时间

| 步骤 | 时间 |
|------|------|
| 操作系统安装 | 30-60 分钟 |
| Git + GitHub 配置 | 10 分钟 |
| 引导（自动化） | 15-30 分钟 |
| 云同步 | 1-24 小时（取决于数据量） |
| 数据恢复 | 1-8 小时（取决于数据量） |
| **人工操作总计** | **约 1 小时** |
| **实际耗时总计** | **2-24 小时** |