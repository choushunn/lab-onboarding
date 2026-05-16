# 阶段 4：Linux 虚拟机与容器

## 目标

通过 VirtualBox 创建 Ubuntu 虚拟机，掌握 Linux 基础操作与 Shell 脚本编写，安装 Docker 体验容器化部署，学习 SSH 隧道与 tmux 会话管理，配置 VSCode 远程开发，以及搭建 AI 编程助手环境。

## 前置依赖

- 阶段 1（Git）
- 阶段 2（编辑器使用）

## 任务

| 子项 | 任务 | 验收 |
|------|------|------|
| 4.1 虚拟机 | 安装 [VirtualBox](https://www.virtualbox.org/)；从 [清华 Ubuntu 22.04 ISO 目录](https://mirror.tuna.tsinghua.edu.cn/ubuntu-releases/22.04/) 下载镜像并新建虚拟机；分配内存与虚拟磁盘；完成系统安装与首次登录；可选安装 Guest Additions | 开机进入 Ubuntu 22.04 桌面或控制台登录成功 |
| 4.2 Linux 基础与 Shell 脚本 | 练习 `cd`/`ls`/`pwd`/`cp`/`mv`/`rm`、`cat`/`less`、`mkdir`/`rmdir`；`grep` 与 `find`；`chmod`/`chown` 基础；在 VM 内安装 `openssh-server`，从本机通过 `ssh 用户名@虚拟机IP` 远程登录；编写一个 Shell 脚本，包含 `#!/bin/bash`、变量、循环、条件判断，添加执行权限并运行；按 [Ubuntu 源帮助](https://mirror.tuna.tsinghua.edu.cn/help/ubuntu/) 将 `apt` 换为清华；`sudo apt update`；用 `apt install` 安装任意一个小工具；查看进程 `ps` 与端口 `ss` 或 `netstat` | `apt update` 无源错误；新装软件可执行；本机可 SSH 登录 VM；Shell 脚本可独立运行 |
| 4.3 Docker | 按 [Docker Engine 安装](https://docs.docker.com/engine/install/ubuntu/) 在 Ubuntu 中安装 Docker；确认 `docker run hello-world`；使用 docker compose 启动 nginx 服务，执行 `docker compose up -d`；查看 `docker compose ps` 与日志 | 浏览器或 `curl` 能访问 compose 中声明的端口；`docker compose down` 可正常回收 |
| 4.4 VSCode 远程开发 | 在 VSCode 中安装 Remote-SSH 扩展；通过 SSH 连接到 Ubuntu 虚拟机；在远程窗口中打开文件夹、编辑文件、运行终端命令，[参考教程](https://www.bilibili.com/video/BV13Z421T7oz/) | VSCode 左下角显示 `SSH: <虚拟机IP>` 连接成功；可在远程终端执行命令 |
| 4.5 远程工作必备 | 安装 tmux，学习新建、分离、重连会话：`tmux new -s`、`Ctrl+B d`、`tmux attach -t`；练习从本机传文件到 VM 和从 VM 下载到本机：`scp file user@host:/path`、`rsync -avz ./local/ user@host:~/remote/` | 能用 tmux 管理持久会话；能用 scp 或 rsync 在宿主机与 VM 间传输文件 |
| 4.6 AI 编程助手 | 在 VM 中安装 Node.js；通过 npm 全局安装 `@anthropic-ai/claude-code`；获取 DeepSeek API Key 并配置环境变量 `ANTHROPIC_API_KEY` 和 `ANTHROPIC_BASE_URL`；在项目目录运行 `claude` 启动交互式编程会话 | `claude --version` 输出版本号；`claude` 可正常启动并响应 DeepSeek 模型 |

## 快速参考

```bash
# Linux 基本操作
cd /path            # 切换目录
ls -la              # 列出文件
cp src dst          # 复制
mv src dst          # 移动或重命名
rm -rf dir          # 删除目录
cat file            # 查看文件
grep pattern file   # 搜索文件内容
find . -name "*.py" # 查找文件

chmod +x file       # 添加执行权限

# 配置 SSH 远程登录
sudo apt install openssh-server
sudo systemctl enable ssh
ip a                # 查看 IP 地址

# tmux 会话管理
tmux new -s work    # 新建会话
# Ctrl+B d          # 分离会话
tmux attach -t work # 重连会话
tmux ls             # 列出会话

# scp 文件传输
scp local.file user@vm-ip:~/remote/path/    # 本机上传到 VM
scp user@vm-ip:~/remote.file ./local/       # 从 VM 下载到本机
rsync -avz ./local/ user@vm-ip:~/remote/    # 增量同步

# Docker 容器管理
sudo apt install docker.io docker-compose-v2
sudo usermod -aG docker $USER
docker run hello-world

# Claude Code AI 编程助手
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs
npm install -g @anthropic-ai/claude-code
export ANTHROPIC_API_KEY=sk-your-deepseek-api-key
export ANTHROPIC_BASE_URL=https://api.deepseek.com/v1
claude
```

## 参考链接

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [清华 Ubuntu 22.04 ISO](https://mirror.tuna.tsinghua.edu.cn/ubuntu-releases/22.04/)
- [清华 Ubuntu 源帮助](https://mirror.tuna.tsinghua.edu.cn/help/ubuntu/)
- [Docker Engine 安装](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/)
- [tmux 入门](https://github.com/tmux/tmux/wiki)
- [rsync 手册](https://rsync.samba.org/)
- [Node.js 下载](https://nodejs.org/)
- [Claude Code 文档](https://docs.anthropic.com/en/docs/claude-code/overview)
- [DeepSeek API 文档](https://platform.deepseek.com/)