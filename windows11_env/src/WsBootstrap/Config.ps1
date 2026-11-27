# Config.ps1 - 模板渲染、配置写入、镜像、PATH、环境变量与系统设置

function ConvertTo-WsJsonString {
    [CmdletBinding()]
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }
    ($Value -replace '\\', '\\') -replace '"', '\"'
}

function Get-WsTemplateValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [hashtable]$Extra = @{}
    )

    $mirrors = $Context.Mirrors
    $user = $Context.User
    $values = @{
        'HOME'                 = [string]$Context.Home
        'REPO_ROOT'            = [string]$Context.RepoRoot
        'REPO_ROOT_JSON'       = ConvertTo-WsJsonString -Value $Context.RepoRoot
        'GIT_NAME'             = if ($user) { [string]$user.gitName } else { '' }
        'GIT_EMAIL'            = if ($user) { [string]$user.gitEmail } else { '' }
        'AI_PROVIDER'          = if ($user) { ConvertTo-WsJsonString -Value $user.aiProvider } else { '' }
        'AI_MODEL'             = if ($user) { ConvertTo-WsJsonString -Value $user.aiModel } else { '' }
        'CCS_ROUTE_PORT'       = if ($user) { [string]$user.ccsRoutePort } else { [string]$Context.Bootstrap.ccs.routePort }
        'PROXY_HOST'           = [string]$Context.Bootstrap.proxy.host
        'PROXY_PORT'           = [string]$Context.Bootstrap.proxy.port
        'WORKSPACE_ROOT'       = [string]$Context.WorkspaceRoot
        'PNPM_STORE'           = Get-WsExpandedPath -Value $Context.Bootstrap.paths.pnpmStore -Context $Context
        'PIP_INDEX_URL'        = [string]$mirrors.pip.indexUrl
        'PIP_EXTRA_INDEX_URL'  = [string]$mirrors.pip.extraIndexUrl
        'PIP_TRUSTED_HOSTS'    = (@($mirrors.pip.trustedHosts) -join "`n    ")
        'PIP_TIMEOUT'          = [string]$mirrors.pip.timeout
        'UV_INDEX_URL'         = [string]$mirrors.uv.indexUrl
        'NPM_REGISTRY'         = [string]$mirrors.npm.registry
        'CARGO_SOURCE'         = [string]$mirrors.cargo.sourceName
        'CARGO_REGISTRY'       = [string]$mirrors.cargo.registry
        'MAVEN_MIRROR_ID'      = [string]$mirrors.maven.mirrorId
        'MAVEN_MIRROR_URL'     = [string]$mirrors.maven.mirrorUrl
        'MAVEN_MIRROR_OF'      = [string]$mirrors.maven.mirrorOf
        'GRADLE_REPO_1'        = [string]@($mirrors.gradle.repositories)[0]
        'GRADLE_REPO_2'        = [string]@($mirrors.gradle.repositories)[1]
        'GRADLE_REPO_3'        = [string]@($mirrors.gradle.repositories)[2]
        'NUGET_OFFICIAL'       = [string]$mirrors.nuget.official
        'NUGET_HUAWEI'         = [string]$mirrors.nuget.huawei
    }
    foreach ($key in $Extra.Keys) {
        $values[$key] = $Extra[$key]
    }
    $values
}

function Expand-WsTemplateText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][hashtable]$Values
    )

    $result = $Text
    foreach ($key in $Values.Keys) {
        $result = $result.Replace('{{' + $key + '}}', [string]$Values[$key])
    }
    $remaining = [regex]::Matches($result, '\{\{([A-Z0-9_]+)\}\}')
    if ($remaining.Count -gt 0) {
        $names = @($remaining | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        throw ('模板存在未知占位符：' + ($names -join ', '))
    }
    $result
}

function Get-WsNormalizedText {
    [CmdletBinding()]
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) {
        return ''
    }
    ($Text -replace "`r`n", "`n").TrimEnd()
}

