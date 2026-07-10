# 添加新机器

## 快速指南

### 1. 复制清单模板
```bash
cp inventory/ubuntu-main.yaml inventory/ubuntu-server.yaml
```

### 2. 编辑清单文件
```yaml
host: ubuntu-server
os: ubuntu
hostname: my-server
workspace_root: /home/deploy/workspace
data_root: /mnt/data
cloud_root: /home/deploy/cloud
scratch_root: /tmp/scratch
features:
  - common
  - python-development
  - docker
project_groups:
  - personal
  - tools
# ... 其余配置
```

### 3. 更新清单（如需要）
如果新机器需要现有清单中不包含的软件包，将其添加到
`manifests/ubuntu.yaml` 或创建机器专属的清单。

### 4. 添加到 repos.yaml（如需要）
如果新机器需要克隆尚未列出的仓库，将其添加到
`projects/repos.yaml`，并在 `hosts` 列表中加入新主机。

### 5. 测试
```bash
# 在新机器上执行：
bash ./run.sh --dry-run
bash ./scripts/unix/verify.sh --inventory inventory/ubuntu-main.yaml
```

### 6. 应用
```bash
bash ./run.sh
```

## 清单字段参考

| 字段 | 必填 | 说明 |
|------|------|------|
| `host` | 是 | 唯一机器标识符 |
| `os` | 是 | `windows`、`ubuntu` 或 `macos` |
| `hostname` | 是 | 机器主机名 |
| `workspace_root` | 是 | WORKSPACE_ROOT 的绝对路径 |
| `data_root` | 是 | DATA_ROOT 的绝对路径 |
| `cloud_root` | 否 | CLOUD_ROOT 的绝对路径 |
| `scratch_root` | 是 | SCRATCH_ROOT 的绝对路径 |
| `features` | 是 | 要启用的功能组列表 |
| `project_groups` | 是 | 要克隆的项目组列表 |
| `git_user_name` | 否 | Git user.name（模板） |
| `git_user_email` | 否 | Git user.email（模板） |
| `install_docker` | 否 | 是否安装 Docker |
| `install_c_dev` | 否 | 是否安装 C/C++ 工具链 |
| `install_python_dev` | 否 | 是否安装 Python 工具链 |
| `install_node_dev` | 否 | 是否安装 Node.js 工具链 |
| `install_office` | 否 | 是否安装办公工具 |
