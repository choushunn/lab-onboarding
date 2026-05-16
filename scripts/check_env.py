"""
实验室环境检查脚本

用法：
    python scripts/check_env.py

检查项目：
    - Python 版本与解释器路径
    - Git 安装与配置
    - Conda 环境
    - pip 镜像源
    - GCC (MSYS2)
    - CMake
    - Docker
"""

import shutil
import subprocess
import sys
from pathlib import Path


def check(description, command, show_output=False):
    print(f"  [{('  ' if len(description) < 12 else '')} ] {description}...", end=" ")
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            print("OK")
            if show_output and result.stdout.strip():
                first_line = result.stdout.strip().split("\n")[0]
                print(f"       -> {first_line}")
            return True
        else:
            print("MISSING")
            return False
    except (FileNotFoundError, subprocess.TimeoutExpired):
        print("MISSING")
        return False


def main():
    print("=" * 50)
    print("  实验室环境检查")
    print("=" * 50)
    print()

    all_ok = True

    print("[Python]")
    all_ok &= check("Python 版本", f"{sys.executable} --version", show_output=True)
    all_ok &= check("pip", f"{sys.executable} -m pip --version", show_output=True)

    print()
    print("[Git]")
    all_ok &= check("Git", "git --version", show_output=True)
    all_ok &= check("Git user.name", "git config --global user.name")
    all_ok &= check("Git user.email", "git config --global user.email")

    print()
    print("[Conda]")
    all_ok &= check("Conda", "conda --version", show_output=True)

    print()
    print("[pip 镜像源]")
    all_ok &= check("pip 清华源", "pip config get global.index-url", show_output=True)

    print()
    print("[C/C++]")
    all_ok &= check("gcc", "gcc --version", show_output=True)
    all_ok &= check("cmake", "cmake --version", show_output=True)

    print()
    print("[Docker]")
    all_ok &= check("Docker", "docker --version", show_output=True)

    print()
    print("=" * 50)
    if all_ok:
        print("  所有环境检查通过")
    else:
        print("  部分工具未安装，请参考 基础入门.md 完成安装")
    print("=" * 50)


if __name__ == "__main__":
    main()