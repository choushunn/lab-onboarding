# Packages.ps1 - 包提供方安装、探测与失败策略

function Get-WsStagePackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][ValidateSet('base', 'toolchain', 'optional', 'system', 'proxy')][string]$Stage
    )

    $source = if ($Stage -eq 'system') { @($Context.SystemPackages.packages) } else { @($Context.DevPackages.packages) }
    @($source | Where-Object { $_.stage -eq $Stage })
}

function Invoke-WsDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$OutFile
    )

    Invoke-WebRequest -Uri $Uri -OutFile $OutFile
}

function Get-WsHttpText {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Uri)

    $response = Invoke-WebRequest -Uri $Uri
    [string]$response.Content
}

function Test-WsArchiveEntryPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$EntryPath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if ([string]::IsNullOrWhiteSpace($EntryPath)) {
        return $true
    }
    $relative = $EntryPath -replace '/', [IO.Path]::DirectorySeparatorChar
    if ([IO.Path]::IsPathRooted($relative)) {
        return $false
    }
    $root = [IO.Path]::GetFullPath($DestinationPath).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $target = [IO.Path]::GetFullPath((Join-Path $root $relative))
    $target.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Expand-WsArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $archive.Entries) {
            if (-not (Test-WsArchiveEntryPath -EntryPath $entry.FullName -DestinationPath $DestinationPath)) {
                throw "归档条目越界：$($entry.FullName)"
            }
        }
    } finally {
        $archive.Dispose()
    }
    Expand-Archive -LiteralPath $Path -DestinationPath $DestinationPath -Force
}

function Get-WsPackageHash {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Package)

    foreach ($algorithm in @('sha256', 'sha512')) {
        if ($Package.PSObject.Properties.Name -contains $algorithm -and $Package.$algorithm) {
            return [pscustomobject]@{
                Algorithm = $algorithm.ToUpperInvariant()
                Value     = ([string]$Package.$algorithm).ToLowerInvariant()
            }
        }
    }
    $hashUrls = @($Package.hashUrls | Where-Object { $_ })
    if ($hashUrls.Count -eq 0) {
        return $null
    }
    $text = (Get-WsHttpText -Uri $hashUrls[0]).Trim()
    $value = ($text -split '\s+')[0]
    if (-not $value) {
        throw "哈希清单为空：$($Package.id)"
    }
    $algorithm = switch ($value.Length) {
        64 { 'SHA256' }
        128 { 'SHA512' }
        default { throw "无法识别哈希长度：$($Package.id)" }
    }
    [pscustomobject]@{
        Algorithm = $algorithm
        Value     = $value.ToLowerInvariant()
    }
}

function Assert-WsFileHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $expected = Get-WsPackageHash -Package $Package
    if (-not $expected) {
        Write-WsLog "未配置哈希校验：$($Package.id)" -Level WARN -Context $Context
        return 'Unverified'
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm $expected.Algorithm).Hash.ToLowerInvariant()
    if ($actual -ne $expected.Value) {
        throw "$($Package.name) 哈希校验失败：期望 $($expected.Value)，实际 $actual"
    }
    Write-WsLog "哈希校验通过：$($Package.id)" -Context $Context
    'Verified'
}

function Test-WsWingetInstalled {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$PackageId)

    $result = Invoke-WsProcess -FilePath 'winget' -Arguments @(
        'list', '--id', $PackageId, '-e', '--accept-source-agreements'
    )
    $result.ExitCode -eq 0
}

function Install-WsWingetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    if (-not $Context.ReinstallPackages -and (Test-WsWingetInstalled -PackageId $Package.packageId)) {
        return 'AlreadyPresent'
    }
    $arguments = @(
        'install', '--id', $Package.packageId, '-e', '--silent',
        '--accept-source-agreements', '--accept-package-agreements'
    )
    if ($Context.ReinstallPackages) {
        $arguments += '--force'
    }
    $result = Invoke-WsProcess -FilePath 'winget' -Arguments $arguments
    if ($result.ExitCode -ne 0) {
        throw "winget 安装 $($Package.packageId) 失败，退出码 $($result.ExitCode)"
    }
    'Installed'
}

