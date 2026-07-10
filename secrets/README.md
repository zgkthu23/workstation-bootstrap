# 密钥

本目录仅包含此 README，不存放任何实际文件。

## 这里应该放什么

什么都不放。这个目录是一个占位符，提醒你密钥在本仓库之外管理。

## 密钥如何管理

所有密钥（API 密钥、Token、密码、SSH 私钥）存储在密码管理器（1Password、Bitwarden 等）中，在模板和脚本中通过条目名称引用。

## 恢复流程

在新机器上设置时：
1. 安装你的密码管理器
2. 登录并同步你的保险库
3. 使用 `../templates/` 中的模板创建实际配置文件
4. 切勿将那些实际文件提交到本仓库

## 本仓库引用的内容

- `templates/env.example` — 列出环境变量名称
- `templates/gitconfig.example` — 不含真实邮箱的 git 配置
- `templates/ssh-config.example` — 不含真实主机名的 SSH 配置

## 提交前保护

`tests/test_no_secrets.py` 扫描会在每次提交时运行，以捕获意外提交的密钥。如果不小心提交了密钥，请参阅 `docs/security.md` 了解处理方式。