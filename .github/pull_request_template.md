## 变更说明

说明改了什么，以及为什么改。

## 影响范围

- [ ] `windows11_env/`
- [ ] `ubuntu_env/`
- [ ] `phases/` 或 `resources/`
- [ ] `skills/`
- [ ] `.github/`
- [ ] 根 README、AGENTS.md 或其他根文件

## 验证

| 命令 | 退出码 |
|---|---|
|  |  |

涉及 `windows11_env/` 时至少执行 `just lint-ps` 与 `just test-ps`；涉及文档时说明与 `data/` 的一致性检查方式。

## 回滚

说明本次改动如何回退；涉及环境配置时写明使用的 `-Rollback` 目标。

## 检查清单

- [ ] 提交信息符合 Conventional Commits
- [ ] 新增或修改的文档与数据文件一致，无防御性写作
- [ ] 未包含个人姓名、个人邮箱、API Key 或供应商令牌
- [ ] PowerShell 改动通过 `just lint-ps` 与 `just test-ps`
- [ ] 新增下载源提供哈希校验，解压限制在目标目录内