function Install-WsExeInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    $target = Get-WsExpandedPath -Value $Package.target -Context $Context
    $verifyPath = if ($Package.verifyPath) { Get-WsExpandedPath -Value $Package.verifyPath -Context $Context } else { $null }
    $present = (Test-Path -LiteralPath $target) -or ($verifyPath -and (Test-Path -LiteralPath $verifyPath))
    if (-not $Context.ReinstallPackages -and $present) {
        return 'AlreadyPresent'
    }

    $installer = Join-Path $env:TEMP ('wsbootstrap-' + $Package.id + '.exe')
    $downloaded = $false
    foreach ($url in @($Package.urls)) {
        try {
            Invoke-WsDownload -Uri $url -OutFile $installer
            $downloaded = $true
            break
        } catch {
            Write-WsLog "下载失败，尝试下一个地址：$url" -Level WARN -Context $Context
        }
    }
    if (-not $downloaded) {
        throw "全部下载地址失败：$($Package.id)"
    }
    try {
        [void](Assert-WsFileHash -Context $Context -Package $Package -Path $installer)
    } catch {
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
        throw
    }
    $result = Invoke-WsProcess -FilePath $installer -Arguments @($Package.args)
    Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    if ($result.ExitCode -ne 0) {
        throw "$($Package.name) 安装器退出码 $($result.ExitCode)"
    }
    'Installed'
}

function Install-WsFileDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    if (-not $Context.ReinstallPackages) {
        if ($Package.registryName -and (Test-WsRegisteredProgram -Pattern ([string]$Package.registryName))) {
            return 'AlreadyPresent'
        }
        foreach ($raw in @($Package.verifyPaths)) {
            if (-not $raw) {
                continue
            }
            if (Test-Path -LiteralPath (Get-WsExpandedPath -Value $raw -Context $Context)) {
                return 'AlreadyPresent'
            }
        }
    }
    $target = Get-WsExpandedPath -Value $Package.target -Context $Context
    if (Test-Path -LiteralPath $target) {
        return 'AlreadyPresent'
    }
    $directory = Split-Path -Parent $target
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    foreach ($url in @($Package.urls)) {
        try {
            Invoke-WsDownload -Uri $url -OutFile $target
            [void](Assert-WsFileHash -Context $Context -Package $Package -Path $target)
            return 'Downloaded'
        } catch {
            Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
            Write-WsLog "下载或校验失败，尝试下一个地址：$url" -Level WARN -Context $Context
        }
    }
    throw "全部下载地址失败：$($Package.id)"
}

function Test-WsRegisteredProgram {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Pattern)

    foreach ($root in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )) {
        $found = Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $Pattern } |
            Select-Object -First 1
        if ($found) {
            return $true
        }
    }
    return $false
}

function Install-WsLocalInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    $installer = Join-Path (Join-Path $Context.RepoRoot 'installers') ([string]$Package.file)
    if (-not (Test-Path -LiteralPath $installer)) {
        throw "未找到本地安装包：$installer"
    }
    if (-not $Context.ReinstallPackages -and $Package.registryName -and (Test-WsRegisteredProgram -Pattern ([string]$Package.registryName))) {
        return 'AlreadyPresent'
    }
    $result = Invoke-WsProcess -FilePath $installer -Arguments @($Package.args)
    if ($result.ExitCode -ne 0) {
        throw "$($Package.name) 安装器退出码 $($result.ExitCode)"
    }
    'Installed'
}

function Install-WsZipDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    $target = Get-WsExpandedPath -Value $Package.target -Context $Context
    if (-not $Context.ReinstallPackages -and (Test-Path -LiteralPath $target)) {
        return 'AlreadyPresent'
    }

    $archive = Join-Path $env:TEMP ('wsbootstrap-' + $Package.id + '.zip')
    $downloaded = $false
    foreach ($url in @($Package.urls)) {
        try {
            Invoke-WsDownload -Uri $url -OutFile $archive
            $downloaded = $true
            break
        } catch {
            Write-WsLog "下载失败，尝试下一个地址：$url" -Level WARN -Context $Context
        }
    }
    if (-not $downloaded) {
        throw "全部下载地址失败：$($Package.id)"
    }
    try {
        [void](Assert-WsFileHash -Context $Context -Package $Package -Path $archive)
    } catch {
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
        throw
    }

    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $before = @(Get-ChildItem -LiteralPath $parent -Directory | Select-Object -ExpandProperty FullName)
    Expand-WsArchive -Path $archive -DestinationPath $parent
    if (-not (Test-Path -LiteralPath $target)) {
        $created = @(Get-ChildItem -LiteralPath $parent -Directory | Where-Object { $before -notcontains $_.FullName })
        if ($created.Count -eq 1) {
            Move-Item -LiteralPath $created[0].FullName -Destination $target
        } else {
            throw "解压后未找到目标目录：$target"
        }
    }
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    'Installed'
}

