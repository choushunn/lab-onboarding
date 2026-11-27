---
name: windows-bootstrap
description: Windows 11 环境搭建、验收、回滚与失败定位。修改 windows11_env 或在新机执行 bootstrap.ps1 时使用。
---

# Windows 环境搭建

## 适用场景

- 新机执行 `windows11_env/bootstrap.ps1`。
- 修改 `windows11_env/` 的阶段、包、配置或数据文件后做回归验证。
- 需要回滚某一次运行产生的配置变更。

## 前置检查

1. 当前账户的用户目录为纯 ASCII。含中文或其他非 ASCII 字符时入口直接退出 2，先切换账户。
2. PowerShell 7.4 及以上。
3. 需要下载 GitHub 资源时先执行 `windows11_env/scripts/proxy-on.ps1`。

## 执行流程

在仓库根的 `windows11_env/` 目录下操作。

1. 输出计划，确认阶段、工作空间与人工项：

   ```powershell
   just bootstrap-dry
   ```

   退出码 0 且系统无变化。

2. 实际搭建：

   ```powershell
   just bootstrap
   ```

   退出码 0 表示搭建与验收全部通过。

3. 只做验收：

   ```powershell
   just verify
   ```

   等价于 `.\bootstrap.ps1 -Profile Dev -Stages Verify`。

4. 只补某个阶段：

   ```powershell
   .\bootstrap.ps1 -Stages Proxy
   ```

   前置阶段按依赖自动补齐。

5. 回滚最近一次配置变更：

   ```powershell
   just rollback
   ```

   只还原配置文件、PATH、环境变量、注册表值与 Defender 排除项，不卸载软件。文件在运行后被修改或删除时保留现状，记为冲突并跳过。

## 退出码

| 退出码 | 含义 |
|---|---|
| 0 | 成功 |
| 1 | 验收失败 |
| 2 | 预检错误，含非 ASCII 用户目录 |
| 3 | 提权被拒 |
| 4 | 阶段执行失败 |

## 产物位置

`windows11_env/logs/runs/<runId>/` 下：

| 文件 | 内容 |
|---|---|
| `bootstrap.log` | 完整日志 |
| `summary.json` | 阶段、包、变更、告警、失败 |
| `manifest.json` | 可回滚变更，文件项含写入前后哈希 |
| `environment-report.json` | 平台信息、实际工具版本、失败与告警 |

## 失败处理

- 预检退出 2：切换纯 ASCII 用户目录后重跑。
- 代理相关包缺失：启动 7890 代理后执行 `.\bootstrap.ps1 -Stages Proxy`。
- Defender 排除项未添加：默认关闭，需要时加 `-EnableDevExclusions`。
- `git safe.directory` 含 `*`：手动执行 `git config --global --unset-all safe.directory`，再重跑 Config 阶段。

## 约束

- 不手工修改注册表或环境变量绕过 manifest；所有可回滚变更必须经 `bootstrap.ps1`。
- 不新增平行安装脚本；安装内容先改 `data/`。
- 修改 PowerShell 后必须执行 `just lint-ps` 与 `just test-ps`。
