# AGENTS.md

本仓库面向实验室新成员与科研开发人员，提供开发环境标准化、研究方向工具链配置、工程实践模板、AI 辅助开发规范与自动化质量验证。本文件是仓库级规则；`windows11_env/AGENTS.md` 是子工程规则，冲突时以子工程为准。

## 目录职责

| 目录 | 职责 |
|---|---|
| `phases/` | 分阶段教程，按章节手动操作 |
| `resources/` | 常见问题与工具推荐 |
| `windows11_env/` | Windows 11 自动化搭建工程，入口 `bootstrap.ps1` |
| `ubuntu_env/` | Ubuntu 服务器初始化工程 |
| `skills/` | 仓库级可执行操作规程 |
| `.github/workflows/` | CI：PowerShell 检查、提交信息校验 |

## 硬约束

1. Windows 主链路不使用 WSL、Docker、Dev Container；Docker 与 Dev Container 只在 Linux 环境（Ubuntu 服务器、虚拟机、`ubuntu_env`）中使用。
2. Windows 环境搭建只经 `windows11_env/bootstrap.ps1`；不新增平行安装脚本。
3. 新项目的 Python 依赖只经 `uv` 锁定；不在系统 Python 或 Conda base 中安装包。
4. Windows 用户目录必须为纯 ASCII；`bootstrap.ps1` 在写入前检查 `USERPROFILE` 与 `USERNAME`。
5. 仓库不保存个人姓名、个人邮箱、API Key 或供应商令牌；个人值只写入 gitignore 的文件，模板使用占位符。
6. 解压必须限制在目标目录内，拒绝越界路径。
7. 文档只陈述当前事实与约定，不使用防御性写作。

## 工程规范

### Git

- 提交信息使用 Conventional Commits：`<type>(<scope>): <subject>`。
- type 取 `feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`build`、`ci`、`chore`、`revert`。
- 提交信息由 CI 的 `Commit Messages` 工作流校验；本地提交前先确认格式。
- 一次提交只做一件事；数据文件与逻辑改动分开提交。

### 代码

- `.ps1` 与 `.psm1` 保存为 UTF-8 带 BOM；`.cmd` 注释只写 ASCII；其余文本文件使用 UTF-8。
- 编码、缩进与行尾由 `.editorconfig` 约束。
- 路径参数使用绝对路径，不依赖当前工作目录。
- 新增或修改 PowerShell 脚本必须同时满足 `just lint-ps` 零 Error 与 `just test-ps` 全部通过。

### 测试

- 行为变更必须附带测试；修复缺陷先补失败用例。
- Pester 用例放在 `windows11_env/tests/`，测试不依赖真实用户配置与管理员权限。
- `ubuntu_env` 脚本使用 `shellcheck` 与 `bats` 验证。

### 文档

- 每个项目根目录必须提供 README。
- 文档中的命令、路径与包清单必须与 `data/` 和各项目实现一致。
- 文档不记录个人身份、机器特定数值或历史迁移过程。

### 安全

- 提交前执行 `gitleaks protect --staged --no-banner`。
- 解压归档前校验每个条目都落在目标目录内。

## Skills

实施前先确定本轮使用哪些 Skills，并把清单写入计划。仓库级 Skills 位于 `skills/`：

| Skill | 用途 |
|---|---|
| `windows-bootstrap` | Windows 环境搭建、验收、回滚与失败定位 |
| `repo-delivery` | 提交前门禁、CI 校验与交付检查 |

Skill 必须包含可执行命令、验收标准与退出码；无法执行验证的内容不纳入。

机器级 Agent Skills 由 `windows11_env/scripts/sync-skills.ps1` 同步，清单在 `windows11_env/data/skills.json`，安装到 `%USERPROFILE%\.agents\skills`。`bootstrap.ps1` 的 Config 阶段默认执行同步，`-SkipSkills` 跳过；新增技能包必须提供来源与用途，安装后能在 `npx skills list -g` 中定位。

## 验证命令

Windows 环境（在 `windows11_env/` 下执行）：

| 场景 | 命令 | 判定 |
|---|---|---|
| 搭建计划 | `just bootstrap-dry` | 退出码 0，系统无变化 |
| 环境验收 | `just verify` | 退出码 0 |
| 回滚 | `just rollback` | 退出码 0 |
| 静态检查 | `just lint-ps` | 零 Error |
| 单元测试 | `just test-ps` | 全部通过 |
| 环境体检 | `just doctor` | 输出无缺失项 |

仓库级：

| 场景 | 命令 | 判定 |
|---|---|---|
| 提交信息 | CI `Commit Messages` | 全部提交符合 Conventional Commits |
| PowerShell CI | CI `CI` | lint 与 test 均通过 |
| 密钥扫描 | `gitleaks protect --staged --no-banner` | 无发现 |

执行验证后必须引用具体命令与退出码，不用主观判断代替结果。

## 变更流程

1. 计划：列出受影响的目录与阶段、使用的 Skills、验收命令。
2. 实施：先改 `data/` 再改逻辑；小步修改，保持可回滚。
3. 验证：运行对应命令并记录退出码；失败先修复再继续。
4. 汇报：改动文件、验证结果、未完成项与下一步。

## 网络

- `github.com:443` 直连被阻断；HTTPS 克隆或下载发布包前执行 `windows11_env/scripts/proxy-on.ps1`。
- 包管理器统一使用 `data/mirrors.json` 定义的国内镜像。
- `api.github.com` 与 SSH 22 端口直连可用。
