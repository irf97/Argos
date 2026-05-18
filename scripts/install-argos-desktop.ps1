[CmdletBinding()]
param(
  [int]$Port = 4020,
  [string]$HostName = "127.0.0.1",
  [string]$TaskName = "ArgosDesktopHub",
  [ValidateSet("startup", "scheduled_task", "auto")]
  [string]$Method = "startup"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$StartScript = Join-Path $PSScriptRoot "start-argos.ps1"
$BaseUrl = "http://${HostName}:$Port"

function Set-UserEnvironmentVariable {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  [Environment]::SetEnvironmentVariable($Name, $Value, "User")
  & reg.exe add "HKCU\Environment" /v $Name /t REG_SZ /d $Value /f | Out-Null
}

Set-UserEnvironmentVariable -Name "ARGOS_URL" -Value $BaseUrl
Set-UserEnvironmentVariable -Name "ARGOS_MCP_URL" -Value "$BaseUrl/mcp"
Set-UserEnvironmentVariable -Name "ARGOS_HOME" -Value $Root

$InstalledVia = $null

function Install-StartupLauncher {
  $StartupDir = [Environment]::GetFolderPath("Startup")
  $StartupCmd = Join-Path $StartupDir "$TaskName.cmd"
  $CmdContent = @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$StartScript" -Port $Port -HostName $HostName
"@
  [System.IO.File]::WriteAllText($StartupCmd, $CmdContent, [System.Text.UTF8Encoding]::new($false))
  return $StartupCmd
}

if ($Method -in @("scheduled_task", "auto")) {
  $Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$StartScript`" -Port $Port -HostName $HostName"

  $Trigger = New-ScheduledTaskTrigger -AtLogOn
  $Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

  try {
    Register-ScheduledTask `
      -TaskName $TaskName `
      -Action $Action `
      -Trigger $Trigger `
      -Settings $Settings `
      -Description "Start ARGOS desktop memory hub on $BaseUrl at user logon." `
      -Force | Out-Null

    $InstalledVia = "scheduled_task"
  } catch {
    if ($Method -eq "scheduled_task") {
      throw
    }

    $StartupCmd = Install-StartupLauncher
    $InstalledVia = "startup_folder"
    Write-Warning "Scheduled task registration failed: $($_.Exception.Message)"
    Write-Warning "Installed Startup folder fallback: $StartupCmd"
  }
}

if ($Method -eq "startup") {
  $StartupCmd = Install-StartupLauncher
  $InstalledVia = "startup_folder"
  Write-Host "Installed Startup folder launcher $StartupCmd"
}

Write-Host "Installed Argos desktop hub via $InstalledVia"
Write-Host "Set user ARGOS_URL=$BaseUrl"
Write-Host "Set user ARGOS_MCP_URL=$BaseUrl/mcp"

& $StartScript -Port $Port -HostName $HostName
