# 实验室入门任务

> **目标**：为实验室新成员提供一套标准化的开发环境搭建指南，覆盖四个研究生方向（计算机科学、软件工程、人工智能、嵌入式系统）的通用基础与专业工具链。
>
> **前置条件**：一台 Windows 电脑，无其他要求。
>
> **路线说明**：阶段 0 → 1 → 2 → 3 → 4 为**全体必修**的通用基础；阶段 5（AI）、阶段 6（嵌入式）根据研究方向**选做**；阶段 7（学术写作）为**全体必修**，可与前序阶段并行完成。

## 学习路线

| 阶段 | 主题 | 详细指南 | 预计时间 | 类型 |
|------|------|----------|----------|------|
| 0 | 网络与账号 | [阶段0-网络与账号.md](phases/阶段0-网络与账号.md) | 30 min | 必修 |
| 1 | Git 版本控制 | [阶段1-Git.md](phases/阶段1-Git.md) | 2 h | 必修 |
| 2 | Python 与开发环境 | [阶段2-Python与开发环境.md](phases/阶段2-Python与开发环境.md) | 3.5 h | 必修 |
| 3 | C 语言、CMake 与 OpenCV | [阶段3-C与OpenCV.md](phases/阶段3-C与OpenCV.md) | 2 h | 必修（OpenCV 选做） |
| 4 | Linux 虚拟机与容器 | [阶段4-Linux与容器.md](phases/阶段4-Linux与容器.md) | 5 h | 必修 |
| 5 | AI / 深度学习环境 | [阶段5-AI与深度学习环境.md](phases/阶段5-AI与深度学习环境.md) | 2 h | **AI 方向选做** |
| 6 | 嵌入式开发环境 | [阶段6-嵌入式开发环境.md](phases/阶段6-嵌入式开发环境.md) | 4 h | **嵌入式方向选做** |
| 7 | 学术写作与通用工具 | [阶段7-学术写作与通用工具.md](phases/阶段7-学术写作与通用工具.md) | 3 h | 必修（可并行） |

## 快速导航（验收标准）

### 阶段 0：网络与账号

| 任务 | 验收 |
|------|------|
| 配置科学上网，能稳定打开 GitHub；注册 GitHub 账号，完成邮箱验证 | 浏览器可打开 https://github.com/ 并处于已登录状态 |

### 阶段 1：Git

| 子项 | 验收 |
|------|------|
| 1.1 安装与基础配置 | `git config --global user.name` 和 `user.email` 输出正确 |
| 1.2 本地仓库操作 | 本地仓库有至少一条提交记录 |
| 1.3 远程仓库协作 | 远程仓库上能看到你的提交记录；`git push` 无需重复输入密码 |
| 1.4 分支管理 | 能展示分支合并历史 |
| 1.5 `.gitignore` | 仓库中无无关文件被跟踪 |
| 1.6 VSCode 集成 | 在 VSCode 中完成至少一次 `add` → `commit` → `push` |

### 阶段 2：Python 与开发环境

| 子项 | 验收 |
|------|------|
| 2.1 Conda | `conda activate` 后解释器属于该环境；`conda list` 可见所装包 |
| 2.2 VSCode + Python | 终端成功执行 `hello.py` |
| 2.3 Trae | 终端成功执行 `hello.py`；断点可命中 |
| 2.4 pip 清华源 | 安装日志中下载地址为 `pypi.tuna.tsinghua.edu.cn` |
| 2.5 conda 清华源 | `conda install` 输出中域名为 `mirrors.tuna.tsinghua.edu.cn` |
| 2.6 uv | A 或 B 跑通；安装过程走清华 PyPI |
| 2.7 代码格式化与检查 | `ruff check` 无报错；`ruff format` 后代码格式统一 |
| 2.8 单元测试入门 | `pytest` 运行测试全部通过 |

### 阶段 3：C 语言、CMake 与 OpenCV

| 子项 | 验收 |
|------|------|
| 3.1 MSYS2 | `gcc --version` 输出与预期套件一致 |
| 3.2 CMake 构建入门 | 能编译运行至少一个 `.c` 文件；断点可命中 |
| 3.3 OpenCV（选做） | 自建 CMake 项目，运行 `cv::Mat` 示例成功 |

### 阶段 4：Linux 虚拟机与容器

