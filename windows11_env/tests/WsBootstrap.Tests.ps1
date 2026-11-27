BeforeAll {
    $repo = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $repo 'src\WsBootstrap\WsBootstrap.psm1') -Force
    $script:repo = $repo
    $script:zipSource = Join-Path $TestDrive 'zip-src\apache-maven-3.9.12'
    $script:zipFixture = Join-Path $TestDrive 'maven.zip'
    $script:wheelFixture = Join-Path $TestDrive 'uv-wheel.zip'
    New-Item -ItemType Directory -Path (Join-Path $script:zipSource 'bin') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:zipSource 'bin\mvn.cmd') -Value '@echo off'
    Compress-Archive -Path $script:zipSource -DestinationPath $script:zipFixture -Force

    $wheelSource = Join-Path $TestDrive 'wheel-src'
    New-Item -ItemType Directory -Path $wheelSource -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $wheelSource 'uv.exe') -Value 'stub'
    Compress-Archive -Path (Join-Path $wheelSource 'uv.exe') -DestinationPath $script:wheelFixture -Force
    $global:WsWheelFixture = $script:wheelFixture
}

Describe '配置写入' {
    BeforeEach {
        $script:context = New-WsContext -RepoRoot $script:repo
        $script:context.LogPath = Join-Path $TestDrive 'config.log'
        $script:context.SummaryPath = Join-Path $TestDrive 'summary.json'
        $script:context.ManifestPath = Join-Path $TestDrive 'manifest.json'
        $script:context.BackupDir = Join-Path $TestDrive 'backup'
        $script:context.Home = Join-Path $TestDrive 'home'
        $script:context.AppData = Join-Path $TestDrive 'appdata'
    }

    It '缺失文件写入并记录 manifest' {
        $path = Join-Path $TestDrive 'new\pip.ini'
        $status = Write-WsManagedFile -Context $script:context -Path $path -Content "registry=example`n"
        $status | Should -Be 'Written'
        (Get-Content -LiteralPath $path -Raw).Trim() | Should -Be 'registry=example'
        Test-Path -LiteralPath $script:context.ManifestPath | Should -BeTrue
        (Get-Content -LiteralPath $script:context.ManifestPath -Raw | ConvertFrom-Json).entries.Count | Should -Be 1
    }

    It '内容一致时跳过' {
        $path = Join-Path $TestDrive 'same.ini'
        [void](Write-WsManagedFile -Context $script:context -Path $path -Content "a=1`n")
        Write-WsManagedFile -Context $script:context -Path $path -Content "a=1`n" | Should -Be 'Unchanged'
    }

    It '内容不同时备份且不覆盖' {
        $path = Join-Path $TestDrive 'conflict.ini'
        $script:context.ManifestPath = Join-Path $TestDrive 'conflict-manifest.json'
        Set-Content -LiteralPath $path -Value 'original'
        $status = Write-WsManagedFile -Context $script:context -Path $path -Content 'replacement'
        $status | Should -Be 'BackupSkipped'
        (Get-Content -LiteralPath $path -Raw).Trim() | Should -Be 'original'
        @(Get-ChildItem -LiteralPath $script:context.BackupDir -File).Count | Should -Be 1
        Test-Path -LiteralPath $script:context.ManifestPath | Should -BeFalse
    }

    It 'ForceConfig 覆盖并保留备份' {
        $path = Join-Path $TestDrive 'force.ini'
        Set-Content -LiteralPath $path -Value 'original'
        $script:context.ForceConfig = $true
        Write-WsManagedFile -Context $script:context -Path $path -Content 'replacement' | Should -Be 'Written'
        (Get-Content -LiteralPath $path -Raw).Trim() | Should -Be 'replacement'
        @(Get-ChildItem -LiteralPath $script:context.BackupDir -File | Where-Object { $_.Name -like '*force.ini*' }).Count | Should -Be 1
    }

    It 'manifest 记录写入前后哈希' {
        $path = Join-Path $TestDrive 'hashed.ini'
        [void](Write-WsManagedFile -Context $script:context -Path $path -Content "a=1`n")
        $entry = @((Get-Content -LiteralPath $script:context.ManifestPath -Raw | ConvertFrom-Json).entries)[0]
        $entry.BeforeHash | Should -Be ''
        $entry.AfterHash | Should -Be (Get-WsFileHash -Path $path)
    }

    It '写入 Codex、Claude 与 Trae 的全局规则且只含 5 条' {
        $script:context.Home = Join-Path $TestDrive 'agents-home'
        $paths = @(
            (Join-Path $script:context.Home '.codex\AGENTS.md'),
            (Join-Path $script:context.Home '.claude\CLAUDE.md'),
            (Join-Path $script:context.Home '.trae-cn\user_rules\rule-global.md')
        )
        Set-WsGlobalAgents -Context $script:context | Out-Null
        foreach ($path in $paths) {
            Test-Path -LiteralPath $path | Should -BeTrue -Because $path
            $text = Get-Content -LiteralPath $path -Raw
            @($text -split "`n" | Where-Object { $_ -match '^\d+\.' }).Count | Should -Be 5
            $text | Should -Not -Match '硬约束|工具链路径'
        }
        Set-WsGlobalAgents -Context $script:context | Out-Null
        $expected = Get-Content -LiteralPath $paths[0] -Raw
        foreach ($path in $paths) {
            (Get-Content -LiteralPath $path -Raw) | Should -Be $expected
        }
    }

    It '同目录已有等价规则文件时不重复写入' {
        $testHome = Join-Path $TestDrive 'agents-dedupe'
        $script:context.Home = $testHome
        $rulesDir = Join-Path $testHome '.trae-cn\user_rules'
        New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null
        $existing = "1.所有项目必须使用git进行管理`n2.所有项目必须添加README`n3.git提交使用Conventional Commits 标准`n4.所有项目在实施前必须确定使用哪些skills`n5.所有文档不允许使用防御性写作"
        Set-Content -LiteralPath (Join-Path $rulesDir 'rule-existing.md') -Value $existing
        Set-WsGlobalAgents -Context $script:context | Out-Null
        Test-Path -LiteralPath (Join-Path $rulesDir 'rule-global.md') | Should -BeFalse
    }

    It '合并 Windows Terminal 外观并保留已有 profile' {
        $path = Join-Path $TestDrive 'terminal-settings.json'
        @{
            profiles = @{
                defaults = @{ opacity = 90; font = @{ size = 9; face = 'TestFont' } }
                list     = @(@{ name = 'PowerShell' })
            }
            scheme   = 'keep'
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
        Set-WsTerminalAppearance -Context $script:context -Path $path
        $result = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $result.profiles.defaults.opacity | Should -Be 49
        $result.profiles.defaults.font.size | Should -Be 14
        $result.profiles.defaults.font.face | Should -Be 'TestFont'
        $result.profiles.list[0].name | Should -Be 'PowerShell'
        $result.scheme | Should -Be 'keep'
    }
}

Describe 'PATH 规划' {
    It '受管项去重并放到头尾' {
        $current = 'C:\A;C:\Programs\msys64\ucrt64\bin;C:\B'
        $planned = Get-WsPlannedPath -Current $current -Head @('C:\Users\Test\.local\bin') -Tail @('C:\Programs\msys64\ucrt64\bin')
        $planned | Should -Be 'C:\Users\Test\.local\bin;C:\A;C:\B;C:\Programs\msys64\ucrt64\bin'
    }

    It '二次规划结果不变' {
        $head = @('C:\Users\Test\.local\bin')
        $tail = @('C:\Programs\msys64\ucrt64\bin')
        $first = Get-WsPlannedPath -Current 'C:\A;C:\B' -Head $head -Tail $tail
        $second = Get-WsPlannedPath -Current $first -Head $head -Tail $tail
        $second | Should -Be $first
    }

    It '未受管项与长路径完整保留' {
        $long = 'C:\' + ('x' * 3000)
        $planned = Get-WsPlannedPath -Current "C:\A;$long" -Head @('C:\Head') -Tail @('C:\Tail')
        $planned | Should -Match ([regex]::Escape($long))
        ($planned -split ';')[0] | Should -Be 'C:\Head'
        ($planned -split ';')[-1] | Should -Be 'C:\Tail'
    }
}

Describe 'pacman 镜像' {
    It '在每个仓库段前插入受管 Server 行且重复执行不变' {
        $context = New-WsContext -RepoRoot $script:repo
        $context.LogPath = Join-Path $TestDrive 'pacman.log'
        $context.ManifestPath = Join-Path $TestDrive 'pacman-manifest.json'
        $context.BackupDir = Join-Path $TestDrive 'pacman-backup'
        $path = Join-Path $TestDrive 'pacman.conf'
        @(
            '[options]',
            'Architecture = auto',
            '',
            '[ucrt64]',
            'Include = /etc/pacman.d/mirrorlist',
            '',
            '[mingw64]',
            'Include = /etc/pacman.d/mirrorlist',
            '',
            '[msys]',
            'Include = /etc/pacman.d/mirrorlist',
            '',
            '[clang64]',
            'Include = /etc/pacman.d/mirrorlist'
        ) | Set-Content -LiteralPath $path

        Set-WsPacmanMirrors -Context $context -Path $path | Should -Be 'Written'
        $first = Get-Content -LiteralPath $path -Raw
        $first | Should -Match '\[ucrt64\][\s\S]*Server = https://mirrors\.aliyun\.com/msys2/mingw/ucrt64'
        $first | Should -Match '\[mingw64\][\s\S]*Server = https://mirrors\.aliyun\.com/msys2/mingw/mingw64'
        $first | Should -Match '\[msys\][\s\S]*Server = https://mirrors\.aliyun\.com/msys2/msys/x86_64'
        $first | Should -Match '\[clang64\][\s\S]*Server = https://mirrors\.aliyun\.com/msys2/mingw/clang64'
        $first | Should -Not -Match 'Include = /etc/pacman\.d/mirrorlist'
        Set-WsPacmanMirrors -Context $context -Path $path | Should -Be 'Unchanged'
        (Get-Content -LiteralPath $path -Raw) | Should -Be $first
    }

    It 'pacman.conf 缺失时返回 Missing' {
        $context = New-WsContext -RepoRoot $script:repo -DryRun
        Set-WsPacmanMirrors -Context $context -Path (Join-Path $TestDrive 'missing-pacman.conf') | Should -Be 'Missing'
    }
}

Describe '系统设置' {
    It '默认不添加 Defender 排除项' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'system-default.log'
            Mock Set-WsDefenderExclusions { @() }
            Mock Set-WsRegistryValue { 'Unchanged' }
            Set-WsSystemSettings -Context $context | Out-Null
            Should -Invoke Set-WsDefenderExclusions -Times 0
        }
    }

    It 'EnableDevExclusions 开启后添加 Defender 排除项' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $context = New-WsContext -RepoRoot $Repo -EnableDevExclusions
            $context.LogPath = Join-Path $Directory 'system-enable.log'
            Mock Set-WsDefenderExclusions { @() }
            Mock Set-WsRegistryValue { 'Unchanged' }
            Set-WsSystemSettings -Context $context | Out-Null
            Should -Invoke Set-WsDefenderExclusions -Times 1
        }
    }
}

