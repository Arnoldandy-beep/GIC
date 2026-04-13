param(
  [ValidateSet("latest","copy_a","copy_b")]
  [string]$SourceSlot = "latest",
  [switch]$Force,
  [switch]$Preview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$backupRoot = Join-Path $projectRoot "backup"
$metaFileName = "backup-meta.json"

function Get-SlotTimestamp {
  param([string]$SlotPath)

  $metaPath = Join-Path $SlotPath $metaFileName
  if (-not (Test-Path $metaPath)) {
    return [datetime]::MinValue
  }

  try {
    $meta = Get-Content $metaPath -Raw | ConvertFrom-Json
    if ($meta.createdAtUtc) {
      return [datetime]::Parse($meta.createdAtUtc).ToUniversalTime()
    }
  } catch {
    return [datetime]::MinValue
  }

  return [datetime]::MinValue
}

if (-not (Test-Path $backupRoot)) {
  throw "Backup root not found: $backupRoot"
}

$slotPath = if ($SourceSlot -eq "latest") {
  Get-ChildItem -LiteralPath $backupRoot -Directory | Where-Object { $_.Name -in @("copy_a","copy_b") } |
    Sort-Object @{ Expression = { Get-SlotTimestamp $_.FullName } }, Name -Descending |
    Select-Object -First 1 -ExpandProperty FullName
} else {
  Join-Path $backupRoot $SourceSlot
}

if (-not $slotPath -or -not (Test-Path $slotPath)) {
  throw "Requested backup slot not found."
}

$slotItems = Get-ChildItem -LiteralPath $slotPath -Force | Where-Object { $_.Name -ne $metaFileName }

if ($Preview -or -not $Force) {
  Write-Output ("RESTORE_SOURCE=" + $slotPath)
  Write-Output "RESTORE_PREVIEW=The following top-level items would be restored:"
  $slotItems | Select-Object -ExpandProperty Name
  if (-not $Force) {
    Write-Output "RESTORE_NOTE=Run with -Force to apply the restore."
  }
  if ($Preview) {
    return
  }
}

$targets = Get-ChildItem -LiteralPath $projectRoot -Force | Where-Object { $_.Name -ne "backup" }
foreach ($target in $targets) {
  Remove-Item -LiteralPath $target.FullName -Recurse -Force
}

foreach ($item in $slotItems) {
  Copy-Item -LiteralPath $item.FullName -Destination $projectRoot -Recurse -Force
}

Write-Output ("RESTORE_COMPLETE=" + $slotPath)