#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Mega Cleanup Script — BleachBit + PowerShell system cleanup
.DESCRIPTION
    Runs BleachBit with key categories, then performs PowerShell-based
    cleanup of Recycle Bin, temp folders, prefetch, and downloaded files.
    Reports freed disk space before and after.
#>

param(
    [switch]$SkipBleachBit,
    [switch]$SkipPSCleanup
)

$ErrorActionPreference = 'Continue'

# ── Helpers ────────────────────────────────────────────────────────────────
function Get-CDriveFreeGB {
    $d = Get-PSDrive C -ErrorAction SilentlyContinue
    if ($d) { return [math]::Round($d.Free / 1GB, 2) }
    return 0
}

function Remove-SafeFolder {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) {
        Write-Host "  [SKIP] $Label — path not found" -ForegroundColor DarkGray
        return 0
    }
    $before = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
               Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    $freed = if ($before) { [math]::Round($before / 1MB, 1) } else { 0 }
    Write-Host "  [OK] $Label — freed ~$freed MB" -ForegroundColor Green
    return $freed
}

# ── Disk baseline ──────────────────────────────────────────────────────────
$freeBefore = Get-CDriveFreeGB
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  MEGA CLEANUP — $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  C: free before: $freeBefore GB" -ForegroundColor Yellow
Write-Host ""

$totalFreedMB = 0

# ══════════════════════════════════════════════════════════════════════════
#  SECTION 1 — BleachBit
# ══════════════════════════════════════════════════════════════════════════
if (-not $SkipBleachBit) {
    Write-Host "[SECTION 1] BleachBit automated cleaning..." -ForegroundColor Magenta

    # Common BleachBit install paths
    $bbPaths = @(
        "$env:ProgramFiles\BleachBit\bleachbit_console.exe",
        "${env:ProgramFiles(x86)}\BleachBit\bleachbit_console.exe",
        "$env:LOCALAPPDATA\BleachBit\bleachbit_console.exe",
        "F:\backup\windowsapps\installed\BleachBit\bleachbit_console.exe"
    )
    $bb = $bbPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($bb) {
        Write-Host "  BleachBit found: $bb" -ForegroundColor DarkGray

        # Categories to clean (safe, non-destructive)
        $bbOptions = @(
            "--clean",
            "system.cache",
            "system.clipboard",
            "system.custom",
            "system.localizations",
            "system.logs",
            "system.memory_dump",
            "system.muicache",
            "system.prefetch",
            "system.recycle_bin",
            "system.tmp",
            "system.updates",
            "windows_explorer.mru",
            "windows_explorer.recent_documents",
            "windows_explorer.run",
            "windows_explorer.search_history",
            "windows_explorer.thumbnails"
        )

        Write-Host "  Running BleachBit (this may take 1-5 min)..." -ForegroundColor DarkGray
        try {
            $result = & $bb @bbOptions 2>&1
            $result | ForEach-Object { Write-Host "    BB: $_" -ForegroundColor DarkGray }
            Write-Host "  [OK] BleachBit completed" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] BleachBit error: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [SKIP] BleachBit not found in standard locations" -ForegroundColor Yellow
        Write-Host "         Install from https://www.bleachbit.org/ or add path to bbPaths array" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ══════════════════════════════════════════════════════════════════════════
#  SECTION 2 — PowerShell Cleanup
# ══════════════════════════════════════════════════════════════════════════
if (-not $SkipPSCleanup) {
    Write-Host "[SECTION 2] PowerShell system cleanup..." -ForegroundColor Magenta

    # 2a. Recycle Bin
    Write-Host "  Emptying Recycle Bin..." -NoNewline
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Host " [OK]" -ForegroundColor Green
    } catch {
        Write-Host " [WARN] $_" -ForegroundColor Yellow
    }

    # 2b. Windows Temp
    $totalFreedMB += Remove-SafeFolder "$env:SystemRoot\Temp" "Windows Temp (C:\Windows\Temp)"

    # 2c. User Temp
    $totalFreedMB += Remove-SafeFolder "$env:TEMP" "User Temp ($env:TEMP)"

    # 2d. System Temp (alternate)
    $totalFreedMB += Remove-SafeFolder "C:\Windows\Temp" "System Temp (fallback)"

    # 2e. Prefetch
    $totalFreedMB += Remove-SafeFolder "C:\Windows\Prefetch" "Prefetch (C:\Windows\Prefetch)"

    # 2f. SoftwareDistribution Downloads (Windows Update cache)
    $totalFreedMB += Remove-SafeFolder "C:\Windows\SoftwareDistribution\Download" "Windows Update Download Cache"

    # 2g. CBS Logs
    $totalFreedMB += Remove-SafeFolder "C:\Windows\Logs\CBS" "CBS Logs (C:\Windows\Logs\CBS)"

    # 2h. Windows Error Reporting
    $totalFreedMB += Remove-SafeFolder "$env:LOCALAPPDATA\Microsoft\Windows\WER" "Windows Error Reporting (WER)"

    # 2i. Thumbnail cache
    $thumbCache = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    if (Test-Path $thumbCache) {
        Write-Host "  Clearing thumbnail cache..." -NoNewline
        Get-ChildItem $thumbCache -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host " [OK]" -ForegroundColor Green
    }

    # 2j. Recent docs MRU
    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
    $totalFreedMB += Remove-SafeFolder $recentPath "Recent Documents MRU"

    # 2k. DISM online cleanup (frees WinSxS)
    Write-Host "  Running DISM cleanup (WinSxS)..." -ForegroundColor DarkGray
    try {
        $dismOut = & dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-String
        Write-Host "  [OK] DISM cleanup completed" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] DISM: $_" -ForegroundColor Yellow
    }

    Write-Host ""
}

# ══════════════════════════════════════════════════════════════════════════
#  SECTION 3 — Report
# ══════════════════════════════════════════════════════════════════════════
$freeAfter = Get-CDriveFreeGB
$freedTotal = [math]::Round($freeAfter - $freeBefore, 2)

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  MEGA CLEANUP COMPLETE" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  C: free before : $freeBefore GB" -ForegroundColor Yellow
Write-Host "  C: free after  : $freeAfter GB" -ForegroundColor Green
Write-Host "  Net freed      : +$freedTotal GB  (~$([math]::Round($freedTotal*1024,0)) MB)" -ForegroundColor Cyan
Write-Host "  PS folder freed: ~$totalFreedMB MB (temp/logs/cache)" -ForegroundColor DarkCyan
Write-Host ""