function Copy-WsFileBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Context.BackupDir)) {
        New-Item -ItemType Directory -Path $Context.BackupDir -Force | Out-Null
    }
    $safeName = ($Path -replace '[\\/:*?"<>|]', '_')
    $backupPath = Join-Path $Context.BackupDir ('{0}.{1}.bak' -f $safeName, (Get-Date -Format 'HHmmssfff'))
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    $backupPath
}

function Write-WsManagedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content,
        [switch]$Force
    )

    $forceWrite = $Force -or $Context.ForceConfig
    $exists = Test-Path -LiteralPath $Path
    if ($exists) {
        $current = Get-Content -LiteralPath $Path -Raw
        if ((Get-WsNormalizedText -Text $current) -eq (Get-WsNormalizedText -Text $Content)) {
            Write-WsLog "配置已一致：$Path" -Level SKIP -Context $Context
            return 'Unchanged'
        }
        if ($Context.DryRun) {
            Write-WsLog "DryRun：将备份并覆盖 $Path" -Context $Context
            return 'Planned'
        }
        $backup = Copy-WsFileBackup -Context $Context -Path $Path
        if (-not $forceWrite) {
            Write-WsLog "配置存在且不同，已备份到 $backup；使用 -ForceConfig 覆盖：$Path" -Level WARN -Context $Context
            return 'BackupSkipped'
        }
        Add-WsChange -Context $Context -Entry @{
            Kind       = 'File'
            Path       = $Path
            Existed    = $true
            BackupPath = $backup
            BeforeHash = Get-WsFileHash -Path $Path
            AfterHash  = Get-WsTextHash -Text $Content
            Action     = 'Overwrite'
        }
    } else {
        if ($Context.DryRun) {
            Write-WsLog "DryRun：将创建 $Path" -Context $Context
            return 'Planned'
        }
        Add-WsChange -Context $Context -Entry @{
            Kind       = 'File'
            Path       = $Path
            Existed    = $false
            BackupPath = ''
            BeforeHash = ''
            AfterHash  = Get-WsTextHash -Text $Content
            Action     = 'Create'
        }
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
    Write-WsLog "写入配置：$Path" -Context $Context
    'Written'
}

function Get-WsTemplateText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$Name
    )

    Get-Content -LiteralPath (Join-Path $Context.DataRoot ('templates\' + $Name)) -Raw
}

function Set-WsPacmanMirrors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-WsLog "pacman.conf 不存在，跳过：$Path" -Level WARN -Context $Context
        return 'Missing'
    }
    $servers = @($Context.Mirrors.msys2.servers)
    $hosts = @($servers | ForEach-Object { Get-WsUriHost -Uri $_ } | Where-Object { $_ } | Sort-Object -Unique)
    $repositoryPattern = $null
    if ($hosts.Count -gt 0) {
        $managed = ($hosts | ForEach-Object { [regex]::Escape($_) }) -join '|'
        $repositoryPattern = '^\s*Server\s*=\s*https://(?:' + $managed + ')/msys2/'
    }
    $sectionPattern = '^\[(?<repo>clangarm64|clang64|mingw32|mingw64|ucrt64|msys)\]$'
    $repoPaths = @{
        clangarm64 = 'mingw/clangarm64'
        mingw32    = 'mingw/mingw32'
        mingw64    = 'mingw/mingw64'
        ucrt64     = 'mingw/ucrt64'
        clang64    = 'mingw/clang64'
        msys       = 'msys/x86_64'
    }
    $output = [System.Collections.Generic.List[string]]::new()
    foreach ($line in @(Get-Content -LiteralPath $Path)) {
        if ($repositoryPattern -and $line -match $repositoryPattern) {
            continue
        }
        if ($line -match '^\s*Include\s*=\s*/etc/pacman\.d/mirrorlist') {
            continue
        }
        $output.Add($line)
        if ($line -match $sectionPattern) {
            $repository = $Matches['repo']
            $relative = $repoPaths[$repository]
            if (-not $relative) {
                continue
            }
            foreach ($server in $servers) {
                $output.Add('Server = ' + $server.TrimEnd('/') + '/' + $relative + '/')
            }
        }
    }
    $content = ($output -join "`n") + "`n"
    Write-WsManagedFile -Context $Context -Path $Path -Content $content -Force
}

