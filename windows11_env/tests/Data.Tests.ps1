BeforeAll {
    $repo = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $repo 'src\WsBootstrap\WsBootstrap.psm1') -Force
    $script:repo = $repo
    $script:fixture = Join-Path $PSScriptRoot 'fixtures\user.json'
    $script:context = New-WsContext -RepoRoot $repo -DryRun
    $script:context.User = Get-Content -LiteralPath $script:fixture -Raw | ConvertFrom-Json
    $script:context.WorkspaceRoot = 'D:\Workspace'
}

Describe '阶段图' {
    It 'Dev 按依赖顺序包含九个阶段' {
        $plan = Get-WsStagePlan -Profile Dev
        ($plan.Name -join ',') | Should -Be 'Preflight,Base,Mirrors,Toolchain,Environment,Proxy,Optional,Config,Verify'
    }

    It 'System 只包含 Preflight、System、Verify' {
        $plan = Get-WsStagePlan -Profile System
        ($plan.Name -join ',') | Should -Be 'Preflight,System,Verify'
    }

    It 'All 包含十个阶段' {
        $plan = Get-WsStagePlan -Profile All
        @($plan).Count | Should -Be 10
        $plan.Name | Should -Contain 'System'
        $plan.Name | Should -Contain 'Proxy'
        $plan.Name | Should -Contain 'Optional'
    }

    It 'Verify 可单独运行' {
        $plan = Get-WsStagePlan -Profile Dev -Stages Verify
        ($plan.Name -join ',') | Should -Be 'Verify'
    }

    It '指定阶段时自动补齐前置' {
        $plan = Get-WsStagePlan -Profile Dev -Stages Toolchain
        ($plan.Name -join ',') | Should -Be 'Preflight,Base,Mirrors,Toolchain'
    }

    It '未知阶段抛出错误' {
        { Get-WsStagePlan -Profile Dev -Stages NoSuchStage } | Should -Throw '*未知阶段*'
    }

    It '机器级阶段标记正确' {
        $plan = Get-WsStagePlan -Profile All
        ($plan | Where-Object RequiresAdmin).Name | Should -Contain 'Base'
        ($plan | Where-Object RequiresAdmin).Name | Should -Contain 'Environment'
        ($plan | Where-Object Name -EQ 'Toolchain').RequiresAdmin | Should -BeFalse
        ($plan | Where-Object Name -EQ 'Proxy').RequiresAdmin | Should -BeFalse
        ($plan | Where-Object Name -EQ 'Optional').RequiresAdmin | Should -BeTrue
        ($plan | Where-Object Name -EQ 'Verify').RequiresAdmin | Should -BeFalse
    }
}

Describe '研究方向' {
    It '默认只选择 base' {
        $context = New-WsContext -RepoRoot $script:repo
        @($context.Direction).Count | Should -Be 1
        $context.Direction | Should -Contain 'base'
        $ids = @(Get-WsStagePackages -Context $context -Stage 'base').id
        $ids | Should -Contain 'Microsoft.PowerShell'
        $ids | Should -Contain 'Mihomo-Party.Clash-Party'
        $ids | Should -Not -Contain 'ARM-GNU-Toolchain'
        $ids | Should -Not -Contain 'Nvidia.CUDA'
    }

    It 'embedded 追加 ARM 工具链、调试器与 STM32 人工项' {
        $context = New-WsContext -RepoRoot $script:repo -Direction embedded
        $context.Direction | Should -Contain 'base'
        $context.Direction | Should -Contain 'embedded'
        @(Get-WsStagePackages -Context $context -Stage 'base').id | Should -Contain 'ARM-GNU-Toolchain'
        @(Get-WsStagePackages -Context $context -Stage 'toolchain').id | Should -Contain 'pacman-openocd'
        @(Get-WsStagePackages -Context $context -Stage 'toolchain').id | Should -Contain 'Keil-MDK'
        @(Get-WsStagePackages -Context $context -Stage 'proxy').id | Should -Contain 'pyocd'
        @(Get-WsManualItems -Context $context).name | Should -Contain 'STM32CubeMX'
    }

    It 'image 追加 OpenCV、CUDA 与 Nsight，不安装 ARM 工具链' {
        $context = New-WsContext -RepoRoot $script:repo -Direction image
        @(Get-WsStagePackages -Context $context -Stage 'base').id | Should -Contain 'Nvidia.CUDA'
        @(Get-WsStagePackages -Context $context -Stage 'base').id | Should -Not -Contain 'ARM-GNU-Toolchain'
        @(Get-WsStagePackages -Context $context -Stage 'toolchain').id | Should -Contain 'pacman-opencv'
        @(Get-WsManualItems -Context $context).name | Should -Contain 'NVIDIA Nsight Systems'
        @(Get-WsManualItems -Context $context).name | Should -Not -Contain 'STM32CubeMX'
    }

    It '多方向合并' {
        $context = New-WsContext -RepoRoot $script:repo -Direction image, embedded
        @(Get-WsStagePackages -Context $context -Stage 'base').id | Should -Contain 'ARM-GNU-Toolchain'
        @(Get-WsStagePackages -Context $context -Stage 'base').id | Should -Contain 'Nvidia.CUDA'
        @(Get-WsStagePackages -Context $context -Stage 'toolchain').id | Should -Contain 'pacman-opencv'
    }

    It '未知方向被拒绝' {
        { New-WsContext -RepoRoot $script:repo -Direction fpga } | Should -Throw
    }
}