Describe '回滚' {
    It '按 manifest 逆序处理' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'rollback.log'
            $global:WsRestoreOrder = [System.Collections.Generic.List[string]]::new()
            Mock Restore-WsFileChange { $global:WsRestoreOrder.Add($Entry.Path) }
            $manifest = @(
                [pscustomobject]@{ Kind = 'File'; Path = 'a' },
                [pscustomobject]@{ Kind = 'File'; Path = 'b' },
                [pscustomobject]@{ Kind = 'File'; Path = 'c' }
            )
            Invoke-WsRollback -Context $context -Manifest $manifest
            ($global:WsRestoreOrder -join ',') | Should -Be 'c,b,a'
        }
    }

    It '删除本次新建文件并还原覆盖前内容' {
        $context = New-WsContext -RepoRoot $script:repo
        $context.LogPath = Join-Path $TestDrive 'rollback-files.log'
        $created = Join-Path $TestDrive 'created.txt'
        Set-Content -LiteralPath $created -Value 'new'
        $target = Join-Path $TestDrive 'target.txt'
        Set-Content -LiteralPath $target -Value 'current'
        $backup = Join-Path $TestDrive 'target.bak'
        Set-Content -LiteralPath $backup -Value 'original'
        $manifest = @(
            [pscustomobject]@{ Kind = 'File'; Path = $created; Existed = $false; BackupPath = '' },
            [pscustomobject]@{ Kind = 'File'; Path = $target; Existed = $true; BackupPath = $backup }
        )
        Invoke-WsRollback -Context $context -Manifest $manifest
        Test-Path -LiteralPath $created | Should -BeFalse
        (Get-Content -LiteralPath $target -Raw).Trim() | Should -Be 'original'
    }

    It '哈希未被修改时按备份还原' {
        $context = New-WsContext -RepoRoot $script:repo
        $context.LogPath = Join-Path $TestDrive 'rollback-hash-ok.log'
        $target = Join-Path $TestDrive 'hash-ok.txt'
        Set-Content -LiteralPath $target -Value 'written'
        $backup = Join-Path $TestDrive 'hash-ok.bak'
        Set-Content -LiteralPath $backup -Value 'original'
        $manifest = @(
            [pscustomobject]@{
                Kind = 'File'; Path = $target; Existed = $true; BackupPath = $backup;
                BeforeHash = ''; AfterHash = (Get-WsFileHash -Path $target)
            }
        )
        Invoke-WsRollback -Context $context -Manifest $manifest
        (Get-Content -LiteralPath $target -Raw).Trim() | Should -Be 'original'
    }

    It '运行后被修改的文件保留现状并报告冲突' {
        $context = New-WsContext -RepoRoot $script:repo
        $context.LogPath = Join-Path $TestDrive 'rollback-hash-conflict.log'
        $target = Join-Path $TestDrive 'hash-conflict.txt'
        Set-Content -LiteralPath $target -Value 'written'
        $backup = Join-Path $TestDrive 'hash-conflict.bak'
        Set-Content -LiteralPath $backup -Value 'original'
        $manifest = @(
            [pscustomobject]@{
                Kind = 'File'; Path = $target; Existed = $true; BackupPath = $backup;
                BeforeHash = ''; AfterHash = (Get-WsFileHash -Path $target)
            }
        )
        Set-Content -LiteralPath $target -Value 'user-edit'
        Invoke-WsRollback -Context $context -Manifest $manifest
        (Get-Content -LiteralPath $target -Raw).Trim() | Should -Be 'user-edit'
        (Get-Content -LiteralPath $context.LogPath -Raw) | Should -Match '跳过回滚'
        (Get-Content -LiteralPath $context.LogPath -Raw) | Should -Match '冲突跳过 1 项'
    }
}

