# Core.ps1 - 日志、上下文、用户配置、提权、进程调用、注册表、回滚与汇总

function Write-WsLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'STEP', 'WARN', 'ERROR', 'SKIP')][string]$Level = 'INFO',
        [object]$Context
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    $color = switch ($Level) {
        'STEP' { 'Cyan' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        'SKIP' { 'DarkGray' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color

    if ($Context -and $Context.LogPath) {
        $directory = Split-Path -Parent $Context.LogPath
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        Add-Content -LiteralPath $Context.LogPath -Value $line -Encoding utf8
    }
}

function Read-WsJson {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "数据文件不存在：$Path"
    }
    Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
}

function Save-WsJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $json = $Value | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

function New-WsContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [ValidateSet('Dev', 'System', 'All')][string]$Profile = 'All',
        [string[]]$Stages,
        [switch]$DryRun,
        [switch]$NoElevate,
        [switch]$IncludeOptional,
        [switch]$ForceConfig,
        [switch]$ReinstallPackages,
        [string]$WorkspaceRoot,
        [string]$UserFile,
        [switch]$Elevated,
        [string]$RunId
    )

    $resolvedRepo = (Resolve-Path -LiteralPath $RepoRoot).Path
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
    }
    $runDirectory = Join-Path $resolvedRepo ('logs\runs\' + $RunId)
    $dataRoot = Join-Path $resolvedRepo 'data'

    [pscustomobject]@{
        RepoRoot              = $resolvedRepo
        DataRoot              = $dataRoot
        Profile               = $Profile
        SelectedStages        = @($Stages | Where-Object { $_ })
        PlanStages            = @()
        DryRun                = [bool]$DryRun
        NoElevate             = [bool]$NoElevate
        IncludeOptional       = [bool]$IncludeOptional
        ForceConfig           = [bool]$ForceConfig
        ReinstallPackages     = [bool]$ReinstallPackages
        WorkspaceRootOverride = $WorkspaceRoot
        WorkspaceRoot         = $null
        UserFile              = $UserFile
        User                  = $null
        Elevated              = [bool]$Elevated
        RunId                 = $RunId
        RunDirectory          = $runDirectory
        LogPath               = Join-Path $runDirectory 'bootstrap.log'
        SummaryPath           = Join-Path $runDirectory 'summary.json'
        ManifestPath          = Join-Path $runDirectory 'manifest.json'
        BackupDir             = Join-Path $runDirectory 'backup'
        Home                  = $env:USERPROFILE
        UserName              = $env:USERNAME
        AppData               = $env:APPDATA
        NvidiaGpu             = $null
        VerifyFailed          = $false
        Results               = [System.Collections.Generic.List[object]]::new()
        Changes               = [System.Collections.Generic.List[object]]::new()
        StageResults          = [System.Collections.Generic.List[object]]::new()
        Warnings              = [System.Collections.Generic.List[string]]::new()
        Failures              = [System.Collections.Generic.List[string]]::new()
        Bootstrap             = Read-WsJson -Path (Join-Path $dataRoot 'bootstrap.json')
        Mirrors               = Read-WsJson -Path (Join-Path $dataRoot 'mirrors.json')
        DevPackages           = Read-WsJson -Path (Join-Path $dataRoot 'packages.dev.json')
        SystemPackages        = Read-WsJson -Path (Join-Path $dataRoot 'packages.system.json')
        Manual                = Read-WsJson -Path (Join-Path $dataRoot 'manual.json')
    }
}

function Test-WsAsciiText {
    [CmdletBinding()]
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    foreach ($character in $Value.ToCharArray()) {
        if ([int]$character -gt 127) {
            return $false
        }
    }
    return $true
}

function Get-WsIdentityProblems {
    [CmdletBinding()]
    param(
        [string]$UserProfile = $env:USERPROFILE,
        [string]$UserName = $env:USERNAME
    )

    $problems = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($UserProfile)) {
        $problems.Add('USERPROFILE 为空')
    } elseif (-not (Test-WsAsciiText -Value $UserProfile)) {
        $problems.Add("USERPROFILE 含非 ASCII 字符：$UserProfile")
    }
    if ([string]::IsNullOrWhiteSpace($UserName)) {
        $problems.Add('USERNAME 为空')
    } elseif (-not (Test-WsAsciiText -Value $UserName)) {
        $problems.Add("USERNAME 含非 ASCII 字符：$UserName")
    }
    @($problems)
}

