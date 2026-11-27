# sync-skills.ps1 - 通过 Skills CLI 同步通用目录中的 Agent Skills

[CmdletBinding()]
param(
    [ValidateSet('base', 'image', 'embedded')][string[]]$Direction = @('base'),
    [switch]$DryRun,
    [switch]$Update,
    [switch]$Remove,
    [switch]$Force,
    [string]$DataFile,
    [string]$SkillsRoot
)

$ErrorActionPreference = 'Stop'
$script:SkillsRepoRoot = Split-Path -Parent $PSScriptRoot

function Write-SkillLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SKIP', 'STEP')][string]$Level = 'INFO'
    )

    $color = switch ($Level) {
        'STEP' { 'Cyan' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        'SKIP' { 'DarkGray' }
        default { 'Gray' }
    }
    Write-Host ('[{0}] {1}' -f $Level, $Message) -ForegroundColor $color
}

function Get-SkillDataProblems {
    param(
        [Parameter(Mandatory = $true)][object]$Data,
        [Parameter(Mandatory = $true)][string[]]$KnownDirections
    )

    $problems = [System.Collections.Generic.List[string]]::new()
    if ($Data.schemaVersion -ne 1) {
        $problems.Add('skills.json schemaVersion 必须为 1')
    }
    $names = @{}
    foreach ($skill in @($Data.skills)) {
        $package = [string]$skill.package
        $name = [string]$skill.name
        if ($package -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$') {
            $problems.Add("package 格式应为 owner/repo@skill：$package")
        }
        if ($name -notmatch '^[A-Za-z0-9._-]+$') {
            $problems.Add("name 含非法字符：$name")
        }
        if ($package -match '@([^@]+)$' -and $Matches[1] -ne $name) {
            $problems.Add("package 后缀与 name 不一致：$package / $name")
        }
        if ($names.ContainsKey($name)) {
            $problems.Add("name 重复：$name")
        } else {
            $names[$name] = $true
        }
        foreach ($direction in @($skill.directions)) {
            if ($direction -and $KnownDirections -notcontains $direction) {
                $problems.Add("未知 direction：$direction（$name）")
            }
        }
    }
    @($problems)
}

function Get-SelectedSkills {
    param(
        [Parameter(Mandatory = $true)][object]$Data,
        [Parameter(Mandatory = $true)][string[]]$Direction
    )

    $selected = @('base') + @($Direction | Where-Object { $_ -and $_ -ne 'base' })
    @($Data.skills | Where-Object {
            $directions = if ($_.PSObject.Properties.Name -contains 'directions' -and $_.directions) { @($_.directions) } else { @('base') }
            @($directions | Where-Object { $selected -contains $_ }).Count -gt 0
        })
}

function Get-SkillTargetPath {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.agents\skills'
    }
    Join-Path $Root $Name
}

function Test-SkillInstalled {
    param([Parameter(Mandatory = $true)][string]$Path)

    Test-Path -LiteralPath (Join-Path $Path 'SKILL.md')
}

function Invoke-SkillCli {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $npx = Get-Command 'npx' -ErrorAction SilentlyContinue
    if (-not $npx) {
        throw '未找到 npx，请先安装 Node.js'
    }
    $output = & $npx.Source --yes skills @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ('skills {0} 失败（退出码 {1}）：{2}' -f ($Arguments -join ' '), $LASTEXITCODE, (($output | ForEach-Object { [string]$_ }) -join "`n"))
    }
    @($output | ForEach-Object { [string]$_ })
}

function Invoke-SkillsSync {
    param(
        [string[]]$Direction = @('base'),
        [switch]$DryRun,
        [switch]$Update,
        [switch]$Remove,
        [switch]$Force,
        [string]$DataFile,
        [string]$SkillsRoot
    )

    $dataPath = if ($DataFile) { $DataFile } else { Join-Path $script:SkillsRepoRoot 'data\skills.json' }
    $directionPath = Join-Path $script:SkillsRepoRoot 'data\directions.json'
    if (-not (Test-Path -LiteralPath $dataPath)) {
        Write-SkillLog "数据文件不存在：$dataPath" -Level ERROR
        return 1
    }
    $data = Get-Content -LiteralPath $dataPath -Raw -Encoding utf8 | ConvertFrom-Json
    $knownDirections = @((Get-Content -LiteralPath $directionPath -Raw -Encoding utf8 | ConvertFrom-Json).directions | ForEach-Object { $_.id })
    $problems = @(Get-SkillDataProblems -Data $data -KnownDirections $knownDirections)
    if ($problems.Count -gt 0) {
        foreach ($problem in $problems) {
            Write-SkillLog $problem -Level ERROR
        }
        return 1
    }

    $skills = @(Get-SelectedSkills -Data $data -Direction $Direction)
    if (-not $SkillsRoot) {
        $SkillsRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.agents\skills'
    }
    Write-SkillLog ("方向：{0}；候选 {1} 项；目录 {2}" -f ($Direction -join ', '), $skills.Count, $SkillsRoot) -Level STEP

    if ($Update) {
        if ($DryRun) {
            Write-SkillLog 'DryRun：将更新全局 Skills' -Level SKIP
            return 0
        }
        [void](Invoke-SkillCli -Arguments @('update', '-g', '-y'))
        Write-SkillLog '全局 Skills 已更新'
        return 0
    }

    if (-not $DryRun -and -not $env:HTTPS_PROXY -and -not $env:HTTP_PROXY) {
        Write-SkillLog '未检测到 HTTP(S)_PROXY；GitHub 拉取失败时先执行 scripts/proxy-on.ps1' -Level WARN
    }

    $failed = 0
    foreach ($skill in $skills) {
        $path = Get-SkillTargetPath -Name $skill.name -Root $SkillsRoot
        if ($Remove) {
            if (-not (Test-Path -LiteralPath $path)) {
                Write-SkillLog ("未安装：{0}" -f $skill.name) -Level SKIP
                continue
            }
            if ($DryRun) {
                Write-SkillLog ("DryRun：将移除 {0}" -f $skill.name) -Level SKIP
                continue
            }
            [void](Invoke-SkillCli -Arguments @('remove', $skill.name, '-g', '-y'))
            Write-SkillLog ("已移除：{0}" -f $skill.name)
            continue
        }

        if ((Test-SkillInstalled -Path $path) -and -not $Force) {
            Write-SkillLog ("已安装：{0}" -f $skill.name) -Level SKIP
            continue
        }
        if ($DryRun) {
            Write-SkillLog ("DryRun：将安装 {0}（{1}）" -f $skill.name, $skill.package) -Level SKIP
            continue
        }
        try {
            $parts = $skill.package -split '@', 2
            [void](Invoke-SkillCli -Arguments @('add', $parts[0], '-g', '-y', '-s', $parts[1]))
            if (-not (Test-SkillInstalled -Path $path)) {
                throw "安装后未找到 SKILL.md：$path"
            }
            Write-SkillLog ("已安装：{0}" -f $skill.name)
        } catch {
            $failed++
            Write-SkillLog ("安装失败 {0}：{1}" -f $skill.name, $_.Exception.Message) -Level ERROR
        }
    }
    if ($failed -gt 0) {
        return 1
    }
    0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-SkillsSync -Direction $Direction -DryRun:$DryRun -Update:$Update -Remove:$Remove -Force:$Force -DataFile $DataFile -SkillsRoot $SkillsRoot)
}
