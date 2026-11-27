# Stages.ps1 - 阶段图、阶段实现、验收与环境体检

$script:WsStageOrder = @('Preflight', 'Base', 'Mirrors', 'Toolchain', 'Environment', 'System', 'Proxy', 'Optional', 'Config', 'Verify')

$script:WsStageDefinitions = @{
    Preflight   = @{ Profiles = @('Dev', 'System', 'All'); RequiresAdmin = $false; Prerequisites = @() }
    Base        = @{ Profiles = @('Dev', 'All'); RequiresAdmin = $true; Prerequisites = @('Preflight') }
    Mirrors     = @{ Profiles = @('Dev', 'All'); RequiresAdmin = $true; Prerequisites = @('Base') }
    Toolchain   = @{ Profiles = @('Dev', 'All'); RequiresAdmin = $false; Prerequisites = @('Mirrors') }
    Environment = @{ Profiles = @('Dev', 'All'); RequiresAdmin = $true; Prerequisites = @('Toolchain') }
    System      = @{ Profiles = @('System', 'All'); RequiresAdmin = $true; Prerequisites = @('Preflight') }
    Proxy       = @{ Profiles = @('Dev', 'All'); RequiresAdmin = $false; Prerequisites = @('Toolchain') }
    Optional    = @{ Profiles = @('Dev', 'All'); RequiresAdmin = $true; Prerequisites = @('Toolchain') }
    Config      = @{ Profiles = @('Dev', 'All'); RequiresAdmin = $false; Prerequisites = @('Proxy') }
    Verify      = @{ Profiles = @('Dev', 'System', 'All'); RequiresAdmin = $false; Prerequisites = @() }
}

function Get-WsStagePlan {
    [CmdletBinding()]
    param(
        [ValidateSet('Dev', 'System', 'All')][string]$Profile = 'All',
        [string[]]$Stages
    )

    $allowed = @($script:WsStageOrder | Where-Object { $script:WsStageDefinitions[$_].Profiles -contains $Profile })
    $selected = if ($Stages -and @($Stages).Count -gt 0) { @($Stages) } else { @($allowed) }
    foreach ($name in $selected) {
        if (-not $script:WsStageDefinitions.ContainsKey($name)) {
            throw "未知阶段：$name"
        }
    }

    $closure = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($name in $selected) {
        $queue.Enqueue($name)
    }
    while ($queue.Count -gt 0) {
        $name = $queue.Dequeue()
        if (-not $closure.Add($name)) {
            continue
        }
        foreach ($prerequisite in @($script:WsStageDefinitions[$name].Prerequisites)) {
            $queue.Enqueue($prerequisite)
        }
    }

    $plan = foreach ($name in $script:WsStageOrder) {
        if ($closure.Contains($name)) {
            [pscustomobject]@{
                Name          = $name
                RequiresAdmin = [bool]$script:WsStageDefinitions[$name].RequiresAdmin
                Prerequisites = @($script:WsStageDefinitions[$name].Prerequisites)
            }
        }
    }
    @($plan)
}