| 子项 | 验收 |
|------|------|
| 4.1 虚拟机 | 开机进入 Ubuntu 22.04 桌面或控制台登录成功 |
| 4.2 Linux 基础与 Shell | `apt update` 无源错误；本机可 SSH 登录 VM；Shell 脚本可独立运行 |
| 4.3 Docker | 浏览器能访问 compose 中声明的端口；`docker compose down` 可正常回收 |
| 4.4 VSCode 远程开发 | VSCode 左下角显示 `SSH: <虚拟机IP>` 连接成功 |
| 4.5 远程工作必备（tmux + scp） | 能用 tmux 管理持久会话；能用 scp/rsync 传输文件 |
| 4.6 AI 编程助手 | `claude` 可正常启动并响应 DeepSeek 模型 |

### 阶段 5：AI / 深度学习环境（选做）

| 子项 | 验收 |
|------|------|
| 5.1 NVIDIA 驱动与 CUDA | `nvidia-smi` 显示 GPU 信息；`nvcc --version` 输出 CUDA 版本 |
| 5.2 PyTorch 环境 | `torch.cuda.is_available()` 返回 `True` |
| 5.3 Jupyter Lab | 浏览器打开 Jupyter Lab 界面；Notebook 中可调用 GPU |

### 阶段 6：嵌入式开发环境（选做）

| 子项 | 验收 |
|------|------|
| 6.1 Keil MDK | Keil uVision 可正常启动；新建空项目编译通过 |
| 6.2 STM32CubeMX | CubeMX 成功生成 Keil 项目；可在 uVision 中编译 |
| 6.3 编译与烧录 | 开发板运行用户程序 |
| 6.4 调试入门 | 断点可命中；可查看变量实时值 |

### 阶段 7：学术写作与通用工具

| 子项 | 验收 |
|------|------|
| 7.1 Markdown 基础 | 能独立编写含表格、代码块、链接的 Markdown 文档 |
| 7.2 LaTeX 安装与配置 | `xelatex` 编译成功，输出 PDF 文件 |
| 7.3 LaTeX 论文结构 | 完成含标题、章节、图片、表格、参考文献的示例论文 |
| 7.4 VSCode + LaTeX 工作流 | 修改 `.tex` 后保存自动刷新 PDF |

## 文件结构

```
├── README.md                   # 本文件（完整学习路线）
├── phases/                     # 各阶段详细指南
│   ├── 阶段0-网络与账号.md
│   ├── 阶段1-Git.md
│   ├── 阶段2-Python与开发环境.md
│   ├── 阶段3-C与OpenCV.md
│   ├── 阶段4-Linux与容器.md
│   ├── 阶段5-AI与深度学习环境.md
│   ├── 阶段6-嵌入式开发环境.md
│   └── 阶段7-学术写作与通用工具.md
├── resources/
│   └── 常见问题.md
└── .gitignore
```

## 使用方式

1. 按阶段顺序学习，每个阶段有详细指南（`phases/` 目录）和验收标准（见上表）
2. 遇到问题先查阅 [常见问题](resources/常见问题.md)
3. **阶段 5（AI）** 和 **阶段 6（嵌入式）** 根据研究方向选做
4. **阶段 7（学术写作）** 可与阶段 1-4 并行学习

## 参考链接

| 主题 | URL |
|------|-----|
| GitHub | https://github.com/ |
| Git 官网 | https://git-scm.com/ |
| 《Pro Git》中文版 | https://git-scm.com/book/zh/v2 |
| VSCode | https://code.visualstudio.com/ |
| Trae 中国站 | https://www.trae.cn/ |
| 清华 PyPI 帮助 | https://mirror.tuna.tsinghua.edu.cn/help/pypi/ |
| 清华 Anaconda 帮助 | https://mirror.tuna.tsinghua.edu.cn/help/anaconda/ |
| uv 文档 | https://docs.astral.sh/uv/ |
| ruff 文档 | https://docs.astral.sh/ruff/ |
| pytest 文档 | https://docs.pytest.org/ |
| MSYS2 | https://www.msys2.org/ |
| CMake 官网 | https://cmake.org/ |
| VirtualBox | https://www.virtualbox.org/wiki/Downloads |
| Docker Engine 安装 | https://docs.docker.com/engine/install/ |
| Markdown 指南 | https://www.markdownguide.org/ |
| TeX Live | https://tug.org/texlive/ |

## 贡献

如需修改或补充，请提交 PR 或联系实验室管理员。