Describe '验收' {
    It '验收结束写入环境报告' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'verify.log'
            $context.RunDirectory = Join-Path $Directory 'verify-run'
            Mock Test-WsEnvironment {
                [pscustomobject]@{
                    Failures = @()
                    Warnings = @()
                    Versions = @([pscustomobject]@{ Name = 'git'; Version = 'git version 2.0'; Path = 'C:\git.exe' })
                }
            }
            Invoke-WsVerifyStage -Context $context
            $reportPath = Join-Path $context.RunDirectory 'environment-report.json'
            Test-Path -LiteralPath $reportPath | Should -BeTrue
            $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
            $report.runId | Should -Be $context.RunId
            $report.tools[0].Name | Should -Be 'git'
            $report.platform.psVersion | Should -Not -BeNullOrEmpty
        }
    }
}

Describe '包安装' {
    BeforeEach {
        $global:WsTestProcess = $null
        $global:WsTestProcessCount = 0
    }

    It 'winget 已安装时跳过' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            Mock Test-WsWingetInstalled { $true }
            Mock Invoke-WsProcess { throw '不应调用安装' }
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'winget.log'
            $package = [pscustomobject]@{ id = 'x'; name = 'X'; provider = 'winget'; packageId = 'Vendor.X'; required = $true }
            Install-WsWingetPackage -Context $context -Package $package | Should -Be 'AlreadyPresent'
        }
    }

    It 'winget 安装参数包含静默与协议参数' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            Mock Test-WsWingetInstalled { $false }
            Mock Invoke-WsProcess {
                param($FilePath, $Arguments)
                $global:WsTestProcess = @($Arguments)
                [pscustomobject]@{ ExitCode = 0; Output = @() }
            }
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'winget-args.log'
            $package = [pscustomobject]@{ id = 'x'; name = 'X'; provider = 'winget'; packageId = 'Vendor.X'; required = $true }
            Install-WsWingetPackage -Context $context -Package $package | Should -Be 'Installed'
            $global:WsTestProcess | Should -Contain '--silent'
            $global:WsTestProcess | Should -Contain '--accept-source-agreements'
            $global:WsTestProcess | Should -Contain '--accept-package-agreements'
            $global:WsTestProcess | Should -Contain '-e'
        }
    }

    It 'DryRun 不调用安装命令' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            Mock Invoke-WsProcess { throw 'DryRun 不应调用' }
            $context = New-WsContext -RepoRoot $Repo -DryRun
            $context.LogPath = Join-Path $Directory 'dryrun.log'
            $package = [pscustomobject]@{ id = 'x'; name = 'X'; provider = 'winget'; packageId = 'Vendor.X'; required = $true }
            $result = Invoke-WsPackage -Context $context -Package $package
            $result.Status | Should -Be 'Planned'
        }
    }

    It '必需包失败时抛出，可选包失败继续' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            Mock Install-WsNpmPackage { throw 'boom' }
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'failure.log'
            $required = [pscustomobject]@{ id = 'a'; name = 'A'; provider = 'npm'; packageId = 'a'; required = $true }
            { Invoke-WsPackageGroup -Context $context -Packages @($required) } | Should -Throw '*必需组件*'

            $optional = @(
                [pscustomobject]@{ id = 'b'; name = 'B'; provider = 'npm'; packageId = 'b'; required = $false },
                [pscustomobject]@{ id = 'c'; name = 'C'; provider = 'npm'; packageId = 'c'; required = $false }
            )
            { Invoke-WsPackageGroup -Context $context -Packages $optional } | Should -Not -Throw
            @($context.Results | Where-Object Status -EQ 'Failed').Count | Should -Be 3
        }
    }

    It 'zipDownload 下载解压到目标并跳过已存在' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive; Zip = $script:zipFixture } {
            param($Repo, $Directory, $Zip)
            Mock Invoke-WsDownload {
                param($Uri, $OutFile)
                Copy-Item -LiteralPath $Zip -Destination $OutFile -Force
            }
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'zip.log'
            $target = Join-Path $Directory 'Programs\apache-maven-3.9.12'
            $package = [pscustomobject]@{
                id = 'Maven'; name = 'Maven'; provider = 'zipDownload'; required = $true;
                urls = @('https://example.invalid/maven.zip'); target = $target
            }
            Install-WsZipDownload -Context $context -Package $package | Should -Be 'Installed'
            Test-Path -LiteralPath (Join-Path $target 'bin\mvn.cmd') | Should -BeTrue
            Install-WsZipDownload -Context $context -Package $package | Should -Be 'AlreadyPresent'
        }
    }

    It 'fileDownload 下载到目标并跳过已存在' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            Mock Invoke-WsDownload {
                param($Uri, $OutFile)
                Set-Content -LiteralPath $OutFile -Value 'x'
            }
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'file-download.log'
            $target = Join-Path $Directory 'installers\mdk.exe'
            $package = [pscustomobject]@{
                id = 'Keil-MDK'; name = 'Keil MDK'; urls = @('https://example.invalid/mdk.exe'); target = $target
            }
            Install-WsFileDownload -Context $context -Package $package | Should -Be 'Downloaded'
            Test-Path -LiteralPath $target | Should -BeTrue
            Install-WsFileDownload -Context $context -Package $package | Should -Be 'AlreadyPresent'
        }
    }

    It 'fileDownload 检测到已安装时跳过下载' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $existing = Join-Path $Directory 'Keil\UV4\UV4.exe'
            New-Item -ItemType Directory -Path (Split-Path $existing) -Force | Out-Null
            Set-Content -LiteralPath $existing -Value 'x'
            Mock Invoke-WsDownload { throw '不应下载' }
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'file-download-skip.log'
            $package = [pscustomobject]@{
                id = 'Keil-MDK'; name = 'Keil MDK'; urls = @('https://example.invalid/mdk.exe'); target = (Join-Path $Directory 'installers\mdk.exe');
                verifyPaths = @($existing)
            }
            Install-WsFileDownload -Context $context -Package $package | Should -Be 'AlreadyPresent'
        }
    }

    It 'gitClone 目标已存在时跳过' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $target = Join-Path $Directory 'vcpkg'
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            $exe = Join-Path $target 'vcpkg.exe'
            Set-Content -LiteralPath $exe -Value 'x'
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'git-clone.log'
            $package = [pscustomobject]@{
                id = 'vcpkg'; repo = 'https://example.invalid/vcpkg.git'; target = $target; verifyPaths = @($exe); bootstrap = ''
            }
            Mock Invoke-WsProcess { throw '不应调用' }
            Install-WsGitClone -Context $context -Package $package | Should -Be 'AlreadyPresent'
        }
    }

    It 'exeInstaller 目标存在时跳过，缺失时执行安装器' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'exe.log'
            $target = Join-Path $Directory 'msys2'
            $package = [pscustomobject]@{
                id = 'MSYS2'; name = 'MSYS2'; provider = 'exeInstaller'; required = $true;
                urls = @('https://example.invalid/msys2.exe'); args = @('in', '--confirm-command'); target = $target
            }
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Mock Invoke-WsDownload { throw '不应下载' }
            Install-WsExeInstaller -Context $context -Package $package | Should -Be 'AlreadyPresent'

            Remove-Item -LiteralPath $target -Recurse -Force
            Mock Invoke-WsDownload {
                param($Uri, $OutFile)
                Set-Content -LiteralPath $OutFile -Value 'stub'
            }
            Mock Invoke-WsProcess {
                param($FilePath, $Arguments)
                $global:WsTestProcessCount++
                $global:WsTestProcess = @($Arguments)
                [pscustomobject]@{ ExitCode = 0; Output = @() }
            }
            Install-WsExeInstaller -Context $context -Package $package | Should -Be 'Installed'
            $global:WsTestProcessCount | Should -Be 1
            $global:WsTestProcess | Should -Contain '--confirm-command'
        }
    }

    It 'wheelExtract 解压出 uv.exe' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            Mock Get-WsWheelUrl { 'https://example.invalid/uv-0.11.2-py3-none-win_amd64.whl' }
            Mock Invoke-WsDownload {
                param($Uri, $OutFile)
                Copy-Item -LiteralPath $global:WsWheelFixture -Destination $OutFile -Force
            }
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'wheel.log'
            $target = Join-Path $Directory 'bin'
            $package = [pscustomobject]@{
                id = 'uv'; name = 'uv'; provider = 'wheelExtract'; required = $true;
                indexUrl = 'https://example.invalid/simple/uv/';
                wheelPattern = 'uv-*-py3-none-win_amd64.whl';
                files = @('uv.exe'); target = $target
            }
            Install-WsWheelExtract -Context $context -Package $package | Should -Be 'Installed'
            Test-Path -LiteralPath (Join-Path $target 'uv.exe') | Should -BeTrue
        }
    }

    It 'uv python 需要 7890 代理' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'uvpython.log'
            $package = [pscustomobject]@{ id = 'python-3.12'; name = 'CPython'; provider = 'uvPython'; required = $true; version = '3.12' }
            Mock Invoke-WsProcess { [pscustomobject]@{ ExitCode = 0; Output = @() } }
            Mock Test-WsPortListening { $false }
            { Install-WsUvPython -Context $context -Package $package } | Should -Throw '*proxy-on*'

            Mock Test-WsPortListening { $true }
            Install-WsUvPython -Context $context -Package $package | Should -Be 'Installed'
        }
    }
}

