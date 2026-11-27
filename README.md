# 实验室入门任务

面向实验室新成员与科研开发人员，提供开发环境标准化、研究方向工具链配置、工程实践模板、AI 辅助开发规范与自动化质量验证，构成一套轻量化研发基础设施。

仓库包含两条路径：`phases/` 按章节手动操作，`windows11_env/` 与 `ubuntu_env/` 提供自动化环境搭建。仓库级规则见 [AGENTS.md](AGENTS.md)，可执行操作规程见 `skills/`。

前置条件：一台 Windows 电脑。如对计算机硬件与软件基础尚不熟悉，可先阅读 [认识你的电脑](https://www.criwits.top/missing/computer-and-its-components.html) 了解 CPU、内存、硬盘等基本概念。

> **重要提示**：Windows 默认禁止运行 PowerShell 脚本，使用 Conda、uv 等工具时可能出现权限错误。请以管理员身份打开 PowerShell，执行以下命令解除限制：
>
> ```powershell
> # 执行
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```
>
> 该命令仅对当前用户生效，仅允许运行受信任来源的脚本，建议完成环境搭建后保持此设置不变。

各阶段遇到问题请查看 [常见问题](resources/常见问题.md) 中的解决方案，涉及 Shell、Git、调试等内容可参考 [MIT Missing Semester](https://missing.csail.mit.edu/) 作为补充。

## 学习路线

| 阶段 | 主题                  | 详细指南                                            | 预计时间   |
| -- | ------------------- | ----------------------------------------------- | ------ |
| 0  | 网络与账号               | [阶段0-网络与账号.md](phases/阶段0-网络与账号.md)             | 30 min |
| 1  | Git 版本控制            | [阶段1-Git.md](phases/阶段1-Git.md)                 | 2 h    |
| 2  | Python 与开发环境        | [阶段2-Python与开发环境.md](phases/阶段2-Python与开发环境.md) | 3.5 h  |
| 3  | C 语言、CMake 与 OpenCV | [阶段3-C与OpenCV.md](phases/阶段3-C与OpenCV.md)       | 2 h    |
| 4  | Linux 虚拟机与容器        | [阶段4-Linux与容器.md](phases/阶段4-Linux与容器.md)       | 5 h    |
| 5  | AI / 深度学习环境         | [阶段5-AI与深度学习环境.md](phases/阶段5-AI与深度学习环境.md)     | 2 h    |
| 6  | 嵌入式开发环境             | [阶段6-嵌入式开发环境.md](phases/阶段6-嵌入式开发环境.md)         | 4 h    |
| 7  | 学术写作与通用工具           | [阶段7-学术写作与通用工具.md](phases/阶段7-学术写作与通用工具.md)     | 3 h    |

## 文件结构

```
├── README.md
├── AGENTS.md                 仓库级规则：约束、规范、Skills 与验证命令
├── .editorconfig             编码、缩进与行尾约定
├── .github/
│   ├── workflows/
│   │   ├── ci.yml            PowerShell 静态检查与单元测试
│   │   └── commitlint.yml    Conventional Commits 校验
│   └── pull_request_template.md
├── phases/
│   ├── 阶段0-网络与账号.md
│   ├── 阶段1-Git.md
│   ├── 阶段2-Python与开发环境.md
│   ├── 阶段3-C与OpenCV.md
│   ├── 阶段4-Linux与容器.md
│   ├── 阶段5-AI与深度学习环境.md
│   ├── 阶段6-嵌入式开发环境.md
│   └── 阶段7-学术写作与通用工具.md
├── resources/
│   ├── 常见问题.md
│   └── 常用工具推荐.md
├── skills/
│   ├── windows-bootstrap/SKILL.md
│   └── repo-delivery/SKILL.md
├── ubuntu_env/               Ubuntu 服务器初始化
├── windows11_env/
│   ├── README.md
│   ├── bootstrap.ps1
│   ├── Justfile
│   ├── AGENTS.md
│   ├── data/
│   ├── docs/
│   ├── src/
│   ├── scripts/
│   └── tests/
└── .gitignore
```

## 使用方式

1. 按阶段顺序学习，每个阶段有详细指南和验收标准
2. 遇到问题先查阅 [常见问题](resources/常见问题.md)
3. [常用工具推荐](resources/常用工具推荐.md) 为参考资料，供选择

## 自动化方式

`phases/` 是手动路径，按章节逐步操作；`windows11_env/` 面向 Windows 新机，入口为 `bootstrap.ps1`，支持演练、验收与回滚，细节见 [windows11_env/README.md](windows11_env/README.md)。全新 Windows 11 首次运行可用系统自带的 Windows PowerShell 5.1 启动入口；入口会安装 PowerShell 7 与 just，再以 pwsh 重启。`ubuntu_env/` 面向 Ubuntu 服务器初始化。仓库级规则见 [AGENTS.md](AGENTS.md)，可执行流程见 `skills/`。

## 参考链接

| 主题                   | URL                                                                |
| -------------------- | ------------------------------------------------------------------ |
| MIT Missing Semester | <https://missing.csail.mit.edu/>                                   |
| 菜鸟教程                 | <https://www.runoob.com/>                                          |
| Hello 算法             | <https://www.hello-algo.com/>                                      |
| Hello Agents         | <https://datawhalechina.github.io/hello-agents/>                   |
| 认识你的电脑               | <https://www.criwits.top/missing/computer-and-its-components.html> |
| Missing Semester 2026 | <https://missing.csail.mit.edu/2026/>                               |
| OSSU 计算机科学自学课表        | <https://cs.ossu.dev/>                                             |
| CS50x                 | <https://cs50.harvard.edu/x/>                                      |

各阶段专用链接已分别列在对应阶段文档的"参考链接"章节中，常用工具推荐见 [resources/常用工具推荐.md](resources/常用工具推荐.md)。

## 贡献

如需修改或补充，请提交 PR。