function Get-WsPlaceholderMap {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $paths = $Context.Bootstrap.paths
    @{
        '{home}'              = [string]$Context.Home
        '{workspaceRoot}'     = [string]$Context.WorkspaceRoot
        '{programsRoot}'      = [string]$paths.programsRoot
        '{msys2}'             = [string]$paths.msys2
        '{maven}'             = [string]$paths.maven
        '{gradle}'            = [string]$paths.gradle
        '{armGnu}'            = [string]$paths.armGnu
        '{vcpkg}'             = [string]$paths.vcpkg
        '{pnpmStore}'         = [string]$paths.pnpmStore
        '{pnpmStoreFallback}' = [string]$paths.pnpmStoreFallback
        '{repoRoot}'          = [string]$Context.RepoRoot
    }
}

function Get-WsExpandedPath {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Value,
        [Parameter(Mandatory = $true)][object]$Context
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }
    $result = $Value
    $map = Get-WsPlaceholderMap -Context $Context
    foreach ($key in $map.Keys) {
        $replacement = [string]$map[$key]
        if ($replacement) {
            $result = $result.Replace($key, $replacement)
        }
    }
    $result
}

function Get-WsUriHost {
    [CmdletBinding()]
    param([AllowNull()][string]$Uri)

    if ([string]::IsNullOrWhiteSpace($Uri)) {
        return $null
    }
    try {
        return ([Uri]($Uri -replace '^sparse\+', '')).Host
    } catch {
        return $null
    }
}

function Resolve-WsWorkspaceRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [string]$Override,
        [scriptblock]$DriveExists = { param($Drive) Test-Path -LiteralPath $Drive }
    )

    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return $Override
    }
    $preferred = $Context.Bootstrap.workspace.root
    $fallback = $Context.Bootstrap.workspace.fallbackRoot
    $drive = [IO.Path]::GetPathRoot($preferred)
    if ($drive -and (& $DriveExists $drive)) {
        return $preferred
    }
    return $fallback
}

function Resolve-WsPnpmStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [scriptblock]$DriveExists = { param($Drive) Test-Path -LiteralPath $Drive }
    )

    $preferred = Get-WsExpandedPath -Value $Context.Bootstrap.paths.pnpmStore -Context $Context
    $fallback = Get-WsExpandedPath -Value $Context.Bootstrap.paths.pnpmStoreFallback -Context $Context
    $drive = if ($preferred) { [IO.Path]::GetPathRoot($preferred) } else { $null }
    if ($drive -and (& $DriveExists $drive)) {
        return $preferred
    }
    return $fallback
}

function New-WsWorkspace {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if (-not $Context.WorkspaceRoot) {
        throw '工作空间根目录未解析'
    }
    $root = $Context.WorkspaceRoot
    $created = [System.Collections.Generic.List[string]]::new()
    $directories = @($root) + @($Context.Bootstrap.workspace.directories | ForEach-Object { Join-Path $root $_ })
    foreach ($directory in $directories) {
        if (Test-Path -LiteralPath $directory) {
            continue
        }
        if ($Context.DryRun) {
            Write-WsLog "DryRun：将创建目录 $directory" -Context $Context
            continue
        }
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $created.Add($directory)
        Write-WsLog "创建目录 $directory" -Context $Context
    }
    @($created)
}

function Test-WsNvidiaGpu {
    [CmdletBinding()]
    param()

    if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
        return $true
    }
    try {
        $controllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
        foreach ($controller in $controllers) {
            if ($controller.Name -match 'NVIDIA') {
                return $true
            }
        }
    } catch {
        return $false
    }
    return $false
}

function Get-WsGpuAvailability {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if ($null -eq $Context.NvidiaGpu) {
        $Context.NvidiaGpu = Test-WsNvidiaGpu
    }
    [bool]$Context.NvidiaGpu
}