function Get-WsWheelUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$IndexUrl,
        [Parameter(Mandatory = $true)][string]$WheelPattern
    )

    $html = Get-WsHttpText -Uri $IndexUrl
    $pattern = [regex]::Escape($WheelPattern).Replace('\*', '.*')
    $links = [regex]::Matches($html, 'href="(?<href>[^"]+)"') |
        ForEach-Object { $_.Groups['href'].Value } |
        ForEach-Object { ($_ -split '#')[0] } |
        Where-Object { $_ -match $pattern } |
        Sort-Object -Unique
    if (-not $links) {
        throw "索引中未找到匹配 $WheelPattern 的文件：$IndexUrl"
    }
    $best = $null
    $bestVersion = $null
    foreach ($link in $links) {
        $name = Split-Path -Leaf $link
        $versionText = $name -replace '^uv-', '' -replace '-py3-none-win_amd64\.whl$', ''
        $version = $null
        if (-not [version]::TryParse($versionText, [ref]$version)) {
            continue
        }
        if ($null -eq $bestVersion -or $version -gt $bestVersion) {
            $bestVersion = $version
            $best = $link
        }
    }
    if (-not $best) {
        $best = $links | Select-Object -Last 1
    }
    if ($best -match '^https?://') {
        return $best
    }
    ([Uri]::new([Uri]$IndexUrl, $best)).AbsoluteUri
}

function Install-WsWheelExtract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    $target = Get-WsExpandedPath -Value $Package.target -Context $Context
    $files = @($Package.files)
    $present = $files.Count -gt 0
    foreach ($file in $files) {
        if (-not (Test-Path -LiteralPath (Join-Path $target $file))) {
            $present = $false
        }
    }
    if (-not $Context.ReinstallPackages -and $present) {
        return 'AlreadyPresent'
    }

    $wheelUrl = Get-WsWheelUrl -IndexUrl $Package.indexUrl -WheelPattern $Package.wheelPattern
    $wheel = Join-Path $env:TEMP ('wsbootstrap-' + $Package.id + '.whl')
    Invoke-WsDownload -Uri $wheelUrl -OutFile $wheel
    try {
        [void](Assert-WsFileHash -Context $Context -Package $Package -Path $wheel)
    } catch {
        Remove-Item -LiteralPath $wheel -Force -ErrorAction SilentlyContinue
        throw
    }

    $archive = Join-Path $env:TEMP ('wsbootstrap-' + $Package.id + '.zip')
    Copy-Item -LiteralPath $wheel -Destination $archive -Force
    $extractDir = Join-Path $env:TEMP ('wsbootstrap-' + $Package.id + '-files')
    if (Test-Path -LiteralPath $extractDir) {
        Remove-Item -LiteralPath $extractDir -Recurse -Force
    }
    Expand-WsArchive -Path $archive -DestinationPath $extractDir

    if (-not (Test-Path -LiteralPath $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }
    foreach ($file in $files) {
        $source = Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter $file | Select-Object -First 1
        if (-not $source) {
            throw "wheel 中缺少 $file"
        }
        Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $target $file) -Force
    }
    Remove-Item -LiteralPath $wheel -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    'Installed'
}

