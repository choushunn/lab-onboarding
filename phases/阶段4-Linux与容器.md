# 阶段 4：Linux 虚拟机与容器

## 目标

通过 VirtualBox 创建 Ubuntu 虚拟机，掌握 Linux 基础操作，安装 Docker 并体验容器化部署，配置 VSCode 远程开发，以及搭建 AI 编程助手环境。

## 任务

| 子项 | 任务 | 验收 |
|------|------|------|
| 4.1 虚拟机 | 安装 [VirtualBox](https://www.virtualbox.org/)；从 [清华 Ubuntu 22.04 ISO 目录](https://mirror.tuna.tsinghua.edu.cn/ubuntu-releases/22.04/) 下载镜像并新建虚拟机；分配内存与虚拟磁盘；完成系统安装与首次登录；可选安装 Guest Additions | 开机进入 Ubuntu 22.04 桌面或控制台登录成功 |
| 4.2 Linux 基础 | 练习 `cd`/`ls`/`pwd`/`cp`/`mv`/`rm`、`cat`/`less`、`mkdir`/`rmdir`；`grep` 与 `find`；`chmod`/`chown` 基础；在 VM 内安装 `openssh-server`，从本机通过 `ssh 用户名@虚拟机IP` 远程登录；按 [Ubuntu 源帮助](https://mirror.tuna.tsinghua.edu.cn/help/ubuntu/) 将 `apt` 换为清华；`sudo apt update`；用 `apt install` 安装任意一个小工具；查看进程 `ps` 与端口 `ss` 或 `netstat` | `apt update` 无源错误；新装软件可执行；本机可 SSH 登录 VM |
| 4.3 Docker | 按 [Docker Engine 安装](https://docs.docker.com/engine/install/ubuntu/) 在 Ubuntu 中安装 Docker；确认 `docker run hello-world`；使用 docker compose 启动 nginx 服务，执行 `docker compose up -d`；查看 `docker compose ps` 与日志 | 浏览器或 `curl` 能访问 compose 中声明的端口；`docker compose down` 可正常回收 |
| 4.4 VSCode 远程开发 | 在 VSCode 中安装 Remote-SSH 扩展；通过 SSH 连接到 4.1 创建的 Ubuntu 虚拟机；在远程窗口中打开文件夹、编辑文件、运行终端命令；体验「本地编辑、远程执行」的工作流，[参考教程](https://www.bilibili.com/video/BV13Z421T7oz/) | VSCode 左下角显示 `SSH: <虚拟机IP>` 连接成功；可在远程终端执行命令 |
| 4.5 AI 编程助手（Claude Code + DeepSeek） | 在 VM 中安装 Node.js（建议 v18+）；通过 npm 全局安装 `@anthropic-ai/claude-code`；获取 DeepSeek API Key 并配置环境变量 `ANTHROPIC_API_KEY` 指向 DeepSeek 兼容接口；在项目目录运行 `claude` 启动交互式编程会话 | `claude --version` 输出版本号；`claude` 可正常启动并响应 DeepSeek 模型 |

## 快速参考

```bash
# Linux 基础命令
cd /path          # 切换目录
ls -la            # 列出文件
cp src dst        # 复制
mv src dst        # 移动/重命名
rm -rf dir        # 删除
cat file          # 查看文件
grep pattern file # 搜索
find . -name "*.py"  # 查找文件
chmod +x file     # 添加执行权限

# SSH 配置
sudo apt install openssh-server
sudo systemctl enable ssh
ip a              # 查看 IP

# Docker
sudo apt install docker.io docker-compose-v2
sudo usermod -aG docker $USER
docker run hello-world

# Claude Code + DeepSeek
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
- [Node.js 下载](https://nodejs.org/)
- [Claude Code 文档](https://docs.anthropic.com/en/docs/claude-code/overview)
- [DeepSeek API 文档](https://platform.deepseek.com/)