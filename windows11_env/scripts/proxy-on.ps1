# 按需开启代理，仅用于 github.com 的 HTTPS 访问。
# SSH 22 与 api.github.com 直连可用，不走代理。
# 在需要 HTTPS 克隆、下载 GitHub 发布包的终端内执行： . .\scripts\proxy-on.ps1

$repo = Split-Path -Parent $PSScriptRoot
$bootstrap = Get-Content -LiteralPath (Join-Path $repo 'data\bootstrap.json') -Raw | ConvertFrom-Json
$proxyHost = [string]$bootstrap.proxy.host
$proxyPort = [int]$bootstrap.proxy.port
$noProxy = @($bootstrap.proxy.noProxy) -join ','

$listening = Test-NetConnection -ComputerName $proxyHost -Port $proxyPort -InformationLevel Quiet -WarningAction SilentlyContinue
if (-not $listening) {
    Write-Warning "代理端口 $proxyHost`:$proxyPort 未监听，变量已设置但代理不可用。启动代理客户端后重试。"
}

$env:HTTP_PROXY  = "http://$proxyHost`:$proxyPort"
$env:HTTPS_PROXY = "http://$proxyHost`:$proxyPort"
$env:NO_PROXY    = $noProxy

Write-Host "HTTP_PROXY  = $env:HTTP_PROXY"
Write-Host "HTTPS_PROXY = $env:HTTPS_PROXY"
Write-Host "NO_PROXY    = $env:NO_PROXY"
