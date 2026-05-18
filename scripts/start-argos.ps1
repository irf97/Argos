[CmdletBinding()]
param(
  [int]$Port = 4020,
  [string]$HostName = "127.0.0.1",
  [string]$PublicUrl = $env:ARGOS_PUBLIC_URL,
  [switch]$Foreground
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BaseUrl = "http://${HostName}:$Port"
$StateDir = Join-Path $Root ".argos"
$OutLog = Join-Path $StateDir "argos-4020.out.log"
$ErrLog = Join-Path $StateDir "argos-4020.err.log"

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

function Test-ArgosHealth {
  try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/api/health" -TimeoutSec 3
    return $health.status -eq "ok"
  } catch {
    return $false
  }
}

function Get-ListenerPids {
  param([int]$TargetPort)

  netstat -ano |
    Select-String "127\.0\.0\.1:$TargetPort\s+0\.0\.0\.0:0\s+LISTENING" |
    ForEach-Object { ($_ -split "\s+")[-1] } |
    Sort-Object -Unique
}

if (Test-ArgosHealth) {
  Write-Host "Argos is already running at $BaseUrl"
  & (Join-Path $PSScriptRoot "status-argos.ps1") -Port $Port -HostName $HostName
  exit 0
}

$listenerPids = @(Get-ListenerPids -TargetPort $Port)
if ($listenerPids.Count -gt 0) {
  throw "Port $Port is already listening but Argos health did not respond. Listener PID(s): $($listenerPids -join ', ')"
}

if ($Foreground) {
  Set-Location $Root
  $env:PORT = "$Port"
  $env:ARGOS_URL = $BaseUrl
  if ($PublicUrl) {
    $env:ARGOS_PUBLIC_URL = $PublicUrl
  }
  mix phx.server
  exit $LASTEXITCODE
}

$EscapedRoot = $Root.Replace("'", "''")
$EscapedBaseUrl = $BaseUrl.Replace("'", "''")
$EscapedPublicUrl = if ($PublicUrl) { $PublicUrl.Replace("'", "''") } else { "" }

$Command = @"
Set-Location '$EscapedRoot'
`$env:PORT = '$Port'
`$env:ARGOS_URL = '$EscapedBaseUrl'
"@

if ($EscapedPublicUrl) {
  $Command += "`n`$env:ARGOS_PUBLIC_URL = '$EscapedPublicUrl'"
}

$Command += "`nmix phx.server"

$process = Start-Process `
  -FilePath "powershell" `
  -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $Command) `
  -RedirectStandardOutput $OutLog `
  -RedirectStandardError $ErrLog `
  -WindowStyle Hidden `
  -PassThru

Start-Sleep -Seconds 4

Write-Host "Started Argos launcher PID $($process.Id)"
& (Join-Path $PSScriptRoot "status-argos.ps1") -Port $Port -HostName $HostName
