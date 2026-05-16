# 实验室入门任务

为实验室新成员提供一套标准化的开发环境搭建指南，覆盖计算机科学、软件工程、人工智能、嵌入式系统开发等方向的通用基础与专业工具链。

前置条件：一台 Windows 电脑，无其他要求。如对计算机硬件与软件基础尚不熟悉，可先阅读 [认识你的电脑](https://www.criwits.top/missing/computer-and-its-components.html) 了解 CPU、内存、硬盘等基本概念。

> **重要提示**：Windows 默认禁止运行 PowerShell 脚本，使用 Conda、uv 等工具时可能出现权限错误。请以管理员身份打开 PowerShell，执行以下命令解除限制：
>
> ```powershell
> # 执行
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```
> 该命令仅对当前用户生效，仅允许运行受信任来源的脚本，建议完成环境搭建后保持此设置不变。

路线说明：阶段 0 至 4 为全体必修的通用基础；阶段 5 和阶段 6 根据研究方向选做；阶段 7 为全体必修，可与前序阶段并行完成。各阶段涉及 Shell、Git、调试等内容可参考 [MIT Missing Semester](https://missing.csail.mit.edu/) 作为补充。

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
└── .gitignore
```

## 使用方式

1. 按阶段顺序学习，每个阶段有详细指南和验收标准
2. 遇到问题先查阅 [常见问题](resources/常见问题.md)
3. 阶段 5 和阶段 6 根据研究方向选做
4. 阶段 7 可与阶段 1 至 4 并行学习
5. [常用工具推荐](resources/常用工具推荐.md) 为参考资料，可随时查阅

## 参考链接

| 主题                   | URL                                                                |
| -------------------- | ------------------------------------------------------------------ |
| GitHub               | <https://github.com/>                                              |
| Git 官网               | <https://git-scm.com/>                                             |
| Pro Git 中文版          | <https://git-scm.com/book/zh/v2>                                   |
| VSCode               | <https://code.visualstudio.com/>                                   |
| 清华 PyPI 帮助           | <https://mirror.tuna.tsinghua.edu.cn/help/pypi/>                   |
| 清华 Anaconda 帮助       | <https://mirror.tuna.tsinghua.edu.cn/help/anaconda/>               |
| uv 文档                | <https://docs.astral.sh/uv/>                                       |
| MSYS2                | <https://www.msys2.org/>                                           |
| CMake 官网             | <https://cmake.org/>                                               |
| VirtualBox           | <https://www.virtualbox.org/wiki/Downloads>                        |
| Docker Engine 安装     | <https://docs.docker.com/engine/install/>                          |
| Markdown 指南          | <https://www.markdownguide.org/>                                   |
| MIT Missing Semester | <https://missing.csail.mit.edu/>                                   |
| 菜鸟教程                 | <https://www.runoob.com/>                                          |
| 考拉软件                 | <https://www.kaolarj.com/>                                         |
| Anna's Archive       | <https://shadowlibraries.github.io/DirectDownloads/AnnasArchive/>  |
| TeX Live             | <https://tug.org/texlive/>                                         |
| 认识你的电脑               | <https://www.criwits.top/missing/computer-and-its-components.html> |

## 贡献

如需修改或补充，请提交 PR。
