# WsBootstrap.psm1 - 新机开发环境与系统优化构建模块

foreach ($file in @('Core.ps1', 'Packages.ps1', 'Config.ps1', 'Stages.ps1')) {
    . (Join-Path $PSScriptRoot $file)
}

Export-ModuleMember -Function *