function Set-WsGoMirrors {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if (-not (Get-Command 'go' -ErrorAction SilentlyContinue)) {
        Write-WsLog '未找到 go，跳过 Go 镜像配置' -Level WARN -Context $Context
        return 'Missing'
    }
    $proxyValue = [string]$Context.Mirrors.go.proxy
    $sumValue = [string]$Context.Mirrors.go.sumdb
    if ($Context.DryRun) {
        Write-WsLog "DryRun：将设置 GOPROXY=$proxyValue GOSUMDB=$sumValue" -Context $Context
        return 'Planned'
    }
    $result = Invoke-WsProcess -FilePath 'go' -Arguments @('env', '-w', ('GOPROXY=' + $proxyValue), ('GOSUMDB=' + $sumValue))
    if ($result.ExitCode -ne 0) {
        throw 'go env -w 失败'
    }
    Write-WsLog '设置 Go 镜像 goproxy.cn' -Context $Context
    'Updated'
}

function Set-WsMirrors {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $values = Get-WsTemplateValues -Context $Context
    $targets = @(
        @{ Template = 'pip.ini'; Target = (Join-Path $Context.Home 'pip\pip.ini') },
        @{ Template = 'uv.toml'; Target = (Join-Path $Context.AppData 'uv\uv.toml') },
        @{ Template = 'npmrc'; Target = (Join-Path $Context.Home '.npmrc') },
        @{ Template = 'cargo-config.toml'; Target = (Join-Path $Context.Home '.cargo\config.toml') },
        @{ Template = 'maven-settings.xml'; Target = (Join-Path $Context.Home '.m2\settings.xml') },
        @{ Template = 'gradle-init.gradle'; Target = (Join-Path $Context.Home '.gradle\init.gradle') },
        @{ Template = 'nuget.config'; Target = (Join-Path $Context.AppData 'NuGet\NuGet.Config') }
    )
    $statuses = [System.Collections.Generic.List[object]]::new()
    foreach ($target in $targets) {
        $template = Get-WsTemplateText -Context $Context -Name $target.Template
        $content = Expand-WsTemplateText -Text $template -Values $values
        $status = Write-WsManagedFile -Context $Context -Path $target.Target -Content $content -Force
        $statuses.Add([pscustomobject]@{ Name = $target.Template; Status = $status })
    }
    $pacman = Join-Path $Context.Bootstrap.paths.msys2 'etc\pacman.conf'
    $statuses.Add([pscustomobject]@{ Name = 'pacman.conf'; Status = (Set-WsPacmanMirrors -Context $Context -Path $pacman) })
    $statuses.Add([pscustomobject]@{ Name = 'go env'; Status = (Set-WsGoMirrors -Context $Context) })
    $statuses.Add([pscustomobject]@{
            Name   = 'RUSTUP_DIST_SERVER'
            Status = Set-WsEnvironmentVariable -Context $Context -Name 'RUSTUP_DIST_SERVER' -Value $Context.Mirrors.rustup.distServer -Scope 'User'
        })
    $statuses.Add([pscustomobject]@{
            Name   = 'RUSTUP_UPDATE_ROOT'
            Status = Set-WsEnvironmentVariable -Context $Context -Name 'RUSTUP_UPDATE_ROOT' -Value $Context.Mirrors.rustup.updateRoot -Scope 'User'
        })
    $statuses.Add([pscustomobject]@{
            Name   = 'COREPACK_NPM_REGISTRY'
            Status = Set-WsEnvironmentVariable -Context $Context -Name 'COREPACK_NPM_REGISTRY' -Value $Context.Mirrors.corepack.registry -Scope 'User'
        })
    foreach ($status in $statuses) {
        Write-WsLog ("镜像配置 {0} -> {1}" -f $status.Name, $status.Status) -Context $Context
    }
    @($statuses)
}

function Get-WsPlannedPath {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Current,
        [string[]]$Head = @(),
        [string[]]$Tail = @()
    )

    $items = @($Current -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $managed = @($Head) + @($Tail)
    $unmanaged = @($items | Where-Object { $managed -notcontains $_ })
    (@($Head) + $unmanaged + @($Tail)) -join ';'
}

