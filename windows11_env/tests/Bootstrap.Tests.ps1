BeforeAll {
    $repo = Split-Path -Parent $PSScriptRoot
    $script:repo = $repo
    $script:bootstrap = Join-Path $repo 'bootstrap.ps1'
    $script:fixture = Join-Path $PSScriptRoot 'fixtures\user.json'
    $script:pwsh = (Get-Command 'pwsh').Source
}

Describe '入口集成' {
    It 'DryRun 退出码 0 并输出阶段计划与人工项' {
        $runId = 'pester-dryrun'
        $output = & $script:pwsh -NoProfile -ExecutionPolicy Bypass -File $script:bootstrap `
            -Profile All -DryRun -NoElevate -UserFile $script:fixture -RunId $runId 2>&1
        $code = $LASTEXITCODE
        $text = $output | Out-String
        $code | Should -Be 0
        $text | Should -Match '阶段计划'
        $text | Should -Match '人工项'
        $text | Should -Match '退出码：0'
        Remove-Item -LiteralPath (Join-Path $script:repo "logs\runs\$runId") -Recurse -Force -ErrorAction SilentlyContinue
    }

    It '非 ASCII 用户目录在提权前退出 2' {
        $originalProfile = $env:USERPROFILE
        $originalName = $env:USERNAME
        $runId = 'pester-ascii-guard'
        try {
            $env:USERPROFILE = 'C:\Users\测试'
            $env:USERNAME = '测试'
            $output = & $script:pwsh -NoProfile -ExecutionPolicy Bypass -File $script:bootstrap `
                -DryRun -NoElevate -UserFile $script:fixture -RunId $runId 2>&1
            $code = $LASTEXITCODE
        } finally {
            $env:USERPROFILE = $originalProfile
            $env:USERNAME = $originalName
        }
        $code | Should -Be 2
        ($output | Out-String) | Should -Match '纯 ASCII'
        Test-Path -LiteralPath (Join-Path $script:repo "logs\runs\$runId") | Should -BeFalse
    }
}
