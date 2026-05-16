# 阶段 5：AI / 深度学习环境

## 目标

搭建深度学习开发环境，包括 NVIDIA GPU 驱动、CUDA 工具包、PyTorch 框架以及 Jupyter Lab 交互式开发环境。

## 前置依赖

- 阶段 2（Python 与开发环境）
- 一台配备 NVIDIA GPU 的电脑（或实验室 GPU 服务器访问权限）

## 任务

| 子项 | 任务 | 验收 |
|------|------|------|
| 5.1 NVIDIA 驱动与 CUDA | 安装 NVIDIA 显卡驱动；按 [CUDA 官方文档](https://developer.nvidia.com/cuda-downloads) 安装 CUDA 工具包；安装 cuDNN（可选）；验证 `nvidia-smi` 输出 GPU 信息 | `nvidia-smi` 显示 GPU 型号与驱动版本；`nvcc --version` 输出 CUDA 版本 |
| 5.2 PyTorch 环境 | 创建 Conda 环境；按 [PyTorch 官网](https://pytorch.org/) 命令安装 PyTorch（CUDA 版）；运行 `torch.cuda.is_available()` 验证 GPU 可用 | Python 中 `import torch; torch.cuda.is_available()` 返回 `True` |
| 5.3 Jupyter Lab | `conda install jupyterlab`；运行 `jupyter lab` 启动；创建 Notebook 并执行 PyTorch GPU 验证代码 | 浏览器打开 Jupyter Lab 界面；Notebook 中可调用 GPU |

## 快速参考

```bash
# 验证 GPU 驱动
nvidia-smi

# 创建深度学习环境
conda create -n deeplearning python=3.11
conda activate deeplearning

# 安装 PyTorch（以 CUDA 12.1 为例，具体命令以 pytorch.org 为准）
conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia

# 验证 GPU
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU count: {torch.cuda.device_count()}')"

# Jupyter Lab
conda install jupyterlab
jupyter lab
```

## 参考链接

- [NVIDIA 驱动下载](https://www.nvidia.com/Download/index.aspx)
- [CUDA 下载](https://developer.nvidia.com/cuda-downloads)
- [cuDNN 下载](https://developer.nvidia.com/cudnn)
- [PyTorch 官网](https://pytorch.org/)
- [Jupyter Lab 文档](https://jupyterlab.readthedocs.io/)