function Set-WsPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][ValidateSet('Machine', 'User')][string]$Scope,
        [string[]]$Head = @(),
        [string[]]$Tail = @()
    )

    $hive = if ($Scope -eq 'Machine') { 'HKLM' } else { 'HKCU' }
    $subKey = if ($Scope -eq 'Machine') { 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment' } else { 'Environment' }
    $current = Get-WsRegistryValue -Hive $hive -SubKey $subKey -Name 'Path'
    $previous = if ($current) { [string]$current.Value } else { '' }
    $headExpanded = @($Head | ForEach-Object { Get-WsExpandedPath -Value $_ -Context $Context })
    $tailExpanded = @($Tail | ForEach-Object { Get-WsExpandedPath -Value $_ -Context $Context })
    $planned = Get-WsPlannedPath -Current $previous -Head $headExpanded -Tail $tailExpanded

    if ($planned -eq $previous) {
        Write-WsLog "PATH 已一致：$Scope" -Level SKIP -Context $Context
        return 'Unchanged'
    }
    if ($Context.DryRun) {
        Write-WsLog "DryRun：将重排 $Scope PATH" -Context $Context
        return 'Planned'
    }
    Add-WsChange -Context $Context -Entry @{
        Kind          = 'Path'
        Scope         = $Scope
        PreviousValue = $previous
        Action        = 'Set'
    }
    $base = if ($hive -eq 'HKLM') { [Microsoft.Win32.Registry]::LocalMachine } else { [Microsoft.Win32.Registry]::CurrentUser }
    $key = $base.CreateSubKey($subKey)
    try {
        $key.SetValue('Path', $planned, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    } finally {
        $key.Dispose()
    }
    Write-WsLog "重排 $Scope PATH" -Context $Context
    'Updated'
}

function Clear-WsSslVariables {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $statuses = [System.Collections.Generic.List[object]]::new()
    foreach ($name in @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE')) {
        $userValue = [Environment]::GetEnvironmentVariable($name, 'User')
        if ($null -ne $userValue) {
            $statuses.Add([pscustomobject]@{
                    Name   = $name
                    Status = Set-WsEnvironmentVariable -Context $Context -Name $name -Value $null -Scope 'User'
                })
        }
        if (-not $Context.DryRun) {
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
    }
    @($statuses)
}

function Send-WsEnvironmentChange {
    [CmdletBinding()]
    param()

    try {
        if (-not ([System.Management.Automation.PSTypeName]'WsBootstrap.NativeMethods').Type) {
            Add-Type -Namespace 'WsBootstrap' -Name 'NativeMethods' -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
        }
        $result = [UIntPtr]::Zero
        [void][WsBootstrap.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
    } catch {
        Write-Warning "广播环境变量变更失败：$($_.Exception.Message)"
    }
}

function Set-WsDefenderExclusions {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $statuses = [System.Collections.Generic.List[object]]::new()
    $existing = @()
    if (-not $Context.DryRun) {
        try {
            $preference = Get-MpPreference -ErrorAction Stop
            $existing = @($preference.ExclusionPath | Where-Object { $_ })
        } catch {
            Write-WsLog "读取 Defender 排除项失败，跳过排除项：$($_.Exception.Message)；防篡改开启时需手动添加" -Level WARN -Context $Context
            return @()
        }
    }
    foreach ($raw in @($Context.Bootstrap.system.defenderExclusions)) {
        $path = Get-WsExpandedPath -Value $raw -Context $Context
        if (-not $path) {
            continue
        }
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }
        if ($existing -contains $path) {
            continue
        }
        if ($Context.DryRun) {
            Write-WsLog "DryRun：将添加 Defender 排除项 $path" -Context $Context
            $statuses.Add([pscustomobject]@{ Name = $path; Status = 'Planned' })
            continue
        }
        try {
            Add-MpPreference -ExclusionPath $path -ErrorAction Stop
            Add-WsChange -Context $Context -Entry @{ Kind = 'DefenderExclusion'; Value = $path; Action = 'Add' }
            $statuses.Add([pscustomobject]@{ Name = $path; Status = 'Added' })
        } catch {
            Write-WsLog "添加 Defender 排除项失败，已跳过：$path；防篡改开启时需手动添加" -Level WARN -Context $Context
            $statuses.Add([pscustomobject]@{ Name = $path; Status = 'Skipped' })
        }
    }
    @($statuses)
}

function Set-WsSystemSettings {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $statuses = [System.Collections.Generic.List[object]]::new()
    if ($Context.Bootstrap.system.longPaths) {
        $statuses.Add([pscustomobject]@{
                Name   = 'LongPathsEnabled'
                Status = Set-WsRegistryValue -Context $Context -Hive 'HKLM' -SubKey 'SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -ValueKind DWord
            })
    }
    if ($Context.Bootstrap.system.developerMode) {
        $statuses.Add([pscustomobject]@{
                Name   = 'AllowDevelopmentWithoutDevLicense'
                Status = Set-WsRegistryValue -Context $Context -Hive 'HKLM' -SubKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -ValueKind DWord
            })
    }
    if ($Context.EnableDevExclusions) {
        foreach ($status in @(Set-WsDefenderExclusions -Context $Context)) {
            $statuses.Add($status)
        }
    } else {
        Write-WsLog 'Defender 排除项未启用：使用 -EnableDevExclusions 启用' -Level SKIP -Context $Context
    }
    foreach ($status in $statuses) {
        Write-WsLog ("系统设置 {0} -> {1}" -f $status.Name, $status.Status) -Context $Context
    }
    @($statuses)
}

function Get-WsRuleLines {
    [CmdletBinding()]
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    @($Text -split "`n" |
        ForEach-Object { ($_ -replace '\s', '').TrimEnd('。') } |
        Where-Object { $_ -match '^\d+\.' } |
        ForEach-Object { $_.ToLowerInvariant() })
}

function Set-WsGlobalAgents {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $targets = @($Context.Bootstrap.paths.globalAgents | Where-Object { $_ })
    if ($targets.Count -eq 0) {
        throw 'data/bootstrap.json 未定义 paths.globalAgents'
    }
    $template = Get-WsTemplateText -Context $Context -Name 'global-agents.md'
    $content = Expand-WsTemplateText -Text $template -Values (Get-WsTemplateValues -Context $Context)
    $ruleLines = @(Get-WsRuleLines -Text $content)
    $statuses = [System.Collections.Generic.List[object]]::new()

    foreach ($raw in $targets) {
        $target = Get-WsExpandedPath -Value $raw -Context $Context
        if (-not $target) {
            continue
        }
        $duplicate = $false
        $directory = Split-Path -Parent $target
        if ($directory -and (Test-Path -LiteralPath $directory)) {
            foreach ($file in @(Get-ChildItem -LiteralPath $directory -File -Filter '*.md' -ErrorAction SilentlyContinue)) {
                if ($file.FullName -eq $target) {
                    continue
                }
                $existing = @(Get-WsRuleLines -Text (Get-Content -LiteralPath $file.FullName -Raw))
                if ($ruleLines.Count -gt 0 -and (($existing -join "`n") -eq ($ruleLines -join "`n"))) {
                    $duplicate = $true
                    break
                }
            }
        }
        $status = if ($duplicate) {
            Write-WsLog "全局规则已存在，跳过：$target" -Level SKIP -Context $Context
            'AlreadyPresent'
        } else {
            Write-WsManagedFile -Context $Context -Path $target -Content $content
        }
        $statuses.Add([pscustomobject]@{ Path = $target; Status = $status })
        Write-WsLog "全局规则 $target -> $status" -Context $Context
    }
    @($statuses)
}

function Set-WsTerminalAppearance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [string]$Path
    )

    if (-not $Path) {
        $Path = Get-WsExpandedPath -Value $Context.Bootstrap.paths.terminalSettings -Context $Context
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-WsLog "未找到 Windows Terminal 设置，跳过外观：$Path" -Level SKIP -Context $Context
        return
    }
    $appearance = $Context.Bootstrap.terminal
    $settings = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    if (-not $settings.ContainsKey('profiles') -or $settings.profiles -isnot [hashtable]) {
        $settings['profiles'] = @{}
    }
    if (-not $settings.profiles.ContainsKey('defaults') -or $settings.profiles.defaults -isnot [hashtable]) {
        $settings.profiles['defaults'] = @{}
    }
    $defaults = $settings.profiles.defaults
    $font = if ($defaults.ContainsKey('font') -and $defaults.font -is [hashtable]) { $defaults.font } else { @{} }
    $font['size'] = [int]$appearance.fontSize
    $defaults['font'] = $font
    $defaults['colorScheme'] = [string]$appearance.colorScheme
    $defaults['opacity'] = [int]$appearance.opacity
    $defaults['useAcrylic'] = [bool]$appearance.useAcrylic
    $defaults['intenseTextStyle'] = [string]$appearance.intenseTextStyle
    $settings['theme'] = [string]$appearance.theme
    $settings['useAcrylicInTabRow'] = [bool]$appearance.useAcrylicInTabRow
    $content = $settings | ConvertTo-Json -Depth 20
    $status = Write-WsManagedFile -Context $Context -Path $Path -Content $content -Force
    Write-WsLog "Windows Terminal 外观 -> $status" -Context $Context
}

