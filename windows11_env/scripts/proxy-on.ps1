# 按需开启代理，仅用于 github.com 的 HTTPS 访问。
# SSH 22 与 api.github.com 直连可用，不走代理。
# 端口优先取 Windows 系统代理，未启用时回退 data/bootstrap.json。
# 在需要 HTTPS 克隆、下载 GitHub 发布包的终端内执行： . .\scripts\proxy-on.ps1

$repo = Split-Path -Parent $PSScriptRoot
$bootstrap = Get-Content -LiteralPath (Join-Path $repo 'data\bootstrap.json') -Raw | ConvertFrom-Json
Import-Module (Join-Path $repo 'src\WsBootstrap\WsBootstrap.psm1') -Force
$endpoint = Get-WsProxyEndpoint -FallbackHost ([string]$bootstrap.proxy.host) -FallbackPort ([int]$bootstrap.proxy.port)
$noProxy = @($bootstrap.proxy.noProxy) -join ','

$listening = Test-NetConnection -ComputerName $endpoint.Host -Port $endpoint.Port -InformationLevel Quiet -WarningAction SilentlyContinue
if (-not $listening) {
    Write-Warning "代理端口 $($endpoint.Host):$($endpoint.Port)（$($endpoint.Source)）未监听，变量已设置但代理不可用。启动代理客户端或开启系统代理后重试。"
}

$env:HTTP_PROXY = "http://$($endpoint.Host):$($endpoint.Port)"
$env:HTTPS_PROXY = "http://$($endpoint.Host):$($endpoint.Port)"
$env:NO_PROXY = $noProxy

Write-Host "代理来源    = $($endpoint.Source)"
Write-Host "HTTP_PROXY  = $env:HTTP_PROXY"
Write-Host "HTTPS_PROXY = $env:HTTPS_PROXY"
Write-Host "NO_PROXY    = $env:NO_PROXY"
