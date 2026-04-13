Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$backupRoot = Join-Path $projectRoot "backup"
$slotNames = @("copy_a", "copy_b")
$metaFileName = "backup-meta.json"

function Get-SlotInfo {
  param([string]$SlotPath)

  $metaPath = Join-Path $SlotPath $metaFileName
  $timestamp = [datetime]::MinValue
  if (Test-Path $metaPath) {
    try {
      $meta = Get-Content $metaPath -Raw | ConvertFrom-Json
      if ($meta.createdAtUtc) {
        $timestamp = [datetime]::Parse($meta.createdAtUtc).ToUniversalTime()
      }
    } catch {
      $timestamp = [datetime]::MinValue
    }
  }

  [pscustomobject]@{
    Path = $SlotPath
    Timestamp = $timestamp
    Exists = (Test-Path $SlotPath)
  }
}

function Reset-Directory {
  param([string]$Path)

  if (Test-Path $Path) {
    Get-ChildItem -LiteralPath $Path -Force | Remove-Item -Recurse -Force
  } else {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

if (-not (Test-Path $backupRoot)) {
  New-Item -ItemType Directory -Path $backupRoot | Out-Null
}

$slotInfos = $slotNames | ForEach-Object {
  $slotPath = Join-Path $backupRoot $_
  if (-not (Test-Path $slotPath)) {
    New-Item -ItemType Directory -Path $slotPath | Out-Null
  }
  Get-SlotInfo -SlotPath $slotPath
}

$targetSlot = $slotInfos | Sort-Object Timestamp, Path | Select-Object -First 1
Reset-Directory -Path $targetSlot.Path

Get-ChildItem -LiteralPath $projectRoot -Force | Where-Object { $_.Name -ne "backup" } | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $targetSlot.Path -Recurse -Force
}

$meta = [ordered]@{
  createdAtLocal = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  createdAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  slot = [System.IO.Path]::GetFileName($targetSlot.Path)
  source = $projectRoot
} | ConvertTo-Json

Set-Content -LiteralPath (Join-Path $targetSlot.Path $metaFileName) -Value $meta -Encoding UTF8
Set-Content -LiteralPath (Join-Path $backupRoot "latest-backup.txt") -Value ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " -> " + $targetSlot.Path) -Encoding UTF8

Write-Output ("BACKUP_SLOT=" + $targetSlot.Path)