function Set-WsGitConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if (-not $Context.User) {
        throw '用户配置未加载'
    }
    if ($Context.DryRun) {
        Write-WsLog "DryRun：将写入 Git 身份 $($Context.User.gitName) <$($Context.User.gitEmail)> 与 init.defaultBranch" -Context $Context
        return
    }
    $commands = @(
        @('config', '--global', 'user.name', $Context.User.gitName),
        @('config', '--global', 'user.email', $Context.User.gitEmail),
        @('config', '--global', 'init.defaultBranch', 'main')
    )
    foreach ($arguments in $commands) {
        $result = Invoke-WsProcess -FilePath 'git' -Arguments $arguments
        if ($result.ExitCode -ne 0) {
            throw "git $($arguments -join ' ') 失败"
        }
    }
    $safe = Invoke-WsProcess -FilePath 'git' -Arguments @('config', '--global', '--get-all', 'safe.directory')
    $safeDirectories = @($safe.Output | Where-Object { $_ })
    if ($safeDirectories -contains '*') {
        Write-WsLog "git safe.directory 含 '*'，范围过宽；移除：git config --global --unset-all safe.directory" -Level WARN -Context $Context
    }
    $workspaceRoot = $Context.WorkspaceRoot
    if (-not $workspaceRoot) {
        $workspaceRoot = Resolve-WsWorkspaceRoot -Context $Context -Override $Context.WorkspaceRootOverride
    }
    if ($workspaceRoot -and $safeDirectories -notcontains $workspaceRoot) {
        $result = Invoke-WsProcess -FilePath 'git' -Arguments @('config', '--global', '--add', 'safe.directory', $workspaceRoot)
        if ($result.ExitCode -ne 0) {
            throw 'git safe.directory 写入失败'
        }
    }
    Write-WsLog '写入 Git 全局配置' -Context $Context
}

function Set-WsAiConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $values = Get-WsTemplateValues -Context $Context
    $claudeTemplate = Get-WsTemplateText -Context $Context -Name 'claude-settings.json'
    $claudeContent = Expand-WsTemplateText -Text $claudeTemplate -Values $values
    $claudePath = Join-Path $Context.Home '.claude\settings.json'
    $claudeStatus = Write-WsManagedFile -Context $Context -Path $claudePath -Content $claudeContent

    $traeTemplate = Get-WsTemplateText -Context $Context -Name 'trae-mcp.json'
    $traeContent = Expand-WsTemplateText -Text $traeTemplate -Values $values
    $traePath = Join-Path $Context.AppData 'Trae CN\User\mcp.json'
    $traeStatus = Write-WsManagedFile -Context $Context -Path $traePath -Content $traeContent

    Write-WsLog "Claude 配置 -> $claudeStatus；Trae MCP -> $traeStatus" -Context $Context
}

