@{
    # 脚本面向交互式终端使用，Write-Host 是刻意选择，不是误用
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )
    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.4', '7.5')
        }
    }
}