function Test-WsData {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $problems = [System.Collections.Generic.List[string]]::new()
    $providers = @('winget', 'exeInstaller', 'localInstaller', 'fileDownload', 'zipDownload', 'wheelExtract', 'gitClone', 'uvPython', 'uvTool', 'npm', 'pacman', 'psModule', 'vscodeExtension')
    $stages = @('base', 'toolchain', 'optional', 'system', 'proxy')
    $conditions = @('nvidiaGpu')
    $providerFields = @{
        winget          = @('packageId')
        exeInstaller    = @('urls', 'args', 'target')
        localInstaller  = @('file', 'args', 'registryName')
        fileDownload    = @('urls', 'target')
        zipDownload     = @('urls', 'target')
        wheelExtract    = @('indexUrl', 'wheelPattern', 'files', 'target')
        gitClone        = @('repo', 'target')
        uvPython        = @('version')
        uvTool          = @('packageId')
        npm             = @('packageId')
        pacman          = @('packageId')
        psModule        = @('packageId')
        vscodeExtension = @('packageId')
    }
    $ids = @{}

    foreach ($package in @(@($Context.DevPackages.packages) + @($Context.SystemPackages.packages))) {
        foreach ($field in @('id', 'name', 'provider', 'stage', 'required')) {
            if (-not ($package.PSObject.Properties.Name -contains $field)) {
                $problems.Add("包缺少字段 $field：$($package | ConvertTo-Json -Compress)")
            }
        }
        if ($providers -notcontains $package.provider) {
            $problems.Add("未知 provider：$($package.provider)（$($package.id)）")
        }
        if ($stages -notcontains $package.stage) {
            $problems.Add("未知 stage：$($package.stage)（$($package.id)）")
        }
        if ($package.PSObject.Properties.Name -contains 'condition' -and $package.condition -and $conditions -notcontains $package.condition) {
            $problems.Add("未知 condition：$($package.condition)（$($package.id)）")
        }
        if ($providerFields.ContainsKey($package.provider)) {
            foreach ($field in $providerFields[$package.provider]) {
                if (-not ($package.PSObject.Properties.Name -contains $field)) {
                    $problems.Add("provider $($package.provider) 缺少字段 $field：$($package.id)")
                }
            }
        }
        if ([string]::IsNullOrWhiteSpace([string]$package.id)) {
            continue
        }
        if ($ids.ContainsKey($package.id)) {
            $problems.Add("包 ID 重复：$($package.id)")
        } else {
            $ids[$package.id] = $true
        }
    }

    foreach ($item in @($Context.Manual.items)) {
        if ([string]::IsNullOrWhiteSpace([string]$item.name)) {
            $problems.Add('manual.json 存在缺少 name 的条目')
        }
    }
    if ($Context.Mirrors.schemaVersion -ne 1) {
        $problems.Add('mirrors.json schemaVersion 必须为 1')
    }
    if (@($Context.Mirrors.gradle.repositories).Count -lt 3) {
        $problems.Add('mirrors.json gradle.repositories 至少需要 3 个地址')
    }
    if ($Context.Bootstrap.schemaVersion -ne 1) {
        $problems.Add('bootstrap.json schemaVersion 必须为 1')
    }
    foreach ($field in @('colorScheme', 'fontSize', 'opacity', 'useAcrylic', 'intenseTextStyle', 'theme', 'useAcrylicInTabRow')) {
        if (-not $Context.Bootstrap.terminal -or -not ($Context.Bootstrap.terminal.PSObject.Properties.Name -contains $field)) {
            $problems.Add("bootstrap.json terminal 缺少字段 $field")
        }
    }
    foreach ($check in @(
            @{ Data = 'bootstrap.json'; Schema = 'bootstrap.schema.json' },
            @{ Data = 'mirrors.json'; Schema = 'mirrors.schema.json' },
            @{ Data = 'packages.dev.json'; Schema = 'packages.schema.json' },
            @{ Data = 'packages.system.json'; Schema = 'packages.schema.json' },
            @{ Data = 'user.example.json'; Schema = 'user.schema.json' }
        )) {
        $schemaPath = Join-Path $Context.DataRoot ('schema\' + $check.Schema)
        if (-not (Test-Path -LiteralPath $schemaPath)) {
            $problems.Add("缺少 schema：$schemaPath")
            continue
        }
        $json = Get-Content -LiteralPath (Join-Path $Context.DataRoot $check.Data) -Raw
        $schema = Get-Content -LiteralPath $schemaPath -Raw
        if (-not (Test-Json -Json $json -Schema $schema -ErrorAction SilentlyContinue)) {
            $problems.Add("$($check.Data) 不符合 $($check.Schema)")
        }
    }
    @($problems)
}

function Invoke-WsPreflightStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $problems = [System.Collections.Generic.List[string]]::new()
    if ($PSVersionTable.PSVersion -lt [version]'7.4') {
        $problems.Add("需要 PowerShell 7.4+，当前为 $($PSVersionTable.PSVersion)")
    }
    foreach ($problem in @(Get-WsIdentityProblems)) {
        $problems.Add($problem)
    }
    if (-not (Get-Command 'winget' -ErrorAction SilentlyContinue)) {
        $problems.Add('winget 不可用')
    }
    foreach ($problem in @(Test-WsData -Context $Context)) {
        $problems.Add($problem)
    }
    if ($problems.Count -gt 0) {
        throw ('预检失败：' + ($problems -join '；'))
    }

    if ($Context.PlanStages -contains 'Base' -or $Context.PlanStages -contains 'System' -or $Context.PlanStages -contains 'Verify') {
        $Context.WorkspaceRoot = Resolve-WsWorkspaceRoot -Context $Context -Override $Context.WorkspaceRootOverride
        Write-WsLog "工作空间根目录：$($Context.WorkspaceRoot)" -Context $Context
    }
    Write-WsLog '预检通过' -Context $Context
}