function Test-WsAdmin {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WsPortListening {
    [CmdletBinding()]
    param(
        [string]$HostName = '127.0.0.1',
        [int]$Port = 7890
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        if (-not $task.Wait(500)) {
            return $false
        }
        return $client.Connected
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Invoke-WsProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    $output = & $FilePath @Arguments 2>&1
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = @($output)
    }
}

function Update-WsProcessPath {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if ($Context.DryRun) {
        return
    }
    $extras = @(
        (Join-Path $Context.Home '.local\bin'),
        (Join-Path $Context.Bootstrap.paths.msys2 'ucrt64\bin'),
        (Join-Path $Context.Bootstrap.paths.maven 'bin'),
        (Join-Path $Context.Bootstrap.paths.gradle 'bin'),
        (Join-Path $Context.Bootstrap.paths.armGnu 'bin'),
        (Join-Path $Context.AppData 'npm'),
        (Join-Path $Context.Home '.cargo\bin'),
        (Join-Path $Context.Home 'go\bin')
    ) | Where-Object { Test-Path -LiteralPath $_ }
    $machine = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $parts = @($extras) + @($machine -split ';') + @($user -split ';') | Where-Object { $_ }
    $env:PATH = $parts -join ';'
}

function Resolve-WsToolPath {    [CmdletBinding()]
    param(
        [object]$Context,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }
    if (-not $Context) {
        return $null
    }
    $paths = $Context.Bootstrap.paths
    $candidates = switch ($Name) {
        'mvn' { @((Join-Path $paths.maven 'bin\mvn.cmd'), (Join-Path $paths.maven 'bin\mvn'), (Join-Path $paths.maven 'bin\mvn.bat')) }
        'gradle' { @((Join-Path $paths.gradle 'bin\gradle.bat'), (Join-Path $paths.gradle 'bin\gradle'), (Join-Path $paths.gradle 'bin\gradle.cmd')) }
        'arm-none-eabi-gcc' { @((Join-Path $paths.armGnu 'bin\arm-none-eabi-gcc.exe')) }
        'openocd' { @((Join-Path $paths.msys2 'ucrt64\bin\openocd.exe')) }
        'gcc' { @((Join-Path $paths.msys2 'ucrt64\bin\gcc.exe')) }
        'g++' { @((Join-Path $paths.msys2 'ucrt64\bin\g++.exe')) }
        'clangd' { @((Join-Path $paths.msys2 'ucrt64\bin\clangd.exe')) }
        'ccache' { @((Join-Path $paths.msys2 'ucrt64\bin\ccache.exe')) }
        'mingw32-make' { @((Join-Path $paths.msys2 'ucrt64\bin\mingw32-make.exe')) }
        'uv' { @((Join-Path $Context.Home '.local\bin\uv.exe')) }
        default { @() }
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }
    return $null
}

function Test-WsCommandPresence {
    [CmdletBinding()]
    param(
        [object]$Context,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $null -ne (Resolve-WsToolPath -Context $Context -Name $Name)
}

function Get-WsUserConfigPath {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if ($Context.UserFile) {
        return $Context.UserFile
    }
    Join-Path $Context.DataRoot 'user.json'
}

function Test-WsUserConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$User)

    $problems = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($User.gitName)) {
        $problems.Add('gitName 不能为空')
    }
    if ([string]::IsNullOrWhiteSpace($User.gitEmail)) {
        $problems.Add('gitEmail 不能为空')
    } elseif ($User.gitEmail -notmatch '^[^@\s]+@[^@\s]+$') {
        $problems.Add('gitEmail 格式无效')
    }
    if ($User.writeAiConfig) {
        if ([string]::IsNullOrWhiteSpace($User.aiProvider)) {
            $problems.Add('writeAiConfig 为 true 时 aiProvider 不能为空')
        }
        if ([string]::IsNullOrWhiteSpace($User.aiModel)) {
            $problems.Add('writeAiConfig 为 true 时 aiModel 不能为空')
        }
    }
    $port = 0
    if (-not [int]::TryParse([string]$User.ccsRoutePort, [ref]$port)) {
        $problems.Add('ccsRoutePort 必须是整数')
    } elseif ($port -lt 1 -or $port -gt 65535) {
        $problems.Add('ccsRoutePort 必须在 1 到 65535 之间')
    }
    @($problems)
}

