[CmdletBinding()]
param(
  [string]$TaskName = "ArgosDesktopHub",
  [switch]$KeepUserEnv
)

$ErrorActionPreference = "Stop"

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  Write-Host "Removed scheduled task $TaskName"
} else {
  Write-Host "Scheduled task $TaskName was not installed"
}

$StartupCmd = Join-Path ([Environment]::GetFolderPath("Startup")) "$TaskName.cmd"
if (Test-Path -LiteralPath $StartupCmd) {
  Remove-Item -LiteralPath $StartupCmd -Force
  Write-Host "Removed Startup folder launcher $StartupCmd"
}

if (-not $KeepUserEnv) {
  [Environment]::SetEnvironmentVariable("ARGOS_URL", $null, "User")
  [Environment]::SetEnvironmentVariable("ARGOS_MCP_URL", $null, "User")
  [Environment]::SetEnvironmentVariable("ARGOS_HOME", $null, "User")
  Write-Host "Removed user ARGOS_URL, ARGOS_MCP_URL, and ARGOS_HOME"
}
