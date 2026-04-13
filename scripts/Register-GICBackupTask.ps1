param(
  [string]$TaskName = "GIC Rotating Backup",
  [string]$StartTime = "20:00"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupScript = Join-Path $scriptDir "Run-GICBackup.ps1"

if (-not (Test-Path $backupScript)) {
  throw "Backup script not found: $backupScript"
}

$taskCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $backupScript + '"'

schtasks /Create /TN $TaskName /SC DAILY /MO 2 /ST $StartTime /TR $taskCommand /RU SYSTEM /F | Out-Null

Write-Output ("TASK_REGISTERED=" + $TaskName + " @ every 2 days from " + $StartTime)