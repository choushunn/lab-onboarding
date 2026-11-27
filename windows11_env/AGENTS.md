# AGENTS.md

本文件只维护当前项目的代理规则。全局规则由用户级 AGENTS.md 提供，不在此重复。

## 硬约束

1. **不使用 WSL、Docker、Dev Container。** 主力工具链为 Windows 原生。
2. **不在系统 Python 或 MSYS2 Python 中安装包。** Python 依赖只经 `uv` 进入项目环境。
3. **不修改生成代码区。** CubeMX 生成的代码只改 `/* USER CODE BEGIN */` 与 `/* USER CODE END */` 之间。
4. **用户目录必须为纯 ASCII。** `bootstrap.ps1` 在提权与任何写入前检查 `USERPROFILE` 与 `USERNAME`，含中文或其他非 ASCII 字符时退出 2。

## 环境搭建

- `bootstrap.ps1` 是新机搭建的唯一入口；不新增平行安装脚本。
- `data/` 是包、镜像、路径与人工项的唯一真源；改安装内容先改数据文件。
- 机器级阶段统一 UAC 整体提权；`-NoElevate` 用于只做用户级检查。
- 所有可回滚变更写入 `logs/runs/<runId>/manifest.json`；`-Rollback Last` 只还原配置、PATH、环境变量、注册表值与 Defender 排除项，不卸载软件。
- 仓库与生成配置不得包含个人姓名、个人邮箱、API Key 或供应商令牌。用户值只写入 gitignore 的 `data/user.json`；模板使用占位符。
- 国内镜像由 `data/mirrors.json` 驱动；新增包管理器必须同时提供镜像配置与验收检查。

## 工具链路径

| 用途 | 命令 | 路径 |
|---|---|---|
| Python | `uv run python` | `%USERPROFILE%\.local\bin\uv.exe` |
| C/C++ 编译器 | `gcc` / `g++` | `C:\Programs\msys64\ucrt64\bin` |
| 构建 | `cmake` / `ninja` | 机器级 PATH |
| make | `mingw32-make`（无 `make`） | `C:\Programs\msys64\ucrt64\bin` |
| C/C++ 索引 | `clangd` | `C:\Programs\msys64\ucrt64\bin\clangd.exe` |
| 编译缓存 | `ccache` | `C:\Programs\msys64\ucrt64\bin\ccache.exe` |
| 烧录调试 | `openocd` / `pyocd` | `C:\Programs\msys64\ucrt64\bin\openocd.exe`、`%USERPROFILE%\.local\bin\pyocd.exe` |
| 嵌入式工具链 | `arm-none-eabi-gcc` | ARM GNU Toolchain 的 `bin`，路径见 `data/bootstrap.json` |
| Java | `java` / `mvn` / `gradle` | JDK、Maven 与 Gradle 的 `bin`，路径见 `data/bootstrap.json` |
| 工作空间 | 项目根 | `D:\Workspace\<类别>`；无 D 盘时为 `C:\Workspace\<类别>` |

## 脚本约定

- `.ps1` 与 `.psm1` 一律保存为 UTF-8 **带 BOM**。无 BOM 时 PSScriptAnalyzer 报 `PSUseBOMForUnicodeEncodedFile`。
- `.cmd` 注释只写 ASCII。cmd 按 GBK 解析文件，中文注释会导致命令解析错乱。
- 新增脚本必须同时满足 `just lint-ps` 零 Error 与 `just test-ps` 通过。
- 脚本里的路径参数用绝对路径，不依赖当前工作目录。

## 验证命令

统一入口是 `just`。没有 Justfile 的项目按第二列命令执行。

| 场景 | 命令 | 判定 |
|---|---|---|
| 新机搭建 | `just bootstrap` | 退出码 0 |
| 搭建计划 | `just bootstrap-dry` | 退出码 0，系统无变化 |
| 环境验收 | `just verify` | 退出码 0 |
| 回滚 | `just rollback` | 退出码 0 |
| Python | `just verify-py` 等价 `uv run pytest -q` | 退出码 0 |
| C/C++ | `just verify-cpp` 等价 `cmake --build build && ctest --test-dir build --output-on-failure` | 退出码 0 |
| JS/TS | `just verify-js` 等价 `pnpm test` | 退出码 0 |
| Go | `just verify-go` 等价 `go test ./...` | 退出码 0 |
| Rust | `just verify-rs` 等价 `cargo test` | 退出码 0 |
| C# | `just verify-cs` 等价 `dotnet test` | 退出码 0 |
| 嵌入式编译 | `just verify-fw` 等价 `cmake --build build -j 8` | 退出码 0 |
| 嵌入式烧录 | `openocd -f interface/stlink.cfg -f target/<target>.cfg -c "program build/app.elf verify reset exit"` | verify 通过，须人工确认 |
| PowerShell | `just lint-ps` 与 `just test-ps` | 零 Error、测试全通过 |

代理执行验证后，必须引用具体命令与退出码，不得用"看起来正确"代替。

## 内存与并发

- 并行构建固定 `-j 8`，不按 CPU 线程数跑满。
- 大型 EDA/GUI 工具不在同一时间运行。
- 浏览器标签不超过 15 个；启动大型 EDA/GUI 工具时不超过 5 个。
- VS Code 与 Trae 同一时刻只开一个。
- 代理长会话放在独立终端，用完退出，不做后台常驻。

## 网络

- `github.com:443` 直连被阻断，需要 HTTPS 克隆或下载发布包时先在终端执行 `scripts\proxy-on.ps1`。
- 代理端口从 Windows 系统代理读取，系统代理未启用时回退 `data/bootstrap.json` 的 `proxy.host` 与 `proxy.port`；不在 SSH 或 git 配置中写死端口。
- SSH 22 端口直连可用，`ssh -T git@github.com` 不需要代理。
- `api.github.com` 直连可用，不经过代理。
- 包管理器统一走 `data/mirrors.json` 的国内镜像；PSGallery、VS Code Marketplace 与 winget 无稳定国内镜像，直连。
