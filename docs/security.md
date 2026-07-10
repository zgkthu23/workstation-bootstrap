# 安全

## 仓库分类

此仓库应保持**私有**。其中包含：
- 主机布局和已安装软件清单
- 项目 URL 和组织结构
- 开发环境配置

能够访问此仓库的攻击者可能：
- 绘制你的开发基础设施地图
- 识别已安装软件版本以进行定向攻击
- 发现内部项目 URL 和仓库名称

## 仓库中允许的内容

| 类别 | 允许 | 示例 |
|------|------|------|
| 配置模板 | ✅ | `.env.example`、`config.yaml.example` |
| 环境变量名 | ✅ | `DATABASE_URL`、`API_KEY`（仅名称） |
| 密码管理器条目名 | ✅ | `"GitHub PAT"`、`"AWS Access Key"` |
| 公钥 | ✅ | `id_ed25519.pub`、`*.pub` |
| 示例文件 | ✅ | 带 `.example` 扩展名的文件 |
| 软件包列表 | ✅ | `apt-packages.txt`、`Brewfile` |
| 目录结构 | ✅ | 路径、布局定义 |

## 绝对禁止的内容

| 类别 | 示例 |
|------|------|
| API 密钥 | `sk-...`、`ghp_...`、`xoxb-...` |
| 私钥 | `id_rsa`、`*.pem`、`*.key` |
| 密码 | 数据库密码、服务密码 |
| 令牌 | GitHub PAT、OpenAI 密钥、Claude 密钥 |
| Cookie | 浏览器 Cookie、会话令牌 |
| 真实 `.env` 文件 | `.env`、`.env.local`、`.env.production` |
| 公司凭证 | 工作密码、含密钥的 VPN 配置 |
| 浏览器数据 | Chrome/Firefox 配置文件、历史记录 |
| Shell 历史 | `.bash_history`、`.zsh_history` |
| 含主机的 SSH 配置 | `~/.ssh/config` 中的真实主机名和 IP |

## 提交前保护

`tests/test_no_secrets.py` 扫描在每次提交时运行（通过 GitHub Actions），
也可在本地运行：

```bash
uv run python tests/test_no_secrets.py
```

扫描内容：
- 私钥头（`-----BEGIN.*PRIVATE KEY-----`）
- API 密钥模式（`sk-*`、`ghp_*`、`xoxb-*` 等）
- 密钥赋值（`SECRET=`、`TOKEN=`、`PASSWORD=`）
- AWS 密钥模式（`AKIA*`、`ASIA*`）
- 可疑上下文中的高熵 base64 字符串

## 如果不小心提交了密钥

1. **立即轮换密钥** —— 撤销并重新生成
2. 运行 `git filter-branch` 或 `git filter-repo` 从历史记录中清除
3. 强制推送
4. 用 `test_no_secrets.py` 验证

## 密码管理器集成

所有密钥应存放在密码管理器（1Password、Bitwarden 等）中。
本仓库仅通过条目名称引用它们。

示例：`templates/env.example` 包含：
```
# 复制到 .env 并从密码管理器填入
DATABASE_URL=    # Bitwarden："project-db-url"
API_KEY=         # 1Password："project-api-key"
```