# 开发环境只读体检。默认不改系统设置；-RepairProcessEnvironment 只修复当前进程。
param(
    [switch]$RepairProcessEnvironment
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repo 'src\WsBootstrap\WsBootstrap.psm1') -Force

$context = New-WsContext -RepoRoot $repo -DryRun
$result = Test-WsEnvironment -Context $context -RepairProcessEnvironment:$RepairProcessEnvironment

if ($result.Warnings.Count -gt 0) {
    Write-Warning '需要处理的环境提示：'
    $result.Warnings | ForEach-Object { Write-Warning $_ }
}
if ($result.Failures.Count -gt 0) {
    Write-Error ('环境体检失败：' + ($result.Failures -join '；'))
    exit 1
}

Write-Host '环境体检通过。EDA GUI 与实物板环节仍须人工确认。'