function Invoke-WsBaseStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if (-not $Context.WorkspaceRoot) {
        $Context.WorkspaceRoot = Resolve-WsWorkspaceRoot -Context $Context -Override $Context.WorkspaceRootOverride
    }
    [void](New-WsWorkspace -Context $Context)
    $packages = @(Get-WsStagePackages -Context $Context -Stage 'base')
    Invoke-WsPackageGroup -Context $Context -Packages $packages
    Update-WsProcessPath -Context $Context
}

function Invoke-WsMirrorsStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    [void](Set-WsMirrors -Context $Context)
}

function Initialize-WsNodeToolchain {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if ($Context.DryRun) {
        Write-WsLog 'DryRun：将执行 corepack enable、pnpm 激活与 store 配置' -Context $Context
        return
    }
    if (-not (Get-Command 'corepack' -ErrorAction SilentlyContinue)) {
        $install = Invoke-WsProcess -FilePath 'npm' -Arguments @('install', '-g', 'corepack')
        if ($install.ExitCode -ne 0) {
            throw 'corepack 安装失败'
        }
    }
    foreach ($arguments in @(@('enable'), @('prepare', 'pnpm@latest', '--activate'))) {
        $result = Invoke-WsProcess -FilePath 'corepack' -Arguments $arguments
        if ($result.ExitCode -ne 0) {
            throw ('corepack ' + ($arguments -join ' ') + ' 失败')
        }
    }
    $store = Resolve-WsPnpmStore -Context $Context
    $result = Invoke-WsProcess -FilePath 'pnpm' -Arguments @('config', 'set', 'store-dir', $store)
    if ($result.ExitCode -ne 0) {
        throw 'pnpm store 配置失败'
    }
    Write-WsLog "pnpm store 指向 $store" -Context $Context
}

function Invoke-WsToolchainStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    Initialize-WsNodeToolchain -Context $Context
    $packages = @(Get-WsStagePackages -Context $Context -Stage 'toolchain')
    if (@($packages | Where-Object { $_.provider -eq 'pacman' }).Count -gt 0) {
        Initialize-WsPacman -Context $Context
    }
    Invoke-WsPackageGroup -Context $Context -Packages $packages
    if ($Context.IncludeOptional) {
        $optional = @(Get-WsStagePackages -Context $Context -Stage 'optional')
        Invoke-WsPackageGroup -Context $Context -Packages $optional
    }
    Update-WsProcessPath -Context $Context
}

function Invoke-WsProxyStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $proxy = $Context.Bootstrap.proxy
    if (-not (Test-WsPortListening -HostName $proxy.host -Port $proxy.port)) {
        Write-WsLog "未检测到代理 $($proxy.host):$($proxy.port)，跳过 Proxy 阶段。启动代理后运行 just bootstrap -Stages Proxy 补齐。" -Level WARN -Context $Context
        return
    }
    $packages = @(Get-WsStagePackages -Context $Context -Stage 'proxy')
    Invoke-WsPackageGroup -Context $Context -Packages $packages
    Update-WsProcessPath -Context $Context
}

function Invoke-WsOptionalStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $packages = @(Get-WsStagePackages -Context $Context -Stage 'optional')
    Invoke-WsPackageGroup -Context $Context -Packages $packages
    Update-WsProcessPath -Context $Context
}

function Invoke-WsConfigStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if (-not $Context.User) {
        if ($Context.DryRun) {
            Write-WsLog 'DryRun 缺少 data/user.json，跳过 Config 阶段' -Level SKIP -Context $Context
            return
        }
        $Context.User = Read-WsUserConfig -Context $Context
    }
    Set-WsGlobalAgents -Context $Context
    Set-WsGitConfig -Context $Context
    if ($Context.User.writeAiConfig) {
        Set-WsAiConfig -Context $Context
    } else {
        Write-WsLog '跳过 Claude/Trae 配置（writeAiConfig=false）' -Level SKIP -Context $Context
    }
    Set-WsTerminalAppearance -Context $Context
}