Describe '数据校验' {
    It 'data 下的包、镜像与人工项通过校验' {
        $problems = @(Test-WsData -Context $script:context)
        ($problems -join '；') | Should -Be ''
    }

    It '包 ID 在开发与系统数据中唯一' {
        $ids = @($script:context.DevPackages.packages) + @($script:context.SystemPackages.packages) |
            ForEach-Object { $_.id }
        @($ids).Count | Should -Be @($ids | Sort-Object -Unique).Count
    }

    It 'CUDA 与 Nsight 带 nvidiaGpu 条件' {
        $conditional = @($script:context.DevPackages.packages | Where-Object { $_.PSObject.Properties.Name -contains 'condition' -and $_.condition })
        @($conditional).Count | Should -Be 2
        foreach ($package in $conditional) {
            $package.condition | Should -Be 'nvidiaGpu'
        }
    }

    It '缺少 provider 必需字段时报告问题' {
        $context = New-WsContext -RepoRoot $script:repo -DryRun
        @($context.DevPackages.packages)[0].PSObject.Properties.Remove('packageId')
        ($problems = @(Test-WsData -Context $context)) | Out-Null
        ($problems -join '；') | Should -Match 'packageId'
    }

    It '从镜像地址解析主机' {
        Get-WsUriHost -Uri 'sparse+https://rsproxy.cn/index/' | Should -Be 'rsproxy.cn'
    }

    It 'Maven 镜像只代理 central' {
        $script:context.Mirrors.maven.mirrorOf | Should -Be 'central'
    }
}

Describe '模板渲染' {
    It '全部模板占位符可解析' {
        $values = Get-WsTemplateValues -Context $script:context
        $templates = Get-ChildItem -LiteralPath (Join-Path $script:repo 'data\templates') -File
        @($templates).Count | Should -BeGreaterThan 0
        foreach ($template in $templates) {
            $text = Get-Content -LiteralPath $template.FullName -Raw
            $rendered = Expand-WsTemplateText -Text $text -Values $values
            $rendered | Should -Not -Match '\{\{[A-Z0-9_]+\}\}' -Because $template.Name
        }
    }

    It '未知占位符抛出错误' {
        { Expand-WsTemplateText -Text '{{UNKNOWN_KEY}}' -Values @{ HOME = 'C:\Users\Test' } } |
            Should -Throw '*未知占位符*'
    }

    It 'Claude 配置为合法 JSON 且不含认证令牌' {
        $values = Get-WsTemplateValues -Context $script:context
        $text = Get-Content -LiteralPath (Join-Path $script:repo 'data\templates\claude-settings.json') -Raw
        $rendered = Expand-WsTemplateText -Text $text -Values $values
        $settings = $rendered | ConvertFrom-Json
        $settings.env.ANTHROPIC_BASE_URL | Should -Match '15721'
        $tokenKey = 'ANTHROPIC_' + 'AUTH_TOKEN'
        $settings.env.PSObject.Properties.Name | Should -Not -Contain $tokenKey
        $rendered | Should -Not -Match 'sk-'
    }

    It 'Trae MCP 配置为合法 JSON' {
        $text = Get-Content -LiteralPath (Join-Path $script:repo 'data\templates\trae-mcp.json') -Raw
        $settings = $text | ConvertFrom-Json
        $settings.mcpServers.Playwright.disabled | Should -BeNullOrEmpty
    }

    It 'JSON 字符串值完成转义' {
        ConvertTo-WsJsonString -Value 'C:\Path\With"Quote' | Should -Be 'C:\\Path\\With\"Quote'
    }
}

