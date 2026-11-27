---
name: repo-delivery
description: 提交前门禁、CI 校验与交付检查。准备提交、推送或创建 PR 时使用。
---

# 交付检查

## 适用场景

- 准备提交或推送本仓库改动。
- 创建或更新 PR。
- 需要确认改动是否满足仓库规范。

## 提交前

1. 查看改动范围：

   ```powershell
   git status --short
   git diff
   ```

2. 改动涉及 `windows11_env/` 时，在该目录执行：

   ```powershell
   just lint-ps
   just test-ps
   ```

   两项均以退出码 0 结束。

3. 扫描暂存区密钥：

   ```powershell
   gitleaks protect --staged --no-banner
   ```

   退出码 0 表示无发现。

4. 检查提交信息符合 Conventional Commits：

   ```text
   <type>(<scope>): <subject>
   ```

   type 取 `feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`build`、`ci`、`chore`、`revert`。

## 文档一致性

- 修改 `data/` 后同步更新对应 docs 与 README。
- 修改命令、参数或阶段后同步更新 `windows11_env/README.md`、`windows11_env/docs/`、根 `AGENTS.md`。
- 文档不写个人身份、机器特定数值或历史迁移过程。

## PR

1. 使用 `.github/pull_request_template.md` 填写变更说明、验证命令与退出码、回滚方式。
2. CI 必须通过：
   - `CI`：PowerShell 静态检查与单元测试。
   - `Commit Messages`：全部提交符合 Conventional Commits。
3. 验证结果引用具体命令与退出码，不用主观描述代替。

## 判定

| 检查 | 通过条件 |
|---|---|
| `git diff` | 改动范围与提交说明一致 |
| `just lint-ps` | 零 Error |
| `just test-ps` | 全部通过 |
| `gitleaks protect --staged` | 无发现 |
| 提交信息 | 符合 Conventional Commits |
| CI | 全部工作流通过 |
