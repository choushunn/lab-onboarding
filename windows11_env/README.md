# 新机开发环境与系统优化

本仓库是新机的自动搭建参考工程：一个入口 `bootstrap.ps1`，声明式数据在 `data/`，两份文档分别覆盖开发环境与系统环境。

## 快速开始

```powershell
.\bootstrap.ps1 -Profile All -DryRun
.\bootstrap.ps1 -Profile All
```

首次运行会询问 Git 身份、AI 供应商与模型、CC Switch 路由端口，答案写入 gitignore 的 `data/user.json`。仓库不保存个人姓名、邮箱、API Key 或供应商令牌。

`bootstrap.ps1` 在开始时检查 `USERPROFILE` 与 `USERNAME`：含中文或其他非 ASCII 字符时直接退出 2，须切换到英文用户名账户后重跑。

## 文档

| 文档 | 内容 |
|---|---|
| [开发环境搭建](docs/开发环境搭建.md) | 工作空间、基础工具、语言运行时、嵌入式 CLI、国内镜像、阶段与验收 |
| [系统环境优化](docs/系统环境优化.md) | 系统软件清单、保守可回滚设置、System Profile、回滚 |

## 常用命令

| 命令 | 作用 |
|---|---|
| `just bootstrap` | 开发环境 + 系统优化 |
| `just bootstrap-dry` | 只输出计划，不提权、不修改系统 |
| `just verify` | 开发环境验收 |
| `just rollback` | 回滚最近一次配置变更，不卸载软件 |
| `just doctor` | 当前进程环境只读体检 |
| `just lint-ps` / `just test-ps` | PowerShell 静态检查与测试 |

## 项目结构

```text
bootstrap.ps1                 唯一安装入口：参数、提权、阶段调度、汇总、退出码
Justfile                      搭建、验收、回滚与语言验证入口
src/WsBootstrap/              阶段、包、配置、回滚实现
data/                         包、镜像、路径、模板与用户配置示例
docs/                         开发环境搭建、系统环境优化
scripts/                      check-env、proxy-on 与 PSScriptAnalyzer 配置
tests/                        Pester 测试与用户配置 fixture
AGENTS.md                     代理规则唯一真源
```

## 边界

- 不安装 WSL、Docker、Dev Container；全部 Windows 原生。
- 机器级阶段需要管理员权限；`-NoElevate` 只跳过机器级阶段。
- 回滚不卸载已安装软件，只还原配置文件、PATH、环境变量、注册表值与 Defender 排除项；运行后被修改的文件保留现状并记为冲突。
- Defender 排除项默认关闭，`-EnableDevExclusions` 才添加。
- 仓库不保存密钥、令牌或个人配置备份；提交信息使用 Conventional Commits。
