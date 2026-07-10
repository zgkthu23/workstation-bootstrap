# Dotfiles

## 当前状态（第一阶段）

此目录为 chezmoi 管理的 dotfiles 预留，目前尚未部署。

## 计划（第三阶段）

将使用 [chezmoi](https://chezmoi.io/) 管理跨平台 dotfiles：

- `common/` — 所有平台共享的配置模板
- `windows/` — Windows 专属配置（PowerShell profile、Windows Terminal 等）
- `ubuntu/` — Ubuntu 专属配置（bashrc、tmux.conf 等）
- `macos/` — macOS 专属配置（zshrc、macOS 默认值等）

## 安全说明

Dotfiles 中**不得**包含：
- Shell 历史
- Token、API 密钥
- SSH 私钥
- Cookie
- 浏览器用户数据
- 明文密码
- 真实的 .env 文件