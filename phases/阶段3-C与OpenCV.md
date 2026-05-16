# 阶段 3：C 语言、CMake 与 OpenCV

## 目标

在 Windows 下通过 MSYS2 搭建 C/C++ 开发环境，掌握 CMake 构建系统，并从源码编译 OpenCV。

## 任务

| 子项 | 任务 | 验收 |
|------|------|------|
| 3.1 MSYS2 | 按 [MSYS2 官网](https://www.msys2.org/) 完成安装与首次 `pacman -Syu`；在 UCRT64 终端中安装 `mingw-w64-ucrt-x86_64-gcc` 工具链；确认 `gcc`、`make` 可用 | 在 UCRT64 终端执行 `gcc --version`，输出与预期套件一致 |
| 3.2 VSCode + C | 在 VSCode 中打开 C 项目；学习编写基础 `CMakeLists.txt`（`cmake_minimum_required`、`project`、`add_executable`）；使用 CMake Tools 选择 Kit 后 **Configure** 与 **Build**、断点调试 | 能编译运行至少一个 `.c` 文件；断点可命中 |
| 3.3 OpenCV | `git clone` [opencv](https://github.com/opencv/opencv) 与可选 [opencv_contrib](https://github.com/opencv/opencv_contrib)；在源码旁建独立 `build` 目录；在 MSYS2 终端中按 [Windows 从源码安装](https://docs.opencv.org/4.x/d3/d52/tutorial_windows_install.html) 执行 `cmake` 配置（含 `-G "MinGW Makefiles"`、`CMAKE_BUILD_TYPE=Release` 与 `CMAKE_INSTALL_PREFIX`）、`cmake --build`、`cmake --install` | 自建最小 CMake 项目：`find_package(OpenCV REQUIRED)`、`target_link_libraries(… ${OpenCV_LIBS})`，运行读图或 `cv::Mat` 示例成功 |

## 快速参考

```bash
# MSYS2 (UCRT64 终端)
pacman -Syu
pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-make mingw-w64-ucrt-x86_64-cmake

# 基础 CMakeLists.txt
# cmake_minimum_required(VERSION 3.10)
# project(Hello)
# add_executable(hello main.c)

# CMake 构建
cmake -B build -G "MinGW Makefiles"
cmake --build build
```

## 参考链接

- [MSYS2](https://www.msys2.org/)
- [CMake 官网](https://cmake.org/)
- [OpenCV 主仓库](https://github.com/opencv/opencv)
- [OpenCV Windows 从源码安装](https://docs.opencv.org/4.x/d3/d52/tutorial_windows_install.html)