# 阶段 2：Python 与开发环境

## 目标

用 uv 搭建 Python 项目环境，掌握依赖锁定、代码格式化、单元测试与编辑器调试，配置国内镜像；Conda 作为需要原生依赖时的选修方案。

## 前置依赖

- 阶段 1（Git）

## 任务

| 子项 | 任务 | 验收 |
|------|------|------|
| 2.1 uv | 按 [uv 安装文档](https://docs.astral.sh/uv/getting-started/installation/) 在 Windows 安装 uv；用 `uv init` 建项目、`uv add requests` 添加依赖、`uv run python main.py` 运行；再用 `uv venv` 与 `uv pip install` 的方式走一遍 | 两种方式都能跑通；`pyproject.toml` 与 `uv.lock` 由 uv 生成 |
| 2.2 ruff | 用 `uvx ruff check` 与 `uvx ruff format` 检查、格式化代码，或 `uv add --dev ruff` 加入项目 | `ruff check` 无报错，格式化后风格统一 |
| 2.3 pytest | `uv add --dev pytest`；为一个简单函数编写测试用例；`uv run pytest` 运行 | 测试全部通过 |
| 2.4 国内镜像 | 设置用户环境变量 `UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple`，阅读 [清华 PyPI 帮助](https://mirror.tuna.tsinghua.edu.cn/help/pypi/)；用 `uv add` 安装包并观察下载域名 | 安装日志中下载地址主机为 `pypi.tuna.tsinghua.edu.cn` |
| 2.5 VSCode | 安装 [VSCode](https://code.visualstudio.com/)；打开项目并选择 `.venv` 解释器；运行单文件；配置断点并用 F5 启动调试 | 调试控制台成功执行 `hello.py`，断点可命中 |
| 2.6 Trae | 安装 [Trae](https://www.trae.cn/)；打开同一项目，完成解释器选择、运行与断点调试，流程与 2.5 对齐，[参考教程](https://www.bilibili.com/video/BV1SQo5BAEBo/) | 终端或调试控制台成功执行 `hello.py`；断点可命中 |
| 2.7 Conda（选修） | 需要 CUDA、编译器等非 PyPI 原生依赖或课程指定时，下载 [Miniconda](https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Windows-x86_64.exe) 安装；练习 `conda create`、`conda activate`、`conda env list`；按 [清华 Anaconda 帮助](https://mirror.tuna.tsinghua.edu.cn/help/anaconda/) 配置 `~/.condarc` | `conda activate` 后解释器属于该环境；`conda install` 输出中索引域名为 `mirrors.tuna.tsinghua.edu.cn` |

项目依赖只安装到项目环境，不在系统 Python 或 MSYS2 自带的 Python 中装包。

## 快速参考

```bash
# uv 项目流程（默认）
uv init lab
cd lab
uv add requests
uv run python main.py
uv run pytest

# uv 虚拟环境流程
uv venv
.venv\Scripts\activate
uv pip install requests

# 检查、格式化与锁定
uvx ruff check
uvx ruff format
uv lock
uv sync

# Conda（选修）
conda create -n lab python=3.11
conda activate lab
conda env list
conda deactivate
```

## 参考链接

- [uv 文档](https://docs.astral.sh/uv/)
- [uv 安装](https://docs.astral.sh/uv/getting-started/installation/)
- [pixi 文档](https://pixi.sh/)
- [清华 PyPI 帮助](https://mirror.tuna.tsinghua.edu.cn/help/pypi/)
- [Miniconda 下载](https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/)
- [清华 Anaconda 帮助](https://mirror.tuna.tsinghua.edu.cn/help/anaconda/)
- [ruff 文档](https://docs.astral.sh/ruff/)
- [pytest 文档](https://docs.pytest.org/)
- [VSCode](https://code.visualstudio.com/)
- [Trae 中国站](https://www.trae.cn/)