function ConvertTo-WsVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Text)

    $normalized = if ($Text -match '\.') { $Text } else { $Text + '.0' }
    $version = $null
    if ([version]::TryParse($normalized, [ref]$version)) {
        return $version
    }
    return [version]'0.0'
}

function Get-WsLatestVersionDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$NamePattern
    )

    if (-not (Test-Path -LiteralPath $Root)) {
        return $null
    }
    $candidates = foreach ($directory in @(Get-ChildItem -LiteralPath $Root -Directory)) {
        if ($directory.Name -match $NamePattern) {
            [pscustomobject]@{
                Directory = $directory
                Version   = ConvertTo-WsVersion -Text $Matches[1]
            }
        }
    }
    $latest = $candidates | Sort-Object Version -Descending | Select-Object -First 1
    if ($latest) {
        return $latest.Directory.FullName
    }
    return $null
}

function Get-WsJdkHome {
    [CmdletBinding()]
    param([string]$Root = 'C:\Program Files\Java')

    Get-WsLatestVersionDirectory -Root $Root -NamePattern '^jdk-(\d+(?:\.\d+)*)$'
}

function Get-WsCudaHome {
    [CmdletBinding()]
    param([string]$Root = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA')

    Get-WsLatestVersionDirectory -Root $Root -NamePattern '^v(\d+(?:\.\d+)*)$'
}

function Invoke-WsEnvironmentStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $pathConfig = $Context.Bootstrap.path
    [void](Set-WsPath -Context $Context -Scope 'Machine' -Head @($pathConfig.machineHead) -Tail @($pathConfig.machineTail))
    [void](Set-WsPath -Context $Context -Scope 'User' -Head @($pathConfig.user) -Tail @())

    [void](Set-WsEnvironmentVariable -Context $Context -Name 'HOME' -Value $Context.Home -Scope 'User')
    $jdkHome = Get-WsJdkHome
    if ($jdkHome) {
        [void](Set-WsEnvironmentVariable -Context $Context -Name 'JAVA_HOME' -Value $jdkHome -Scope 'Machine')
    } else {
        Write-WsLog '未找到 JDK 目录，跳过 JAVA_HOME' -Level WARN -Context $Context
    }
    if (Get-WsGpuAvailability -Context $Context) {
        $cudaHome = Get-WsCudaHome
        if ($cudaHome) {
            [void](Set-WsEnvironmentVariable -Context $Context -Name 'CUDA_PATH' -Value $cudaHome -Scope 'Machine')
        } else {
            Write-WsLog '未找到 CUDA 目录，跳过 CUDA_PATH' -Level WARN -Context $Context
        }
    }
    [void](Set-WsEnvironmentVariable -Context $Context -Name 'PYTHONUTF8' -Value '1' -Scope 'Machine')
    $vcpkgRoot = Get-WsExpandedPath -Value $Context.Bootstrap.paths.vcpkg -Context $Context
    [void](Set-WsEnvironmentVariable -Context $Context -Name 'VCPKG_ROOT' -Value $vcpkgRoot -Scope 'User')

    $goPath = [Environment]::GetEnvironmentVariable('GOPATH', 'User')
    if ([string]::IsNullOrWhiteSpace($goPath)) {
        [void](Set-WsEnvironmentVariable -Context $Context -Name 'GOPATH' -Value (Join-Path $Context.Home 'go') -Scope 'User')
    }
    [void](Clear-WsSslVariables -Context $Context)
    if (-not $Context.DryRun) {
        Send-WsEnvironmentChange
    }
}

function Invoke-WsSystemStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    $packages = @(Get-WsStagePackages -Context $Context -Stage 'system')
    Invoke-WsPackageGroup -Context $Context -Packages $packages
    [void](Set-WsSystemSettings -Context $Context)
}