function Install-WsGitClone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    $target = Get-WsExpandedPath -Value $Package.target -Context $Context
    if (-not $Context.ReinstallPackages) {
        foreach ($raw in @($Package.verifyPaths)) {
            if (-not $raw) {
                continue
            }
            if (Test-Path -LiteralPath (Get-WsExpandedPath -Value $raw -Context $Context)) {
                return 'AlreadyPresent'
            }
        }
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw '未找到 git，无法克隆仓库'
    }
    $proxy = $Context.Bootstrap.proxy
    $proxyUrl = 'http://{0}:{1}' -f $proxy.host, $proxy.port
    $useProxy = Test-WsPortListening -HostName ([string]$proxy.host) -Port ([int]$proxy.port)
    $gitArgs = @()
    if ($useProxy) {
        $gitArgs += @('-c', "http.proxy=$proxyUrl", '-c', "https.proxy=$proxyUrl")
    }
    if (-not (Test-Path -LiteralPath $target)) {
        $parent = Split-Path -Parent $target
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        $gitArgs += @('clone', '--depth', '1', '--branch', 'master', [string]$Package.repo, $target)
        $clone = Invoke-WsProcess -FilePath 'git' -Arguments $gitArgs
        if ($clone.ExitCode -ne 0) {
            throw "克隆失败：$($Package.repo)"
        }
    }
    if ($Package.bootstrap) {
        $bootstrapPath = Join-Path $target ([string]$Package.bootstrap)
        if (-not (Test-Path -LiteralPath $bootstrapPath)) {
            throw "缺少引导脚本：$bootstrapPath"
        }
        $oldHttp = $env:HTTP_PROXY
        $oldHttps = $env:HTTPS_PROXY
        if ($useProxy) {
            $env:HTTP_PROXY = $proxyUrl
            $env:HTTPS_PROXY = $proxyUrl
        }
        try {
            $run = Invoke-WsProcess -FilePath $env:ComSpec -Arguments @('/c', "`"$bootstrapPath`" -disableMetrics")
        } finally {
            $env:HTTP_PROXY = $oldHttp
            $env:HTTPS_PROXY = $oldHttps
        }
        if ($run.ExitCode -ne 0) {
            throw 'vcpkg 引导失败'
        }
    }
    'Installed'
}

function Install-WsUvPython {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    $version = [string]$Package.version
    $installed = Invoke-WsProcess -FilePath 'uv' -Arguments @('python', 'list', '--only-installed')
    if (-not $Context.ReinstallPackages -and $installed.ExitCode -eq 0 -and (($installed.Output -join "`n") -match [regex]::Escape($version))) {
        return 'AlreadyPresent'
    }
    $proxy = $Context.Bootstrap.proxy
    if (-not (Test-WsPortListening -HostName $proxy.host -Port $proxy.port)) {
        throw "uv python install 需要访问 GitHub，请先运行 scripts\proxy-on.ps1 并确认 $($proxy.host):$($proxy.port) 已监听"
    }
    $result = Invoke-WsProcess -FilePath 'uv' -Arguments @('python', 'install', $version)
    if ($result.ExitCode -ne 0) {
        throw "uv python install $version 失败"
    }
    'Installed'
}

function Install-WsUvTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    if (-not $Context.ReinstallPackages) {
        $list = Invoke-WsProcess -FilePath 'uv' -Arguments @('tool', 'list')
        if ($list.ExitCode -eq 0 -and (($list.Output -join "`n") -match "(?m)^\s*" + [regex]::Escape($Package.packageId) + '\s')) {
            return 'AlreadyPresent'
        }
    }
    $arguments = @('tool', 'install')
    if ($Context.ReinstallPackages) {
        $arguments += '--force'
    }
    $arguments += $Package.packageId
    $result = Invoke-WsProcess -FilePath 'uv' -Arguments $arguments
    if ($result.ExitCode -ne 0) {
        throw "uv tool install $($Package.packageId) 失败"
    }
    'Installed'
}

function Install-WsNpmPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    if (-not $Context.ReinstallPackages) {
        $check = Invoke-WsProcess -FilePath 'npm' -Arguments @('ls', '-g', '--depth=0', $Package.packageId)
        if ($check.ExitCode -eq 0) {
            return 'AlreadyPresent'
        }
    }
    $result = Invoke-WsProcess -FilePath 'npm' -Arguments @('install', '-g', ($Package.packageId + '@latest'))
    if ($result.ExitCode -ne 0) {
        throw "npm 安装 $($Package.packageId) 失败"
    }
    'Installed'
}

function Initialize-WsPacman {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [string]$BashPath
    )

    if ($Context.DryRun) {
        Write-WsLog 'DryRun：将检查并初始化 pacman 密钥环' -Context $Context
        return 'Planned'
    }
    if (-not $BashPath) {
        $BashPath = Join-Path $Context.Bootstrap.paths.msys2 'usr\bin\bash.exe'
    }
    if (-not (Test-Path -LiteralPath $BashPath)) {
        throw "MSYS2 未安装：$BashPath"
    }
    $check = Invoke-WsProcess -FilePath $BashPath -Arguments @('-lc', 'pacman-key --list-keys >/dev/null 2>&1')
    if ($check.ExitCode -eq 0) {
        return 'Ready'
    }
    Write-WsLog 'pacman 密钥环未初始化，执行 pacman-key --init 与 --populate msys2' -Context $Context
    $init = Invoke-WsProcess -FilePath $BashPath -Arguments @('-lc', 'pacman-key --init && pacman-key --populate msys2')
    if ($init.ExitCode -ne 0) {
        throw 'pacman 密钥环初始化失败'
    }
    'Initialized'
}

function Install-WsPacmanPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    $bash = Join-Path $Context.Bootstrap.paths.msys2 'usr\bin\bash.exe'
    if (-not (Test-Path -LiteralPath $bash)) {
        throw "MSYS2 未安装：$bash"
    }
    if (-not $Context.ReinstallPackages) {
        $query = Invoke-WsProcess -FilePath $bash -Arguments @('-lc', ('pacman -Q ' + $Package.packageId))
        if ($query.ExitCode -eq 0) {
            return 'AlreadyPresent'
        }
    }
    $command = 'pacman -Sy --needed --noconfirm ' + $Package.packageId
    $result = Invoke-WsProcess -FilePath $bash -Arguments @('-lc', $command)
    if ($result.ExitCode -ne 0) {
        throw "pacman 安装 $($Package.packageId) 失败"
    }
    'Installed'
}