Describe '版本选择' {
    It 'JDK 按数值选择最高版本而不是字典序' {
        $root = Join-Path $TestDrive 'java'
        foreach ($name in @('jdk-8', 'jdk-21')) {
            New-Item -ItemType Directory -Path (Join-Path $root $name) -Force | Out-Null
        }
        Get-WsJdkHome -Root $root | Should -Be (Join-Path $root 'jdk-21')
    }

    It 'CUDA 按数值选择最高版本而不是字典序' {
        $root = Join-Path $TestDrive 'cuda'
        foreach ($name in @('v9.0', 'v12.9')) {
            New-Item -ItemType Directory -Path (Join-Path $root $name) -Force | Out-Null
        }
        Get-WsCudaHome -Root $root | Should -Be (Join-Path $root 'v12.9')
    }
}

Describe 'Optional 阶段' {
    It '执行 optional 阶段的包' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'optional.log'
            Mock Invoke-WsPackageGroup { }
            Mock Update-WsProcessPath { }
            Invoke-WsOptionalStage -Context $context
            Should -Invoke Invoke-WsPackageGroup -Times 1 -ParameterFilter { @($Packages).Count -eq 4 }
        }
    }
}

Describe 'pacman 密钥环' {
    It '未初始化时执行 init 与 populate' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $bash = Join-Path $Directory 'msys2\usr\bin\bash.exe'
            New-Item -ItemType Directory -Path (Split-Path $bash) -Force | Out-Null
            Set-Content -LiteralPath $bash -Value 'x'
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'pacman-key.log'
            Mock Invoke-WsProcess {
                param($FilePath, $Arguments)
                $code = if (($Arguments -join ' ') -like '*--init*') { 0 } else { 1 }
                [pscustomobject]@{ ExitCode = $code; StdOut = ''; StdErr = '' }
            }
            Initialize-WsPacman -Context $context -BashPath $bash | Should -Be 'Initialized'
            Should -Invoke Invoke-WsProcess -Times 1 -ParameterFilter { ($Arguments -join ' ') -like '*--init*' }
        }
    }

    It '已初始化时跳过 init' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $bash = Join-Path $Directory 'msys2-ready\usr\bin\bash.exe'
            New-Item -ItemType Directory -Path (Split-Path $bash) -Force | Out-Null
            Set-Content -LiteralPath $bash -Value 'x'
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'pacman-key-ready.log'
            Mock Invoke-WsProcess { [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' } }
            Initialize-WsPacman -Context $context -BashPath $bash | Should -Be 'Ready'
            Should -Invoke Invoke-WsProcess -Times 0 -ParameterFilter { ($Arguments -join ' ') -like '*--init*' }
        }
    }
}

Describe 'Proxy 阶段' {
    It '代理端口未监听时跳过且不安装软件' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'proxy-skip.log'
            Mock Test-WsPortListening { $false }
            Mock Invoke-WsPackageGroup { }
            Invoke-WsProxyStage -Context $context
            Should -Invoke Invoke-WsPackageGroup -Times 0
        }
    }

    It '代理可用时安装 proxy 阶段的包' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $context = New-WsContext -RepoRoot $Repo
            $context.LogPath = Join-Path $Directory 'proxy-run.log'
            Mock Test-WsPortListening { $true }
            Mock Invoke-WsPackageGroup { }
            Mock Update-WsProcessPath { }
            Invoke-WsProxyStage -Context $context
            Should -Invoke Invoke-WsPackageGroup -Times 1
        }
    }
}
