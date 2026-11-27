BeforeAll {
    $repo = Split-Path -Parent $PSScriptRoot
    $script:repo = $repo
}

Describe '仓库结构' {
    It 'docs 目录只保留两份文档' {
        $docs = Get-ChildItem -LiteralPath (Join-Path $script:repo 'docs') -Filter '*.md' -File
        @($docs).Count | Should -Be 2
        $docs.Name | Should -Contain '开发环境搭建.md'
        $docs.Name | Should -Contain '系统环境优化.md'
    }

    It 'inventory 与 CLAUDE.md 不再存在' {
        Test-Path -LiteralPath (Join-Path $script:repo 'inventory') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:repo 'CLAUDE.md') | Should -BeFalse
    }

    It '已移除的维护脚本不再存在' {
        foreach ($name in @('cadence.cmd', 'export-installed-software.ps1', 'install-p1-cli.ps1', 'remove-matlab.ps1', 'remove-miniforge.ps1')) {
            Test-Path -LiteralPath (Join-Path $script:repo ('scripts\' + $name)) | Should -BeFalse -Because $name
        }
    }

    It 'README 链接两份文档且不含失效引用' {
        $readme = Get-Content -LiteralPath (Join-Path $script:repo 'README.md') -Raw
        $readme | Should -Match 'docs/开发环境搭建\.md'
        $readme | Should -Match 'docs/系统环境优化\.md'
        $readme | Should -Not -Match 'inventory/'
        $readme | Should -Not -Match 'CLAUDE\.md'
        $readme | Should -Not -Match '工作站AI开发环境方案'
        $readme | Should -Not -Match 'check-agents'
    }

    It 'Justfile 覆盖搭建、验收、回滚与 PowerShell 检查' {
        $text = Get-Content -LiteralPath (Join-Path $script:repo 'Justfile') -Raw
        foreach ($target in @('bootstrap:', 'bootstrap-dry:', 'verify:', 'rollback:', 'doctor:', 'lint-ps:', 'test-ps:')) {
            $text | Should -Match ([regex]::Escape($target)) -Because $target
        }
        $text | Should -Not -Match 'check-agents'
    }
}

Describe '规则文件' {
    It 'AGENTS.md 是唯一规则文件且不含 FPGA、RTL 内容' {
        $text = Get-Content -LiteralPath (Join-Path $script:repo 'AGENTS.md') -Raw
        $text | Should -Not -Match '(?i)FPGA|Vivado|Verilog|SystemVerilog|RTL|Questa'
        $text | Should -Match 'bootstrap\.ps1'
    }
}

Describe '脚本编码' {
    It '所有 .ps1 与 .psm1 使用 UTF-8 BOM' {
        $files = Get-ChildItem -LiteralPath $script:repo -Recurse -File |
            Where-Object { $_.Extension -in @('.ps1', '.psm1') -and $_.FullName -notmatch '[\\/]\.git[\\/]' }
        @($files).Count | Should -BeGreaterThan 0
        foreach ($file in $files) {
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasBom | Should -BeTrue -Because $file.Name
        }
    }

    It '所有 .cmd 保持 ASCII' {
        $files = Get-ChildItem -LiteralPath $script:repo -Recurse -File -Filter '*.cmd'
        foreach ($file in $files) {
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            @($bytes | Where-Object { $_ -gt 0x7F }).Count | Should -Be 0 -Because $file.Name
        }
    }
}

Describe '文档与数据一致性' {
    It '开发 WinGet 包 ID 全部出现在开发环境搭建' {
        $data = Get-Content -LiteralPath (Join-Path $script:repo 'data\packages.dev.json') -Raw | ConvertFrom-Json
        $doc = Get-Content -LiteralPath (Join-Path $script:repo 'docs\开发环境搭建.md') -Raw
        foreach ($package in @($data.packages | Where-Object provider -EQ 'winget')) {
            $doc | Should -Match ([regex]::Escape($package.packageId)) -Because $package.packageId
        }
    }

    It '系统 WinGet 包 ID 全部出现在系统环境优化' {
        $data = Get-Content -LiteralPath (Join-Path $script:repo 'data\packages.system.json') -Raw | ConvertFrom-Json
        $doc = Get-Content -LiteralPath (Join-Path $script:repo 'docs\系统环境优化.md') -Raw
        foreach ($package in @($data.packages | Where-Object provider -EQ 'winget')) {
            $doc | Should -Match ([regex]::Escape($package.packageId)) -Because $package.packageId
        }
    }

    It 'docs 与 AGENTS 只陈述当前事实' {
        $documents = @(Get-ChildItem -LiteralPath (Join-Path $script:repo 'docs') -Filter '*.md' -File)
        $documents += Get-Item -LiteralPath (Join-Path $script:repo 'AGENTS.md')
        $forbidden = @(
            '原稿', '原文档', '已执行', '执行记录', '历史问题', '旧机', '旧值', '旧路径',
            '迁移记录', '本轮', '本次审查', '与方案原稿不一致', '实测', '尚未', '升级目标',
            '本机', '当前机器', '当前工作站'
        )
        foreach ($document in $documents) {
            $text = Get-Content -LiteralPath $document.FullName -Raw
            foreach ($word in $forbidden) {
                $text | Should -Not -Match ([regex]::Escape($word)) -Because "$($document.Name) 不能包含 $word"
            }
        }
    }

    It 'AGENTS 不记录本机内存或线程事实' {
        $text = Get-Content -LiteralPath (Join-Path $script:repo 'AGENTS.md') -Raw
        $text | Should -Not -Match '15\.8|32 GB|28 线程|30 GB'
    }

    It 'manual.json 不写入特定版本或年份' {
        $manual = Get-Content -LiteralPath (Join-Path $script:repo 'data\manual.json') -Raw | ConvertFrom-Json
        foreach ($item in @($manual.items)) {
            $item.name | Should -Not -Match '\d+\.\d+' -Because "$($item.name) 应指向当前发布"
            $item.name | Should -Not -Match '\b20\d{2}\b' -Because "$($item.name) 不应写年份"
            $item.target | Should -Not -Match '\b20\d{2}\b' -Because "$($item.name) 的路径不应写年份"
        }
    }

    It '全局 AGENTS 模板只有 5 条全局要求' {
        $text = Get-Content -LiteralPath (Join-Path $script:repo 'data\templates\global-agents.md') -Raw
        @($text -split "`n" | Where-Object { $_ -match '^\d+\.' }).Count | Should -Be 5
        $text | Should -Not -Match '硬约束|工具链路径|环境搭建'
    }
}

Describe '隐私' {
    It '仓库配置不含个人姓名、个人邮箱或真实令牌' {
        $paths = @(
            (Join-Path $script:repo 'data'),
            (Join-Path $script:repo 'docs'),
            (Join-Path $script:repo 'README.md'),
            (Join-Path $script:repo 'AGENTS.md')
        )
        $files = foreach ($path in $paths) {
            if (Test-Path -LiteralPath $path -PathType Container) {
                Get-ChildItem -LiteralPath $path -Recurse -File -Include '*.json', '*.md', '*.xml', '*.ini', '*.toml', '*.gradle', '*.config', 'npmrc' |
                    Where-Object { $_.Name -ne 'user.json' }
            } else {
                Get-Item -LiteralPath $path
            }
        }
        $namePattern = 'chous' + 'hunn'
        $emailPattern = '@163' + '\.com'
        foreach ($file in $files) {
            $text = Get-Content -LiteralPath $file.FullName -Raw
            $text | Should -Not -Match $namePattern -Because $file.Name
            $text | Should -Not -Match $emailPattern -Because $file.Name
        }
    }

    It 'Claude 模板不写入认证令牌' {
        $text = Get-Content -LiteralPath (Join-Path $script:repo 'data\templates\claude-settings.json') -Raw
        $text | Should -Not -Match ('ANTHROPIC_' + 'AUTH_TOKEN')
    }

    It '用户配置示例只含占位符' {
        $example = Get-Content -LiteralPath (Join-Path $script:repo 'data\user.example.json') -Raw | ConvertFrom-Json
        $example.gitName | Should -Match '^<.+>$'
        $example.gitEmail | Should -Match '^<.+>$'
        $example.aiProvider | Should -Match '^<.+>$'
        $example.aiModel | Should -Match '^<.+>$'
    }

    It 'data/user.json 已 gitignore' {
        $ignore = Get-Content -LiteralPath (Join-Path $script:repo '.gitignore') -Raw
        $ignore | Should -Match '(?m)^data/user\.json$'
    }
}