function Read-WsUserConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [switch]$SkipPrompt
    )

    $path = Get-WsUserConfigPath -Context $Context
    if (Test-Path -LiteralPath $path) {
        $user = Read-WsJson -Path $path
        $problems = @(Test-WsUserConfig -User $user)
        if ($problems.Count -gt 0) {
            throw ('用户配置无效：' + ($problems -join '；'))
        }
        return $user
    }
    if ($SkipPrompt) {
        throw "缺少用户配置：$path"
    }

    Write-WsLog '未找到用户配置，开始交互询问' -Level STEP -Context $Context
    Write-WsLog 'Git 身份与 AI 配置只保存在 gitignore 的 data/user.json 中' -Context $Context
    $gitName = Read-Host -Prompt 'Git 姓名'
    $gitEmail = Read-Host -Prompt 'Git 邮箱'
    $writeAiText = Read-Host -Prompt '写入 Claude/Trae 配置？(Y/n)'
    $writeAiConfig = $writeAiText -notmatch '^(n|N|no|NO)$'
    $aiProvider = ''
    $aiModel = ''
    if ($writeAiConfig) {
        $aiProvider = Read-Host -Prompt 'AI 供应商名称'
        $aiModel = Read-Host -Prompt '模型标识'
    }
    $defaultPort = [int]$Context.Bootstrap.ccs.routePort
    $portText = Read-Host -Prompt "CC Switch 路由端口（默认 $defaultPort）"
    $port = $defaultPort
    if (-not [string]::IsNullOrWhiteSpace($portText)) {
        $port = [int]$portText
    }

    $user = [pscustomobject]@{
        gitName       = $gitName
        gitEmail      = $gitEmail
        writeAiConfig = $writeAiConfig
        aiProvider    = $aiProvider
        aiModel       = $aiModel
        ccsRoutePort  = $port
    }
    $problems = @(Test-WsUserConfig -User $user)
    if ($problems.Count -gt 0) {
        throw ('用户配置无效：' + ($problems -join '；'))
    }
    if ($Context.DryRun) {
        Write-WsLog "DryRun：用户配置将写入 $path" -Context $Context
    } else {
        Save-WsJson -Path $path -Value $user
        Write-WsLog "用户配置写入 $path" -Context $Context
    }
    $user
}

function Add-WsChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][hashtable]$Entry
    )

    if ($Context.DryRun) {
        return
    }
    $Context.Changes.Add([pscustomobject]$Entry)
    Save-WsManifest -Context $Context
}

function Save-WsManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if ($Context.DryRun) {
        return
    }
    $manifest = [pscustomobject]@{
        runId     = $Context.RunId
        createdAt = (Get-Date).ToString('o')
        entries   = @($Context.Changes)
    }
    Save-WsJson -Path $Context.ManifestPath -Value $manifest
}

function Save-WsSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $summary = [pscustomobject]@{
        runId         = $Context.RunId
        profile       = $Context.Profile
        dryRun        = $Context.DryRun
        noElevate     = $Context.NoElevate
        workspaceRoot = $Context.WorkspaceRoot
        stages        = @($Context.StageResults)
        packages      = @($Context.Results)
        changes       = @($Context.Changes)
        warnings      = @($Context.Warnings)
        failures      = @($Context.Failures)
        manual        = @($Context.Manual.items)
        finishedAt    = (Get-Date).ToString('o')
    }
    Save-WsJson -Path $Context.SummaryPath -Value $summary
}

function Invoke-WsElevation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$BootstrapPath,
        [hashtable]$ExtraParameters = @{}
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $BootstrapPath, '-Elevated', '-RunId', $Context.RunId, '-Profile', $Context.Profile)) {
        $arguments.Add($item)
    }
    foreach ($key in $ExtraParameters.Keys) {
        $value = $ExtraParameters[$key]
        if ($value -is [bool]) {
            if ($value) {
                $arguments.Add("-$key")
            }
            continue
        }
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            continue
        }
        $arguments.Add("-$key")
        if ($value -is [array]) {
            $arguments.Add(($value -join ','))
        } else {
            $arguments.Add([string]$value)
        }
    }

    try {
        $quoted = @($arguments | ForEach-Object { if ([string]$_ -match '\s') { '"' + [string]$_ + '"' } else { [string]$_ } })
        $process = Start-Process -FilePath 'pwsh.exe' -Verb RunAs -ArgumentList ($quoted -join ' ') -Wait -PassThru
        [pscustomobject]@{ Started = $true; ExitCode = $process.ExitCode; Message = '' }
    } catch {
        [pscustomobject]@{ Started = $false; ExitCode = 3; Message = $_.Exception.Message }
    }
}

