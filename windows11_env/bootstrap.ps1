# 新机开发环境与系统优化的唯一入口

[CmdletBinding()]
param(
    [ValidateSet('Dev', 'System', 'All')][string]$Profile = 'All',
    [string[]]$Stages,
    [Alias('EnvProfile')][ValidateSet('base', 'image', 'embedded')][string[]]$Direction = @('base'),
    [switch]$DryRun,
    [switch]$NoElevate,
    [switch]$IncludeOptional,
    [string]$WorkspaceRoot,
    [switch]$ForceConfig,
    [switch]$ReinstallPackages,
    [switch]$EnableDevExclusions,
    [switch]$SkipSkills,
    [string]$UserFile,
    [string]$Rollback,
    [switch]$Elevated,
    [string]$RunId
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
Import-Module (Join-Path $repoRoot 'src\WsBootstrap\WsBootstrap.psm1') -Force

$identityProblems = @(Get-WsIdentityProblems)
if ($identityProblems.Count -gt 0) {
    Write-Host '无法开始：用户目录必须为纯 ASCII。' -ForegroundColor Red
    foreach ($problem in $identityProblems) {
        Write-Host "  $problem" -ForegroundColor Red
    }
    Write-Host '请切换到英文用户名账户后重新运行。' -ForegroundColor Red
    exit 2
}

if ($UserFile) {
    $UserFile = [IO.Path]::GetFullPath($UserFile)
}
if ($Stages) {
    $Stages = @($Stages | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ })
}
if ($Direction) {
    $Direction = @($Direction | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ })
}
if ($WorkspaceRoot) {
    $WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
}

$context = New-WsContext -RepoRoot $repoRoot -Profile $Profile -Direction $Direction -Stages $Stages -DryRun:$DryRun -NoElevate:$NoElevate `
    -IncludeOptional:$IncludeOptional -ForceConfig:$ForceConfig -ReinstallPackages:$ReinstallPackages `
    -EnableDevExclusions:$EnableDevExclusions -SkipSkills:$SkipSkills -WorkspaceRoot $WorkspaceRoot -UserFile $UserFile -Elevated:$Elevated -RunId $RunId

if ($Rollback) {
    $manifest = Get-WsRollbackManifest -RepoRoot $repoRoot -Rollback $Rollback
    if (-not $manifest) {
        Write-Host '没有可回滚的 manifest。' -ForegroundColor Yellow
        exit 0
    }
    if ((Test-WsManifestRequiresAdmin -Manifest $manifest) -and -not (Test-WsAdmin) -and -not $NoElevate -and -not $Elevated) {
        $elevation = Invoke-WsElevation -Context $context -BootstrapPath $PSCommandPath -ExtraParameters @{ Rollback = $Rollback }
        if (-not $elevation.Started) {
            Write-Host "提权被拒绝：$($elevation.Message)" -ForegroundColor Red
            exit 3
        }
        exit $elevation.ExitCode
    }
    Invoke-WsRollback -Context $context -Manifest @($manifest.entries)
    Save-WsSummary -Context $context
    exit 0
}

$plan = @(Get-WsStagePlan -Profile $Profile -Stages $Stages)
$context.PlanStages = @($plan | ForEach-Object { $_.Name })

Write-Host ''
Write-Host '新机开发环境与系统优化' -ForegroundColor Cyan
Write-Host ("RunId   : {0}" -f $context.RunId)
Write-Host ("Profile : {0}" -f $Profile)
Write-Host ("方向    : {0}" -f ($context.Direction -join ', '))
Write-Host ("模式    : {0}" -f $(if ($DryRun) { 'DryRun（只输出计划）' } else { '实际执行' }))
Write-Host '阶段计划：'
$plan | Format-Table @{ Label = '阶段'; Expression = { $_.Name } }, @{ Label = '需管理员'; Expression = { $_.RequiresAdmin } }, @{ Label = '前置'; Expression = { ($_.Prerequisites -join ', ') } } -AutoSize | Out-Host

$devCount = @($context.DevPackages.packages | Where-Object { Test-WsDirectionMatch -Context $context -Item $_ }).Count
$systemCount = @($context.SystemPackages.packages).Count
$manualCount = @(Get-WsManualItems -Context $context).Count
Write-Host ("包数量  : 开发 {0}，系统 {1}；人工项 {2}" -f $devCount, $systemCount, $manualCount)

