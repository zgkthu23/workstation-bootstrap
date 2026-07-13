# Agent 入口

本仓库是声明式工作站配置。**没有脚本、解析器或验证器需要执行**；Agent 读取声明，先展示完整计划，经用户确认后直接在操作系统上执行。

## 硬性边界

- 不把 token、密码、API key 或私钥写入仓库。
- 不猜主机、平台、占位符或缺失映射。
- `templates/` 仅供参考，永远不参与解析，也不要直接复制到实际路径。
- 任何机器变更前，必须展示完整解析结果：路径、设置、工具及 provider、显式跳过、仓库及目标目录。
- 所有操作先检测后执行且保持幂等；已安装工具、已有目录和已克隆仓库跳过。

## 确定性读取顺序

1. 读取 `MANIFEST.yaml`。
2. 获取真实 hostname；在 `hosts/*.yaml` 的 `match.hostnames` 中要求恰好一个匹配。零个或多个匹配都停止并询问用户。
3. 按 host 的 `profiles` 顺序完整读取 `profiles/<id>.yaml`。
4. 读取 `catalog/bundles.yaml`，解析 bundle 引用。
5. 读取 `catalog/tools.yaml`，解析工具、依赖和平台目标。
6. 读取 `catalog/repositories.yaml`，解析项目组。

所有活动 YAML 必须是 `schema_version: 2`，ID 必须为稳定的小写 kebab-case。未知 ID、重复 ID、重复仓库目标目录均在修改机器前报错。

## 合并规则

### Profiles 与 host overrides

1. 按 profile 顺序对 `bundles` 和 `project_groups` 做稳定并集。
2. 多个 profile 的同名 setting 若值不同则报错；host 明确覆盖该 setting 时例外。
3. 应用 host 的 bundle/tool/project `include`。
4. 最后应用所有 `exclude`；排除永远获胜。
5. 同一工具既 required 又 optional 时只保留一次并视为 required。
6. 路径以 `MANIFEST.yaml` 为默认值，host 的 `paths` 逐项覆盖。仅在执行前展开 `~`，声明中保持 portable path。

### 工具与平台目标

- 平台字段为 `os`、可选的 `distro`、`arch`、`environment`。
- 一个 target 兼容的条件是其 `when` 每个字段都与 host platform 相等。
- 选择兼容 target 中 `when` 字段最多者。最高 specificity 并列是歧义错误。
- required 工具无兼容 target：在任何 mutation 前失败。optional 工具无兼容 target：显示并跳过。
- `unsupported` target 无论工具状态都必须显示原因并跳过。
- target 必须且只能含一个 `install` 或 `unsupported`。安装 provider 只允许：`apt`、`brew-formula`、`brew-cask`、`winget`、`npm-global`、`official-installer`、`manual`。
- target-local `dependencies` 只在选中该 target 时加入，参与去重并做拓扑排序；依赖环报错。
- channel 只约束 runtime 大版本或 LTS；未声明 channel 的工具跟随 provider stable。
- `official-installer` 和 `manual` 只给 HTTPS source/documentation。下载后先检查官方说明与内容，不执行未经检查的管道命令。

### 仓库

- profile 解析出的 `project_groups` 选择仓库，再应用 host project include/exclude。
- clone 目标为 `repository_root/<group>/<directory>`；两个项目得到同一目标时报错。
- URL 含 `PUT_YOUR_*` 时显示并跳过，不猜地址。
- `optional: true` 的 clone 失败只报告；required clone 失败则停止。

## 执行顺序

```text
1. resolve-and-show-plan       # 完整解析；所有错误必须在 mutation 前暴露
2. configure-network          # 若解析到 network-client，先配置客户端与 proxy setting
3. install-package-manager    # macOS: brew；Windows: winget；Ubuntu: apt
4. create-directories         # 解析后的 workspace/data/scratch/repository 路径
5. install-tools              # 拓扑顺序；先检测后安装
6. clone-repositories         # 按解析顺序，排除和占位符已处理
7. verify                     # 使用 catalog 中的 verify hint 检查关键工具
```

每一步完成、跳过或失败都向用户报告。代理设置写入用户明确选择的 shell 配置；不要在仓库里记录凭据或私有代理订阅。