function Get-WsRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('HKLM', 'HKCU')][string]$Hive,
        [Parameter(Mandatory = $true)][string]$SubKey,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $base = if ($Hive -eq 'HKLM') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
    $key = $base.OpenSubKey($SubKey, $false)
    if (-not $key) {
        return $null
    }
    try {
        if ($key.GetValueNames() -notcontains $Name) {
            return $null
        }
        [pscustomobject]@{
            Value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            Kind  = $key.GetValueKind($Name)
        }
    } finally {
        $key.Dispose()
    }
}

function Set-WsRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][ValidateSet('HKLM', 'HKCU')][string]$Hive,
        [Parameter(Mandatory = $true)][string]$SubKey,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][object]$Value,
        [ValidateSet('DWord', 'String', 'ExpandString')][string]$ValueKind = 'DWord'
    )

    $existing = Get-WsRegistryValue -Hive $Hive -SubKey $SubKey -Name $Name
    if ($existing -and [string]$existing.Value -eq [string]$Value) {
        Write-WsLog "注册表已一致：$Hive\$SubKey\$Name" -Level SKIP -Context $Context
        return 'Unchanged'
    }
    if ($Context.DryRun) {
        Write-WsLog "DryRun：将设置 $Hive\$SubKey\$Name=$Value" -Context $Context
        return 'Planned'
    }
    Add-WsChange -Context $Context -Entry @{
        Kind          = 'Registry'
        Hive          = $Hive
        SubKey        = $SubKey
        Name          = $Name
        Existed       = ($null -ne $existing)
        PreviousValue = if ($existing) { $existing.Value } else { $null }
        PreviousKind  = if ($existing) { $existing.Kind.ToString() } else { $null }
        Action        = 'Set'
    }
    $base = if ($Hive -eq 'HKLM') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
    $key = $base.CreateSubKey($SubKey)
    try {
        $key.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::$ValueKind)
    } finally {
        $key.Dispose()
    }
    Write-WsLog "设置注册表 $Hive\$SubKey\$Name=$Value" -Context $Context
    'Updated'
}

function Set-WsEnvironmentVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][string]$Value,
        [Parameter(Mandatory = $true)][ValidateSet('Machine', 'User')][string]$Scope
    )

    $current = [Environment]::GetEnvironmentVariable($Name, $Scope)
    if ($current -eq $Value) {
        Write-WsLog "环境变量已一致：$Name ($Scope)" -Level SKIP -Context $Context
        return 'Unchanged'
    }
    if ($Context.DryRun) {
        Write-WsLog "DryRun：将设置 $Name=$Value ($Scope)" -Context $Context
        return 'Planned'
    }
    Add-WsChange -Context $Context -Entry @{
        Kind          = 'Environment'
        Scope         = $Scope
        Name          = $Name
        Existed       = ($null -ne $current)
        PreviousValue = $current
        Action        = if ($null -eq $Value) { 'Remove' } else { 'Set' }
    }
    [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
    Write-WsLog "设置环境变量 $Name=$Value ($Scope)" -Context $Context
    'Updated'
}

function Remove-WsEnvironmentVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('Machine', 'User')][string]$Scope
    )

    Set-WsEnvironmentVariable -Context $Context -Name $Name -Value $null -Scope $Scope
}

function Get-WsRollbackManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Rollback
    )

    $runsRoot = Join-Path $RepoRoot 'logs\runs'
    if (-not (Test-Path -LiteralPath $runsRoot)) {
        return $null
    }
    if ($Rollback -eq 'Last') {
        $run = Get-ChildItem -LiteralPath $runsRoot -Directory |
            Sort-Object Name -Descending |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'manifest.json') } |
            Select-Object -First 1
    } else {
        $candidate = Join-Path $runsRoot $Rollback
        $run = if (Test-Path -LiteralPath (Join-Path $candidate 'manifest.json')) { Get-Item -LiteralPath $candidate } else { $null }
    }
    if (-not $run) {
        return $null
    }
    Read-WsJson -Path (Join-Path $run.FullName 'manifest.json')
}