if ($DryRun) {
    $context.WorkspaceRoot = Resolve-WsWorkspaceRoot -Context $context -Override $WorkspaceRoot
    Write-Host ("工作空间: {0}" -f $context.WorkspaceRoot)
    Write-Host '人工项：'
    $context.Manual.items | Where-Object { Test-WsDirectionMatch -Context $context -Item $_ } | Format-Table @{ Label = '项目'; Expression = { $_.name } }, @{ Label = '来源'; Expression = { $_.source } }, @{ Label = '说明'; Expression = { $_.reason } } -AutoSize | Out-Host
}

$requiresAdmin = @($plan | Where-Object { $_.RequiresAdmin }).Count -gt 0
$skipAdmin = $false
if ($requiresAdmin -and -not (Test-WsAdmin) -and -not $DryRun) {
    if ($NoElevate) {
        $skipAdmin = $true
        Write-Host '当前不是管理员，-NoElevate 已指定：机器级阶段将跳过。' -ForegroundColor Yellow
    } elseif (-not $Elevated) {
        Write-Host '请求管理员权限并整体重启入口。' -ForegroundColor Yellow
        $extra = @{
            NoElevate           = [bool]$NoElevate
            IncludeOptional     = [bool]$IncludeOptional
            ForceConfig         = [bool]$ForceConfig
            ReinstallPackages   = [bool]$ReinstallPackages
            EnableDevExclusions = [bool]$EnableDevExclusions
            SkipSkills          = [bool]$SkipSkills
            WorkspaceRoot       = $WorkspaceRoot
            UserFile            = $UserFile
            Stages              = $Stages
        }
        $elevation = Invoke-WsElevation -Context $context -BootstrapPath $PSCommandPath -ExtraParameters $extra
        if (-not $elevation.Started) {
            Write-Host "提权被拒绝：$($elevation.Message)" -ForegroundColor Red
            exit 3
        }
        exit $elevation.ExitCode
    }
}

$exitCode = 0
foreach ($stage in $plan) {
    $status = 'Succeeded'
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    Write-WsLog ("=== 阶段 {0} ===" -f $stage.Name) -Level STEP -Context $context
    try {
        if ($stage.RequiresAdmin -and $skipAdmin) {
            $status = 'SkippedNoAdmin'
            Write-WsLog ("跳过机器级阶段 {0}（-NoElevate）" -f $stage.Name) -Level SKIP -Context $context
        } else {
            Invoke-WsStage -Context $context -Name $stage.Name
        }
    } catch {
        $status = 'Failed'
        $context.Failures.Add($_.Exception.Message)
        Write-WsLog ("阶段 {0} 失败：{1}" -f $stage.Name, $_.Exception.Message) -Level ERROR -Context $context
        if ($stage.Name -eq 'Preflight') {
            $exitCode = 2
        } else {
            $exitCode = 4
        }
    } finally {
        $stopwatch.Stop()
        $context.StageResults.Add([pscustomobject]@{
                Name    = $stage.Name
                Status  = $status
                Seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
            })
    }
    if ($status -eq 'Failed') {
        break
    }
}

if ($exitCode -eq 0 -and $context.VerifyFailed) {
    $exitCode = 1
}

Save-WsSummary -Context $context
Save-WsManifest -Context $context

Write-Host ''
Write-Host '阶段结果：' -ForegroundColor Cyan
$context.StageResults | Format-Table @{ Label = '阶段'; Expression = { $_.Name } }, @{ Label = '状态'; Expression = { $_.Status } }, @{ Label = '秒'; Expression = { $_.Seconds } } -AutoSize | Out-Host

if ($context.Results.Count -gt 0) {
    Write-Host '安装结果：' -ForegroundColor Cyan
    $context.Results | Group-Object Status | Sort-Object Name | Format-Table @{ Label = '状态'; Expression = { $_.Name } }, @{ Label = '数量'; Expression = { $_.Count } } -AutoSize | Out-Host
}

Write-Host '人工项（须人工确认）：' -ForegroundColor Cyan
$context.Manual.items | Where-Object { Test-WsDirectionMatch -Context $context -Item $_ } | Format-Table @{ Label = '项目'; Expression = { $_.name } }, @{ Label = '来源'; Expression = { $_.source } }, @{ Label = '说明'; Expression = { $_.reason } } -AutoSize | Out-Host

Write-Host ("日志与清单：{0}" -f $context.RunDirectory)
Write-Host ("退出码：{0}" -f $exitCode)
exit $exitCode