function Test-WsEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [switch]$IncludeMirrors,
        [switch]$IncludeWorkspace,
        [switch]$IncludeSystemSettings,
        [switch]$RepairProcessEnvironment
    )

    $failures = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $versions = [System.Collections.Generic.List[object]]::new()
    $home = $Context.Home

    if ($RepairProcessEnvironment) {
        $env:HOME = $home
        foreach ($name in @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE')) {
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
    }
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $failures.Add("需要 PowerShell 7+，当前为 $($PSVersionTable.PSVersion)")
    }
    foreach ($problem in @(Get-WsIdentityProblems)) {
        $failures.Add($problem)
    }
    if ($env:HOME -ne $home) {
        $failures.Add("当前进程 HOME 为 $env:HOME，应为 $home")
    }
    foreach ($name in @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($value) {
            $failures.Add("当前进程仍设置 $name=$value")
        }
    }

    $specs = @()
    if ($Context.Profile -ne 'System') {
        $specs = @(
        @{ Name = 'pwsh'; Args = @('--version') },
        @{ Name = 'uv'; Args = @('--version') },
        @{ Name = 'just'; Args = @('--version') },
        @{ Name = 'git'; Args = @('--version') },
        @{ Name = 'gh'; Args = @('--version') },
        @{ Name = 'node'; Args = @('--version') },
        @{ Name = 'npm'; Args = @('--version') },
        @{ Name = 'pnpm'; Args = @('--version') },
        @{ Name = 'gcc'; Args = @('--version') },
        @{ Name = 'g++'; Args = @('--version') },
        @{ Name = 'cmake'; Args = @('--version') },
        @{ Name = 'ninja'; Args = @('--version') },
        @{ Name = 'clangd'; Args = @('--version') },
        @{ Name = 'ccache'; Args = @('--version') },
        @{ Name = 'openocd'; Args = @('--version') },
        @{ Name = 'pyocd'; Args = @('--version') },
        @{ Name = 'ruff'; Args = @('--version') },
        @{ Name = 'pre-commit'; Args = @('--version') },
        @{ Name = 'gitleaks'; Args = @('version') },
        @{ Name = 'ast-grep'; Args = @('--version') },
        @{ Name = 'delta'; Args = @('--version') },
        @{ Name = 'jq'; Args = @('--version') },
        @{ Name = 'yq'; Args = @('--version') },
        @{ Name = 'rclone'; Args = @('version') },
        @{ Name = 'ffmpeg'; Args = @('-version') },
        @{ Name = 'code'; Args = @('--version') },
        @{ Name = 'mvn'; Args = @('-v') },
        @{ Name = 'gradle'; Args = @('-v') },
        @{ Name = 'java'; Args = @('-version') },
        @{ Name = 'go'; Args = @('version') },
        @{ Name = 'rustc'; Args = @('--version') },
        @{ Name = 'cargo'; Args = @('--version') },
        @{ Name = 'dotnet'; Args = @('--version') },
        @{ Name = 'arm-none-eabi-gcc'; Args = @('--version') }
        )
        if (Get-WsGpuAvailability -Context $Context) {
            $specs += @{ Name = 'nvcc'; Args = @('--version') }
        } else {
            $warnings.Add('未检测到 NVIDIA GPU，跳过 nvcc 检查')
        }
    }

    $proxyTools = @('pyocd', 'ruff', 'pre-commit')
    $proxy = $Context.Bootstrap.proxy
    $proxyReady = Test-WsPortListening -HostName $proxy.host -Port $proxy.port
    foreach ($spec in $specs) {
        $toolPath = Resolve-WsToolPath -Context $Context -Name $spec.Name
        if (-not $toolPath) {
            if ($proxyTools -contains $spec.Name -and -not $proxyReady) {
                $warnings.Add("缺少命令 $($spec.Name)（需要代理，Proxy 阶段未完成）")
            } else {
                $failures.Add("缺少命令：$($spec.Name)")
            }
            continue
        }
        $result = Invoke-WsProcess -FilePath $toolPath -Arguments $spec.Args
        $firstLine = @($result.Output | Where-Object { $_ -and ([string]$_).Trim() -notmatch '^[-_=]{3,}$' } | Select-Object -First 1)
        $versionText = if ($firstLine.Count -gt 0) { [string]$firstLine[0] } else { '(无输出)' }
        $versions.Add([pscustomobject]@{ Name = $spec.Name; Version = $versionText; Path = $toolPath })
        Write-Host ("{0}: {1}" -f $spec.Name, $versionText)
    }

    if ($Context.Profile -ne 'System') {
        foreach ($moduleSpec in @(@{ Name = 'PSScriptAnalyzer'; Minimum = '1.25.0' }, @{ Name = 'Pester'; Minimum = '6.2.0' })) {
            $module = Get-Module -ListAvailable -Name $moduleSpec.Name |
                Sort-Object Version -Descending |
                Select-Object -First 1
            if (-not $module -or $module.Version -lt [version]$moduleSpec.Minimum) {
                $failures.Add("缺少 $($moduleSpec.Name) $($moduleSpec.Minimum) 或更高版本")
            }
        }
    }

    if ($IncludeWorkspace) {
        if (-not $Context.WorkspaceRoot) {
            $Context.WorkspaceRoot = Resolve-WsWorkspaceRoot -Context $Context -Override $Context.WorkspaceRootOverride
        }
        if (-not (Test-Path -LiteralPath $Context.WorkspaceRoot)) {
            $failures.Add("工作空间根目录不存在：$($Context.WorkspaceRoot)")
        } else {
            foreach ($directory in @($Context.Bootstrap.workspace.directories)) {
                $path = Join-Path $Context.WorkspaceRoot $directory
                if (-not (Test-Path -LiteralPath $path)) {
                    $failures.Add("工作空间子目录不存在：$path")
                }
            }
        }
    }

    if ($IncludeMirrors) {
        $mirrorChecks = @(
            @{ Path = (Join-Path $home 'pip\pip.ini'); Host = (Get-WsUriHost -Uri $Context.Mirrors.pip.indexUrl); Label = 'pip' },
            @{ Path = (Join-Path $Context.AppData 'uv\uv.toml'); Host = (Get-WsUriHost -Uri $Context.Mirrors.uv.indexUrl); Label = 'uv' },
            @{ Path = (Join-Path $home '.npmrc'); Host = (Get-WsUriHost -Uri $Context.Mirrors.npm.registry); Label = 'npm' },
            @{ Path = (Join-Path $home '.cargo\config.toml'); Host = (Get-WsUriHost -Uri $Context.Mirrors.cargo.registry); Label = 'cargo' },
            @{ Path = (Join-Path $home '.m2\settings.xml'); Host = (Get-WsUriHost -Uri $Context.Mirrors.maven.mirrorUrl); Label = 'maven' },
            @{ Path = (Join-Path $home '.gradle\init.gradle'); Host = (Get-WsUriHost -Uri @($Context.Mirrors.gradle.repositories)[0]); Label = 'gradle' },
            @{ Path = (Join-Path $Context.AppData 'NuGet\NuGet.Config'); Host = (Get-WsUriHost -Uri $Context.Mirrors.nuget.huawei); Label = 'nuget' }
        )
        foreach ($check in $mirrorChecks) {
            if (-not (Test-Path -LiteralPath $check.Path)) {
                $failures.Add("缺少 $($check.Label) 镜像配置：$($check.Path)")
                continue
            }
            if (-not $check.Host) {
                $warnings.Add("$($check.Label) 镜像地址未在 data/mirrors.json 中定义")
                continue
            }
            $text = Get-Content -LiteralPath $check.Path -Raw
            if ($text -notmatch [regex]::Escape([string]$check.Host)) {
                $failures.Add("$($check.Label) 镜像配置未包含预期主机 $($check.Host)：$($check.Path)")
            }
        }
        if (Get-Command 'go' -ErrorAction SilentlyContinue) {
            $goProxy = Invoke-WsProcess -FilePath 'go' -Arguments @('env', 'GOPROXY')
            if (($goProxy.Output -join "`n") -notmatch 'goproxy\.cn') {
                $failures.Add('go env GOPROXY 未包含 goproxy.cn')
            }
            $goSum = Invoke-WsProcess -FilePath 'go' -Arguments @('env', 'GOSUMDB')
            if (($goSum.Output -join "`n").Trim() -ne [string]$Context.Mirrors.go.sumdb) {
                $failures.Add('go env GOSUMDB 与 data/mirrors.json 不一致')
            }
        } else {
            $warnings.Add('未找到 go，跳过 Go 镜像检查')
        }
        $pacmanPath = Join-Path $Context.Bootstrap.paths.msys2 'etc\pacman.conf'
        if (Test-Path -LiteralPath $pacmanPath) {
            $pacmanText = Get-Content -LiteralPath $pacmanPath -Raw
            $pacmanHost = Get-WsUriHost -Uri @($Context.Mirrors.msys2.servers)[0]
            if (-not $pacmanHost) {
                $warnings.Add('data/mirrors.json 未定义 msys2 镜像')
            } elseif (
                $pacmanText -notmatch [regex]::Escape(('Server = https://' + $pacmanHost + '/msys2/mingw/ucrt64')) -or
                $pacmanText -notmatch [regex]::Escape(('Server = https://' + $pacmanHost + '/msys2/msys/x86_64'))
            ) {
                $failures.Add("pacman.conf 缺少受管 Server 行：$pacmanPath")
            }
        } else {
            $warnings.Add("未找到 pacman.conf：$pacmanPath")
        }
        foreach ($rustup in @(
                @{ Name = 'RUSTUP_DIST_SERVER'; Expected = [string]$Context.Mirrors.rustup.distServer },
                @{ Name = 'RUSTUP_UPDATE_ROOT'; Expected = [string]$Context.Mirrors.rustup.updateRoot },
                @{ Name = 'COREPACK_NPM_REGISTRY'; Expected = [string]$Context.Mirrors.corepack.registry })) {
            $value = [Environment]::GetEnvironmentVariable($rustup.Name, 'User')
            if ($value -ne $rustup.Expected) {
                $failures.Add("$($rustup.Name) 与 data/mirrors.json 不一致")
            }
        }
    }

    if ($IncludeSystemSettings) {
        $longPaths = Get-WsRegistryValue -Hive 'HKLM' -SubKey 'SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled'
        if (-not $longPaths -or [int]$longPaths.Value -ne 1) {
            $failures.Add('未启用长路径支持')
        }
        $developerMode = Get-WsRegistryValue -Hive 'HKLM' -SubKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense'
        if (-not $developerMode -or [int]$developerMode.Value -ne 1) {
            $failures.Add('未启用开发者模式')
        }
    }

    [pscustomobject]@{
        Failures = @($failures)
        Warnings = @($warnings)
        Versions = @($versions)
    }
}