function Test-WsManifestRequiresAdmin {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Manifest)

    foreach ($entry in @($Manifest.entries)) {
        if ($entry.Kind -in @('Registry', 'DefenderExclusion')) {
            return $true
        }
        if ($entry.Kind -eq 'Environment' -and $entry.Scope -eq 'Machine') {
            return $true
        }
        if ($entry.Kind -eq 'Path' -and $entry.Scope -eq 'Machine') {
            return $true
        }
    }
    return $false
}

function Restore-WsFileChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Entry
    )

    if ($Entry.Existed) {
        if ($Entry.BackupPath -and (Test-Path -LiteralPath $Entry.BackupPath)) {
            $directory = Split-Path -Parent $Entry.Path
            if ($directory -and -not (Test-Path -LiteralPath $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
            Copy-Item -LiteralPath $Entry.BackupPath -Destination $Entry.Path -Force
            Write-WsLog "还原文件 $($Entry.Path)" -Context $Context
        } else {
            Write-WsLog "缺少备份，跳过 $($Entry.Path)" -Level WARN -Context $Context
        }
    } elseif (Test-Path -LiteralPath $Entry.Path) {
        Remove-Item -LiteralPath $Entry.Path -Force
        Write-WsLog "删除新建文件 $($Entry.Path)" -Context $Context
    }
}

function Restore-WsRegistryChange {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Entry)

    $base = if ($Entry.Hive -eq 'HKLM') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
    $key = $base.OpenSubKey($Entry.SubKey, $true)
    if (-not $key) {
        if (-not $Entry.Existed) {
            return
        }
        $key = $base.CreateSubKey($Entry.SubKey)
    }
    try {
        if ($Entry.Existed) {
            $kind = [Microsoft.Win32.RegistryValueKind]$Entry.PreviousKind
            $key.SetValue($Entry.Name, $Entry.PreviousValue, $kind)
        } else {
            $key.DeleteValue($Entry.Name, $false)
        }
    } finally {
        $key.Dispose()
    }
}

function Restore-WsPathChange {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Entry)

    $base = if ($Entry.Scope -eq 'Machine') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
    $subKey = if ($Entry.Scope -eq 'Machine') { 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment' } else { 'Environment' }
    $key = $base.OpenSubKey($subKey, $true)
    if (-not $key) {
        $key = $base.CreateSubKey($subKey)
    }
    try {
        $key.SetValue('Path', [string]$Entry.PreviousValue, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    } finally {
        $key.Dispose()
    }
}

function Restore-WsEnvironmentChange {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Entry)

    $value = if ($Entry.Existed) { [string]$Entry.PreviousValue } else { $null }
    [Environment]::SetEnvironmentVariable($Entry.Name, $value, $Entry.Scope)
    [Environment]::SetEnvironmentVariable($Entry.Name, $value, 'Process')
}

function Invoke-WsRollback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [object[]]$Manifest = @()
    )

    $entries = @($Manifest)
    if ($entries.Count -eq 0) {
        Write-WsLog '没有需要回滚的变更' -Context $Context
        return
    }
    for ($index = $entries.Count - 1; $index -ge 0; $index--) {
        $entry = $entries[$index]
        switch ($entry.Kind) {
            'File' { Restore-WsFileChange -Context $Context -Entry $entry }
            'Registry' { Restore-WsRegistryChange -Entry $entry }
            'Path' { Restore-WsPathChange -Entry $entry }
            'Environment' { Restore-WsEnvironmentChange -Entry $entry }
            'DefenderExclusion' {
                try {
                    Remove-MpPreference -ExclusionPath $entry.Value -ErrorAction Stop
                    Write-WsLog "移除 Defender 排除项 $($entry.Value)" -Context $Context
                } catch {
                    Write-WsLog "移除 Defender 排除项失败：$($entry.Value)" -Level WARN -Context $Context
                }
            }
        }
    }
    Write-WsLog "回滚完成，共处理 $($entries.Count) 项；已安装软件不卸载" -Context $Context
}
