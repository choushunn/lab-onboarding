BeforeAll {
    $script:repo = Split-Path -Parent $PSScriptRoot
    . (Join-Path $script:repo 'scripts\sync-skills.ps1')
}

Describe 'Skills 清单' {
    It 'base 始终保留，方向可叠加' {
        $data = [pscustomobject]@{
            skills = @(
                [pscustomobject]@{ package = 'owner/repo@image-demo'; name = 'image-demo'; directions = @('image') },
                [pscustomobject]@{ package = 'owner/repo@base-demo'; name = 'base-demo'; directions = @() }
            )
        }
        $base = @(Get-SelectedSkills -Data $data -Direction @('base')).name
        $base | Should -Contain 'base-demo'
        $base | Should -Not -Contain 'image-demo'
        @(Get-SelectedSkills -Data $data -Direction @('image')).name | Should -Contain 'image-demo'
    }

    It '拒绝非法包名与未知方向' {
        $data = [pscustomobject]@{
            schemaVersion = 1
            skills        = @(
                [pscustomobject]@{ package = 'invalid'; name = 'demo'; directions = @('fpga') }
            )
        }
        $problems = @(Get-SkillDataProblems -Data $data -KnownDirections @('base', 'image', 'embedded'))
        $problems.Count | Should -BeGreaterThan 1
    }

    It '拒绝 name 与包后缀不一致' {
        $data = [pscustomobject]@{
            schemaVersion = 1
            skills        = @(
                [pscustomobject]@{ package = 'owner/repo@other'; name = 'demo'; directions = @('base') }
            )
        }
        @(Get-SkillDataProblems -Data $data -KnownDirections @('base')).Count | Should -BeGreaterThan 0
    }

    It '仓库清单通过校验并覆盖开发与文档技能' {
        $data = Get-Content -LiteralPath (Join-Path $script:repo 'data\skills.json') -Raw | ConvertFrom-Json
        $directions = @((Get-Content -LiteralPath (Join-Path $script:repo 'data\directions.json') -Raw | ConvertFrom-Json).directions.id)
        @(Get-SkillDataProblems -Data $data -KnownDirections $directions).Count | Should -Be 0
        $data.skills.Count | Should -BeGreaterThan 8
        foreach ($name in @('systematic-debugging', 'brainstorming', 'pdf', 'docx', 'xlsx', 'pptx', 'find-skills', 'skill-creator')) {
            $data.skills.name | Should -Contain $name
        }
    }
}

Describe 'Skills 同步' {
    BeforeEach {
        $script:fixture = Join-Path $TestDrive ('skills-{0}.json' -f ([guid]::NewGuid()))
        $data = [pscustomobject]@{
            schemaVersion = 1
            skills        = @(
                [pscustomobject]@{ package = 'owner/repo@demo'; name = 'demo'; directions = @('base') }
            )
        }
        $data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:fixture -Encoding utf8
        $script:root = Join-Path $TestDrive ('skills-root-{0}' -f ([guid]::NewGuid()))
    }

    It 'DryRun 不调用 CLI' {
        Mock Invoke-SkillCli { throw '不应调用' }
        Invoke-SkillsSync -DataFile $script:fixture -SkillsRoot $script:root -DryRun | Should -Be 0
        Should -Invoke Invoke-SkillCli -Times 0
    }

    It '已安装时跳过' {
        New-Item -ItemType Directory -Path (Join-Path $script:root 'demo') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:root 'demo\SKILL.md') -Value '---'
        Mock Invoke-SkillCli { throw '不应调用' }
        Invoke-SkillsSync -DataFile $script:fixture -SkillsRoot $script:root | Should -Be 0
        Should -Invoke Invoke-SkillCli -Times 0
    }

    It '缺失时调用 add 并校验 SKILL.md' {
        $script:installed = $false
        Mock Test-SkillInstalled { $script:installed }
        Mock Invoke-SkillCli { $script:installed = $true; @() }
        Invoke-SkillsSync -DataFile $script:fixture -SkillsRoot $script:root | Should -Be 0
        Should -Invoke Invoke-SkillCli -Times 1 -ParameterFilter { $Arguments -contains 'add' -and $Arguments -contains 'owner/repo' -and $Arguments -contains '-s' -and $Arguments -contains 'demo' }
    }

    It 'Remove 只处理清单内已安装项' {
        New-Item -ItemType Directory -Path (Join-Path $script:root 'demo') -Force | Out-Null
        Mock Invoke-SkillCli { @() }
        Invoke-SkillsSync -DataFile $script:fixture -SkillsRoot $script:root -Remove | Should -Be 0
        Should -Invoke Invoke-SkillCli -Times 1 -ParameterFilter { $Arguments -contains 'remove' -and $Arguments -contains 'demo' }
    }
}