function Invoke-WsVerifyStage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context)

    if ($Context.DryRun) {
        Write-WsLog 'DryRun：跳过实际验收' -Context $Context
        return
    }
    $includeWorkspace = $Context.Profile -in @('Dev', 'All')
    $includeMirrors = $Context.Profile -in @('Dev', 'All')
    $includeSystem = $Context.Profile -in @('System', 'All')
    $result = Test-WsEnvironment -Context $Context -IncludeWorkspace:$includeWorkspace -IncludeMirrors:$includeMirrors -IncludeSystemSettings:$includeSystem
    foreach ($warning in $result.Warnings) {
        Write-WsLog $warning -Level WARN -Context $Context
        $Context.Warnings.Add($warning)
    }
    foreach ($failure in $result.Failures) {
        Write-WsLog $failure -Level ERROR -Context $Context
        $Context.Failures.Add($failure)
    }
    if (@($result.Failures).Count -gt 0) {
        $Context.VerifyFailed = $true
    } else {
        Write-WsLog '验收通过' -Context $Context
    }
}

function Invoke-WsStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$Name
    )

    switch ($Name) {
        'Preflight' { Invoke-WsPreflightStage -Context $Context }
        'Base' { Invoke-WsBaseStage -Context $Context }
        'Mirrors' { Invoke-WsMirrorsStage -Context $Context }
        'Toolchain' { Invoke-WsToolchainStage -Context $Context }
        'Config' { Invoke-WsConfigStage -Context $Context }
        'Environment' { Invoke-WsEnvironmentStage -Context $Context }
        'System' { Invoke-WsSystemStage -Context $Context }
        'Proxy' { Invoke-WsProxyStage -Context $Context }
        'Optional' { Invoke-WsOptionalStage -Context $Context }
        'Verify' { Invoke-WsVerifyStage -Context $Context }
        default { throw "未知阶段：$Name" }
    }
}