Describe '工作空间' {
    It 'D 盘存在时使用 D:\Workspace' {
        Resolve-WsWorkspaceRoot -Context $script:context -DriveExists { param($Drive) $true } |
            Should -Be 'D:\Workspace'
    }

    It 'D 盘不存在时回退 C:\Workspace' {
        Resolve-WsWorkspaceRoot -Context $script:context -DriveExists { param($Drive) $false } |
            Should -Be 'C:\Workspace'
    }

    It '显式根目录优先' {
        Resolve-WsWorkspaceRoot -Context $script:context -Override 'E:\Work' -DriveExists { param($Drive) $true } |
            Should -Be 'E:\Work'
    }

    It 'DryRun 不创建目录' {
        $context = New-WsContext -RepoRoot $script:repo -DryRun
        $context.WorkspaceRoot = Join-Path $TestDrive 'Workspace'
        [void](New-WsWorkspace -Context $context)
        Test-Path -LiteralPath $context.WorkspaceRoot | Should -BeFalse
    }
}

Describe 'PATH 与 pnpm store' {
    It '机器级 PATH 不含用户目录' {
        $machine = @($script:context.Bootstrap.path.machineHead) + @($script:context.Bootstrap.path.machineTail)
        ($machine -join ';') | Should -Not -Match '\{home\}'
    }

    It '用户级 PATH 首位是 .local\bin' {
        @($script:context.Bootstrap.path.user)[0] | Should -Be '{home}\.local\bin'
    }

    It 'globalAgents 覆盖 Codex、Claude 与 Trae' {
        $targets = @($script:context.Bootstrap.paths.globalAgents)
        $targets.Count | Should -Be 3
        ($targets -join ';') | Should -Match '\.codex'
        ($targets -join ';') | Should -Match '\.claude'
        ($targets -join ';') | Should -Match '\.trae-cn'
    }

    It 'Windows Terminal 外观配置完整' {
        $terminal = $script:context.Bootstrap.terminal
        $terminal.colorScheme | Should -Be 'Tango Dark'
        $terminal.fontSize | Should -Be 14
        $terminal.opacity | Should -Be 49
        $terminal.useAcrylic | Should -BeTrue
    }

    It '配置盘存在时使用配置的 pnpm store' {
        Resolve-WsPnpmStore -Context $script:context -DriveExists { param($Drive) $true } |
            Should -Be 'C:\Programs\.pnpm-store'
    }

    It 'D 盘不存在时回退到 C:\Workspace' {
        Resolve-WsPnpmStore -Context $script:context -DriveExists { param($Drive) $false } |
            Should -Be 'C:\Workspace\.pnpm-store'
    }
}

Describe '用户配置' {
    It '读取 fixture' {
        $context = New-WsContext -RepoRoot $script:repo -DryRun -UserFile $script:fixture
        $user = Read-WsUserConfig -Context $context
        $user.gitName | Should -Be 'Test User'
        $user.ccsRoutePort | Should -Be 15721
    }

    It '拒绝空姓名与非法邮箱' {
        $user = [pscustomobject]@{
            gitName = ''; gitEmail = 'not-an-email'; writeAiConfig = $false;
            aiProvider = ''; aiModel = ''; ccsRoutePort = 70000
        }
        $problems = @(Test-WsUserConfig -User $user)
        ($problems -join '；') | Should -Match 'gitName'
        ($problems -join '；') | Should -Match 'gitEmail'
        ($problems -join '；') | Should -Match 'ccsRoutePort'
    }

    It '首次询问后写入指定文件' {
        InModuleScope WsBootstrap -Parameters @{ Repo = $script:repo; Directory = $TestDrive } {
            param($Repo, $Directory)
            $path = Join-Path $Directory 'user.json'
            if (Test-Path $path) { Remove-Item $path -Force }
            $script:answers = [System.Collections.Generic.Queue[string]]::new()
            foreach ($answer in @('Prompt User', 'prompt@example.com', 'y', 'ExampleProvider', 'example-model', '15721')) {
                $script:answers.Enqueue($answer)
            }
            Mock Read-Host { $script:answers.Dequeue() }
            $context = New-WsContext -RepoRoot $Repo -UserFile $path
            $context.LogPath = Join-Path $Directory 'prompt.log'
            $user = Read-WsUserConfig -Context $context
            $user.gitName | Should -Be 'Prompt User'
            Test-Path -LiteralPath $path | Should -BeTrue
            $saved = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            $saved.aiProvider | Should -Be 'ExampleProvider'
        }
    }
}
