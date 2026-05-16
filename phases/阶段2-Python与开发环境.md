# 阶段 2：Python 与开发环境

## 目标

搭建 Python 开发环境，掌握 Conda 环境管理、IDE 调试、包管理工具 uv，学习代码格式化与测试实践，并配置国内镜像源加速。

## 前置依赖

- 阶段 1（Git）

## 任务

| 子项 | 任务 | 验收 |
|------|------|------|
| 2.1 Conda | 下载 [Miniconda](https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Windows-x86_64.exe) 并安装；练习 `conda create -n <环境名> python=<版本>`、`conda activate`、`conda env list`、`conda deactivate`；在环境内 `conda install` 至少一个第三方包 | `conda activate` 后运行脚本使用的解释器属于该环境；`conda list` 可见所装包 |
| 2.2 VSCode + Python | 安装 Python 扩展；选择解释器绑定到 Conda 环境；打开工作区文件夹；运行单文件；配置一次断点并用 F5 启动调试 | 终端或调试控制台成功执行 `hello.py` |
| 2.3 Trae | 安装 [Trae](https://www.trae.cn/)；打开同一项目；完成解释器选择、运行、断点调试，流程与 2.2 对齐，[参考教程](https://www.bilibili.com/video/BV1SQo5BAEBo/) | 终端或调试控制台成功执行 `hello.py`；断点可命中 |
| 2.4 pip 清华源 | 阅读 [清华 PyPI 帮助](https://mirror.tuna.tsinghua.edu.cn/help/pypi/)；执行 `pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple`；再执行 `pip install requests` | 安装日志中下载地址主机为 `pypi.tuna.tsinghua.edu.cn` |
| 2.5 conda 清华源 | 阅读 [Anaconda 镜像帮助](https://mirror.tuna.tsinghua.edu.cn/help/anaconda/)，按文档修改用户级 `~/.condarc`；执行 `conda clean -i`；在新或已有环境中 `conda install numpy` | `conda install` 输出中索引域名为 `mirrors.tuna.tsinghua.edu.cn` |
| 2.6 uv | 按 [uv 安装文档](https://docs.astral.sh/uv/getting-started/installation/) 在 Windows 安装 uv；路径 A：项目目录 `uv venv`、激活后 `uv pip install <包>` 并运行脚本；路径 B：`uv init`、`uv add <包>`、`uv sync` 后运行入口；配置清华源：设置环境变量 `UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple` | A 或 B 跑通；安装过程走清华 PyPI |
| 2.7 代码格式化与检查 | 安装 `ruff`：`pip install ruff`；对 Python 文件运行 `ruff check` 和 `ruff format` | `ruff check` 无报错；`ruff format` 后代码格式统一 |
| 2.8 单元测试入门 | 安装 `pytest`：`pip install pytest`；为一个简单函数编写测试用例；运行 `pytest` 查看测试结果 | `pytest` 运行测试全部通过 |

## 快速参考

```bash
conda create -n lab python=3.11
conda activate lab
conda deactivate
conda env list
conda list

pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

uv venv
.venv\Scripts\activate
uv pip install requests

pip install ruff
ruff check main.py
ruff format main.py

pip install pytest
pytest
pytest -v
```

## 参考链接

- [Miniconda 下载](https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/)
- [Conda 入门教程](https://www.runoob.com/python-qt/anaconda-tutorial.html)
- [清华 PyPI 帮助](https://mirror.tuna.tsinghua.edu.cn/help/pypi/)
- [清华 Anaconda 帮助](https://mirror.tuna.tsinghua.edu.cn/help/anaconda/)
- [uv 文档](https://docs.astral.sh/uv/)
- [ruff 文档](https://docs.astral.sh/ruff/)
- [pytest 文档](https://docs.pytest.org/)
- [VSCode](https://code.visualstudio.com/)
- [Trae 中国站](https://www.trae.cn/)