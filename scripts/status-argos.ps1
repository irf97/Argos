[CmdletBinding()]
param(
  [int]$Port = 4020,
  [string]$HostName = "127.0.0.1"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BaseUrl = "http://${HostName}:$Port"
$StateDir = Join-Path $Root ".argos"

function Get-ListenerPids {
  param([int]$TargetPort)

  netstat -ano |
    Select-String "127\.0\.0\.1:$TargetPort\s+0\.0\.0\.0:0\s+LISTENING" |
    ForEach-Object { ($_ -split "\s+")[-1] } |
    Sort-Object -Unique
}

$listenerPids = @(Get-ListenerPids -TargetPort $Port)
$health = $null
$healthOk = $false
$healthError = $null
$tools = @()
$mcpError = $null

try {
  $health = Invoke-RestMethod -Uri "$BaseUrl/api/health" -TimeoutSec 5
  $healthOk = $health.status -eq "ok"
} catch {
  $healthError = $_.Exception.Message
}

if ($healthOk) {
  try {
    $body = '{"jsonrpc":"2.0","id":"status-tools","method":"tools/list"}'
    $response = Invoke-RestMethod -Method Post -Uri "$BaseUrl/mcp" -ContentType "application/json" -Body $body -TimeoutSec 5
    $tools = @($response.result.tools | ForEach-Object { $_.name })
  } catch {
    $mcpError = $_.Exception.Message
  }
}

$status = [ordered]@{
  base_url = $BaseUrl
  listening = $listenerPids.Count -gt 0
  listener_pids = $listenerPids
  health_ok = $healthOk
  health = $health
  health_error = $healthError
  mcp_tool_count = $tools.Count
  mcp_tools = $tools
  mcp_error = $mcpError
  logs = @{
    stdout = Join-Path $StateDir "argos-4020.out.log"
    stderr = Join-Path $StateDir "argos-4020.err.log"
    stdio_bridge = Join-Path $StateDir "argos-mcp-stdio.log"
  }
}

$status | ConvertTo-Json -Depth 8

if (-not $healthOk) {
  exit 1
}
