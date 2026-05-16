# 阶段 1：Git 版本控制

## 目标

掌握 Git 基本工作流：本地仓库操作、远程仓库协作、分支管理，并配置 SSH 免密登录。

## 任务

| 子项 | 任务 | 验收 |
|------|------|------|
| 1.1 安装与基础配置 | 下载 [Git](https://git-scm.com/) 并完成安装；配置 `user.name` 与 `user.email` | `git config --global user.name` 和 `user.email` 输出正确 |
| 1.2 本地仓库操作 | 在 GitHub 新建空仓库；本地 `git init` 或 `git clone`；练习 `status` / `add` / `commit` | 本地仓库有至少一条提交记录 |
| 1.3 远程仓库协作 | `remote add` 指向 GitHub；`pull` 与 `push`；SSH 免密登录：`ssh-keygen` 生成密钥，添加到 GitHub，切换 remote 为 SSH 地址 | 远程仓库上能看到提交记录；`git push` 无需重复输入密码 |
| 1.4 分支管理 | 新建分支、切换、合并入门；练习解决一次简单冲突 | 能展示分支合并历史 |
| 1.5 `.gitignore` | 创建 `.gitignore` 文件，排除 `__pycache__/`、`.vscode/`、`build/` 等无关文件 | 仓库中无上述无关文件被跟踪 |
| 1.6 VSCode 集成 | 上述流程在 VSCode 终端或源代码管理面板中各走通一遍 | 在 VSCode 中完成至少一次 `add` → `commit` → `push` |
| 1.7 提交规范 | 学习 Conventional Commits 规范：`feat:`、`fix:`、`docs:`、`refactor:` 等类型；按规范格式编写提交信息 | 提交历史中至少包含一条规范格式的提交 |

## 快速参考

```bash
# 配置用户信息
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# 生成 SSH 密钥，将 ~/.ssh/id_ed25519.pub 内容添加到 GitHub
ssh-keygen -t ed25519 -C "your@email.com"

# 初始化或克隆仓库
git init
git clone <仓库地址>

# 本地提交
git status
git add <文件>
git commit -m "feat: add user login API"
git commit -m "fix: correct null pointer in data processing"
git commit -m "docs: update README installation guide"
git commit -m "refactor: extract image processing module"

# 远程同步
git remote add origin <地址>
git push origin main
git pull origin main

# 分支操作
git branch <分支名>
git checkout <分支名>
git merge <分支名>
```

## 提交规范

提交信息采用 Conventional Commits 规范，格式如下：

```
<类型>: <简短描述>
```

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 bug |
| `docs` | 文档变更 |
| `refactor` | 代码重构，不涉及功能增减 |
| `style` | 代码格式调整，不影响逻辑 |
| `test` | 添加或修改测试 |
| `chore` | 构建过程或辅助工具变动 |

## 参考链接

- [Git 官网](https://git-scm.com/)
- [《Pro Git》中文版](https://git-scm.com/book/zh/v2)
- [GitHub](https://github.com/)