function Install-WsPsModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    $module = Get-Module -ListAvailable -Name $Package.packageId |
        Sort-Object Version -Descending |
        Select-Object -First 1
    $minimum = if ($Package.minimumVersion) { [version]$Package.minimumVersion } else { $null }
    if (-not $Context.ReinstallPackages -and $module -and (-not $minimum -or $module.Version -ge $minimum)) {
        return 'AlreadyPresent'
    }
    $parameters = @{
        Name        = $Package.packageId
        Scope       = 'CurrentUser'
        Force       = $true
        AllowClobber = $true
    }
    if ($Package.packageId -eq 'Pester') {
        $parameters['SkipPublisherCheck'] = $true
    }
    Install-Module @parameters
    'Installed'
}

function Install-WsVsCodeExtension {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    if (-not $Context.ReinstallPackages) {
        $list = Invoke-WsProcess -FilePath 'code' -Arguments @('--list-extensions')
        $installed = @($list.Output | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
        if ($installed -contains ([string]$Package.packageId).ToLowerInvariant()) {
            return 'AlreadyPresent'
        }
    }
    $result = Invoke-WsProcess -FilePath 'code' -Arguments @('--install-extension', $Package.packageId, '--force')
    if ($result.ExitCode -ne 0) {
        throw "VS Code 扩展安装失败：$($Package.packageId)"
    }
    'Installed'
}

function Invoke-WsPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][object]$Package
    )

    $result = [pscustomobject]@{
        Id       = $Package.id
        Name     = $Package.name
        Provider = $Package.provider
        Status   = 'Planned'
        Message  = ''
    }

    if ($Package.condition -eq 'nvidiaGpu' -and -not (Get-WsGpuAvailability -Context $Context)) {
        $result.Status = 'SkippedNoGpu'
        $result.Message = '未检测到 NVIDIA GPU'
        return $result
    }
    if ($Context.DryRun) {
        $result.Message = 'DryRun：不执行安装'
        return $result
    }

    try {
        $result.Status = switch ($Package.provider) {
            'winget' { Install-WsWingetPackage -Context $Context -Package $Package }
            'exeInstaller' { Install-WsExeInstaller -Context $Context -Package $Package }
            'localInstaller' { Install-WsLocalInstaller -Context $Context -Package $Package }
            'fileDownload' { Install-WsFileDownload -Context $Context -Package $Package }
            'zipDownload' { Install-WsZipDownload -Context $Context -Package $Package }
            'wheelExtract' { Install-WsWheelExtract -Context $Context -Package $Package }
            'gitClone' { Install-WsGitClone -Context $Context -Package $Package }
            'uvPython' { Install-WsUvPython -Context $Context -Package $Package }
            'uvTool' { Install-WsUvTool -Context $Context -Package $Package }
            'npm' { Install-WsNpmPackage -Context $Context -Package $Package }
            'pacman' { Install-WsPacmanPackage -Context $Context -Package $Package }
            'psModule' { Install-WsPsModule -Context $Context -Package $Package }
            'vscodeExtension' { Install-WsVsCodeExtension -Context $Context -Package $Package }
            default { throw "未知 provider：$($Package.provider)" }
        }
    } catch {
        $result.Status = 'Failed'
        $result.Message = $_.Exception.Message
    }
    $result
}

function Invoke-WsPackageGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [object[]]$Packages = @()
    )

    foreach ($package in $Packages) {
        $result = Invoke-WsPackage -Context $Context -Package $package
        $Context.Results.Add($result)
        $level = switch ($result.Status) {
            'Failed' { 'ERROR' }
            'SkippedNoGpu' { 'SKIP' }
            'AlreadyPresent' { 'SKIP' }
            default { 'INFO' }
        }
        $suffix = if ($result.Message) { '：' + $result.Message } else { '' }
        Write-WsLog ("{0} [{1}] {2}{3}" -f $package.name, $package.provider, $result.Status, $suffix) -Level $level -Context $Context
        if ($result.Status -eq 'Failed' -and $package.required) {
            throw "必需组件安装失败：$($package.name)（$($result.Message)）"
        }
        if ($result.Status -eq 'Failed') {
            $Context.Warnings.Add("可选组件安装失败：$($package.name)（$($result.Message)）")
        }
        if ($result.Status -eq 'Installed') {
            Update-WsProcessPath -Context $Context
        }
    }
}
