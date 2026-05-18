[CmdletBinding()]
param(
  [int]$Port = 4020,
  [switch]$ForceAny
)

$ErrorActionPreference = "Stop"

function Get-ListenerPids {
  param([int]$TargetPort)

  netstat -ano |
    Select-String "127\.0\.0\.1:$TargetPort\s+0\.0\.0\.0:0\s+LISTENING" |
    ForEach-Object { ($_ -split "\s+")[-1] } |
    Sort-Object -Unique
}

function Test-ArgosHealth {
  try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/health" -TimeoutSec 3
    return $health.status -eq "ok"
  } catch {
    return $false
  }
}

$listenerPids = @(Get-ListenerPids -TargetPort $Port)
if ($listenerPids.Count -eq 0) {
  Write-Host "No listener found on 127.0.0.1:$Port"
  exit 0
}

if (-not $ForceAny -and -not (Test-ArgosHealth)) {
  throw "Port $Port is listening but Argos health did not respond. Re-run with -ForceAny if you still want to stop PID(s): $($listenerPids -join ', ')"
}

foreach ($listenerPid in $listenerPids) {
  Stop-Process -Id ([int]$listenerPid) -Force
  Write-Host "Stopped listener PID $listenerPid on port $Port"
}
