# 阶段 3：C 语言、CMake 与 OpenCV

## 目标

在 Windows 下通过 MSYS2 搭建 C/C++ 开发环境，掌握 CMake 构建系统。从源码编译 OpenCV 为可选任务，AI 与嵌入式方向推荐完成。

## 前置依赖

- 阶段 1（Git）

## 任务

| 子项 | 任务 | 验收 |
|------|------|------|
| 3.1 MSYS2 | 按 [MSYS2 官网](https://www.msys2.org/) 完成安装；打开 UCRT64 终端执行 `pacman -Syu`；安装 `mingw-w64-ucrt-x86_64-gcc` 工具链；确认 `gcc`、`make` 可用 | 在 UCRT64 终端执行 `gcc --version`，输出与预期套件一致 |
| 3.2 CMake 构建入门 | 学习编写 `CMakeLists.txt`：`cmake_minimum_required`、`project`、`add_executable`、`target_include_directories`；在 VSCode 中使用 CMake Tools 选择 Kit 后执行 Configure 与 Build；配置断点调试或使用 `tasks.json` + `launch.json` 调用 MSYS2 的 `gcc` | 能编译运行至少一个 `.c` 文件；断点可命中 |
| 3.3 OpenCV（可选） | `git clone` [opencv](https://github.com/opencv/opencv) 与可选 [opencv_contrib](https://github.com/opencv/opencv_contrib)；在源码旁建独立 `build` 目录；在 MSYS2 终端中按 [Windows 从源码安装](https://docs.opencv.org/4.x/d3/d52/tutorial_windows_install.html) 执行 `cmake` 配置（含 `-G "MinGW Makefiles"`、`CMAKE_BUILD_TYPE=Release` 与 `CMAKE_INSTALL_PREFIX`）、`cmake --build`、`cmake --install` | 自建最小 CMake 项目：`find_package(OpenCV REQUIRED)`、`target_link_libraries`，运行读图或 `cv::Mat` 示例成功 |

## 快速参考

```bash
# 更新 MSYS2 软件包数据库并安装工具链
pacman -Syu
pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-make mingw-w64-ucrt-x86_64-cmake

# 使用 CMake 配置并构建项目
cmake -B build -G "MinGW Makefiles"
cmake --build build
```

## 参考链接

- [MSYS2](https://www.msys2.org/)
- [CMake 官网](https://cmake.org/)
- [CMake 教程](https://cmake.org/cmake/help/latest/guide/tutorial/)
- [OpenCV 主仓库](https://github.com/opencv/opencv)
- [OpenCV Windows 从源码安装](https://docs.opencv.org/4.x/d3/d52/tutorial_windows_install.html)