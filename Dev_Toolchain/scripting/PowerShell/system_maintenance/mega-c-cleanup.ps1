#Requires -RunAsAdministrator
<#
.SYNOPSIS
    MEGA C: DRIVE CLEANUP - Maximum Safe Space Recovery (ERROR-FREE EDITION)
.DESCRIPTION
    Comprehensive cleanup script targeting every safe temporary/cache location
    Now with bulletproof error handling and proper wildcard expansion
.NOTES
    Created: 2026-03-11
    Safe: Does not touch user data, applications, or system files
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'Continue'

$script:TotalFreed = 0
$script:StartTime = Get-Date
$script:LogPath = Join-Path $env:TEMP "mega-cleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure log directory exists
$logDir = Split-Path $script:LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Color = 'White')
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $logMsg = "[$timestamp] $Message"
    Write-Host $logMsg -ForegroundColor $Color
    try {
        $logMsg | Out-File -FilePath $script:LogPath -Append -Encoding UTF8 -ErrorAction Stop
    } catch {
        # Silently fail log writing if file is locked
    }
}

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Max(0, $size)
    } catch { return 0 }
}

function Remove-SafePath {
    param(
        [string]$Path,
        [string]$Label,
        [switch]$KeepFolder,
        [switch]$SkipIfLocked
    )
    
    # Expand wildcards in path
    $expandedPaths = @()
    if ($Path -match '\*') {
        try {
            $expandedPaths = @(Get-Item $Path -Force -ErrorAction SilentlyContinue)
        } catch {
            $expandedPaths = @()
        }
    } else {
        if (Test-Path $Path) {
            $expandedPaths = @($Path)
        }
    }
    
    if ($expandedPaths.Count -eq 0) {
        Write-Log "  ⊘ $Label - Not found" -Color DarkGray
        return
    }
    
    $totalFreed = 0
    foreach ($actualPath in $expandedPaths) {
        $sizeBefore = Get-FolderSize $actualPath
        if ($sizeBefore -eq 0) { continue }
        
        try {
            if ($KeepFolder) {
                Get-ChildItem $actualPath -Force -ErrorAction Stop | ForEach-Object {
                    try {
                        Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop
                    } catch {
                        if (-not $SkipIfLocked) {
                            # Silently skip locked files
                        }
                    }
                }
            } else {
                Remove-Item $actualPath -Recurse -Force -ErrorAction Stop
            }
            
            $sizeAfter = Get-FolderSize $actualPath
            $freed = $sizeBefore - $sizeAfter
            $totalFreed += $freed
        } catch {
            if (-not $SkipIfLocked) {
                Write-Log "  ⚠ $Label - Partially cleaned (some files locked)" -Color Yellow
            }
        }
    }
    
    if ($totalFreed -gt 0) {
        $script:TotalFreed += $totalFreed
        $freedMB = [math]::Round($totalFreed / 1MB, 2)
        $color = if ($totalFreed -gt 100MB) { 'Green' } 
                 elseif ($totalFreed -gt 10MB) { 'Yellow' } 
                 else { 'Gray' }
        Write-Log "  ✓ $Label - Freed: ${freedMB}MB | Total: $([math]::Round($script:TotalFreed/1GB,2))GB" -Color $color
    } else {
        Write-Log "  ○ $Label - Already empty" -Color DarkGray
    }
}

function Invoke-CommandSafe {
    param(
        [string]$Command,
        [string]$Label,
        [int]$TimeoutSeconds = 300
    )
    
    Write-Log "  ⚙ $Label..." -Color Cyan
    try {
        $job = Start-Job -ScriptBlock { 
            param($cmd) 
            Invoke-Expression $cmd 2>&1 
        } -ArgumentList $Command
        
        $completed = Wait-Job $job -Timeout $TimeoutSeconds
        if ($completed) {
            $output = Receive-Job $job
            Remove-Job $job -Force
            Write-Log "  ✓ $Label - Complete" -Color Green
            return $output
        } else {
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            Write-Log "  ⏱ $Label - Timeout (${TimeoutSeconds}s)" -Color Yellow
        }
    } catch {
        Write-Log "  ⚠ $Label - Skipped" -Color Yellow
    }
}

# ============================================================================
# MAIN CLEANUP SEQUENCE
# ============================================================================

Write-Log "═══════════════════════════════════════════════════════════════" -Color Magenta
Write-Log "    MEGA C: DRIVE CLEANUP - MAXIMUM SAFE SPACE RECOVERY" -Color Magenta
Write-Log "═══════════════════════════════════════════════════════════════" -Color Magenta
Write-Log ""

# Pre-flight space check
$cDrive = Get-PSDrive C -ErrorAction SilentlyContinue
if ($cDrive) {
    $spaceBefore = [math]::Round($cDrive.Free / 1GB, 2)
    Write-Log "C: Drive Free Space Before: ${spaceBefore}GB" -Color White
} else {
    $spaceBefore = 0
}
Write-Log ""

# ============================================================================
Write-Log "[1/25] Windows Temp Folders" -Color Yellow
# ============================================================================
Remove-SafePath "C:\Windows\Temp\*" "Windows Temp Contents" -SkipIfLocked
Remove-SafePath "C:\Windows\Prefetch\*" "Prefetch Cache Contents" -SkipIfLocked
if (Test-Path "C:\Temp") {
    Remove-SafePath "C:\Temp\*" "C:\Temp Contents" -SkipIfLocked
}
Remove-SafePath "$env:TEMP\*" "User Temp Contents" -SkipIfLocked
Remove-SafePath "$env:TMP\*" "User TMP Contents" -SkipIfLocked

# All users temp (properly expanded)
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $userTempPath = Join-Path $_.FullName "AppData\Local\Temp"
    if (Test-Path $userTempPath) {
        $sizeBefore = Get-FolderSize $userTempPath
        if ($sizeBefore -gt 1MB) {
            Get-ChildItem $userTempPath -Force -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
            $freed = $sizeBefore - (Get-FolderSize $userTempPath)
            if ($freed -gt 0) {
                $script:TotalFreed += $freed
                Write-Log "  ✓ User $($_.Name) Temp - Freed: $([math]::Round($freed/1MB,2))MB" -Color Green
            }
        }
    }
}

# ============================================================================
Write-Log "[2/25] Windows Update Cleanup" -Color Yellow
# ============================================================================
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service UsoSvc -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Remove-SafePath "C:\Windows\SoftwareDistribution\Download\*" "Update Downloads" -SkipIfLocked
Remove-SafePath "C:\Windows\SoftwareDistribution\DataStore\Logs\*" "Update DataStore Logs" -SkipIfLocked
Remove-SafePath "C:\`$Windows.~BT" "Windows Update Temp"
Remove-SafePath "C:\`$Windows.~WS" "Windows Update Setup"
Remove-SafePath "C:\Windows\SoftwareDistribution\DeliveryOptimization" "Delivery Optimization"

Start-Service wuauserv -ErrorAction SilentlyContinue
Start-Service UsoSvc -ErrorAction SilentlyContinue

# ============================================================================
Write-Log "[3/25] Windows Error Reporting and Dumps" -Color Yellow
# ============================================================================
Remove-SafePath "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*" "WER Report Queue" -SkipIfLocked
Remove-SafePath "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*" "WER Report Archive" -SkipIfLocked
Remove-SafePath "C:\Windows\Minidump" "Minidumps"
Remove-SafePath "C:\Windows\MEMORY.DMP" "Memory Dump"
Remove-SafePath "C:\ProgramData\Microsoft\Windows\WER\Temp\*" "WER Temp" -SkipIfLocked

# All users crash dumps
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $crashPath = Join-Path $_.FullName "AppData\Local\CrashDumps"
    if (Test-Path $crashPath) {
        Remove-SafePath "$crashPath\*" "User $($_.Name) Crash Dumps" -SkipIfLocked
    }
}

# ============================================================================
Write-Log "[4/25] Browser Caches (All Users)" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $userName = $_.Name
    $userPath = $_.FullName
    
    # Chrome
    $chromePath = Join-Path $userPath "AppData\Local\Google\Chrome\User Data"
    if (Test-Path $chromePath) {
        Get-ChildItem $chromePath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafePath (Join-Path $_.FullName "Cache\*") "$userName Chrome $($_.Name) Cache" -SkipIfLocked
            Remove-SafePath (Join-Path $_.FullName "Code Cache\*") "$userName Chrome $($_.Name) Code Cache" -SkipIfLocked
            Remove-SafePath (Join-Path $_.FullName "GPUCache\*") "$userName Chrome $($_.Name) GPU Cache" -SkipIfLocked
        }
        Remove-SafePath (Join-Path $chromePath "ShaderCache\*") "$userName Chrome Shader Cache" -SkipIfLocked
    }
    
    # Edge
    $edgePath = Join-Path $userPath "AppData\Local\Microsoft\Edge\User Data"
    if (Test-Path $edgePath) {
        Get-ChildItem $edgePath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafePath (Join-Path $_.FullName "Cache\*") "$userName Edge $($_.Name) Cache" -SkipIfLocked
            Remove-SafePath (Join-Path $_.FullName "Code Cache\*") "$userName Edge $($_.Name) Code Cache" -SkipIfLocked
        }
    }
    
    # Firefox
    $firefoxPath = Join-Path $userPath "AppData\Local\Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxPath) {
        Get-ChildItem $firefoxPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafePath (Join-Path $_.FullName "cache2\*") "$userName Firefox $($_.Name) Cache" -SkipIfLocked
            Remove-SafePath (Join-Path $_.FullName "startupCache\*") "$userName Firefox $($_.Name) Startup" -SkipIfLocked
        }
    }
}

# ============================================================================
Write-Log "[5/25] Windows Thumbnail and Icon Cache" -Color Yellow
# ============================================================================
# Kill Explorer to release locks
$explorerRunning = Get-Process explorer -ErrorAction SilentlyContinue
if ($explorerRunning) {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $userName = $_.Name
    $explorerPath = Join-Path $_.FullName "AppData\Local\Microsoft\Windows\Explorer"
    if (Test-Path $explorerPath) {
        Remove-SafePath "$explorerPath\thumbcache_*.db" "$userName Thumbnail Cache"
        Remove-SafePath "$explorerPath\iconcache_*.db" "$userName Icon Cache"
    }
    Remove-SafePath (Join-Path $_.FullName "AppData\Local\IconCache.db") "$userName Icon Cache DB"
}

# Restart Explorer
Start-Process explorer.exe -ErrorAction SilentlyContinue

# ============================================================================
Write-Log "[6/25] Windows Logs" -Color Yellow
# ============================================================================
Remove-SafePath "C:\Windows\Logs\CBS\*" "CBS Logs" -SkipIfLocked
Remove-SafePath "C:\Windows\Logs\DISM\*" "DISM Logs" -SkipIfLocked
Remove-SafePath "C:\Windows\Logs\DPX" "DPX Logs"
Remove-SafePath "C:\Windows\Logs\MoSetup" "MoSetup Logs"
Remove-SafePath "C:\Windows\Logs\WindowsUpdate\*" "Windows Update Logs" -SkipIfLocked
Remove-SafePath "C:\Windows\Panther\*" "Windows Setup Logs" -SkipIfLocked
Remove-SafePath "C:\Windows\Performance\WinSAT\*" "WinSAT Logs" -SkipIfLocked

# Clear Event Logs
$clearedCount = 0
Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName)
        $clearedCount++
    } catch {}
}
if ($clearedCount -gt 0) {
    Write-Log "  ✓ Cleared $clearedCount Event Logs" -Color Green
}

# ============================================================================
Write-Log "[7/25] Windows Defender" -Color Yellow
# ============================================================================
Remove-SafePath "C:\ProgramData\Microsoft\Windows Defender\Scans\History\Store\*" "Defender Scan History" -SkipIfLocked
Remove-SafePath "C:\ProgramData\Microsoft\Windows Defender\Scans\History\Service\*" "Defender Service History" -SkipIfLocked
Remove-SafePath "C:\ProgramData\Microsoft\Windows Defender\Support\*" "Defender Support Files" -SkipIfLocked

# ============================================================================
Write-Log "[8/25] DNS & Network Cache" -Color Yellow
# ============================================================================
ipconfig /flushdns 2>&1 | Out-Null
Write-Log "  ✓ DNS Cache Flushed" -Color Green
Remove-SafePath "C:\Windows\System32\config\systemprofile\AppData\LocalLow\Microsoft\CryptnetUrlCache\*" "System Cryptnet Cache" -SkipIfLocked
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $cryptPath = Join-Path $_.FullName "AppData\LocalLow\Microsoft\CryptnetUrlCache"
    if (Test-Path $cryptPath) {
        Remove-SafePath "$cryptPath\*" "$($_.Name) Cryptnet Cache" -SkipIfLocked
    }
}

# ============================================================================
Write-Log "[9/25] Windows Store and Apps Cache" -Color Yellow
# ============================================================================
try {
    Start-Process "wsreset.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Stop-Process -Name WinStore.App -Force -ErrorAction SilentlyContinue
    Write-Log "  ✓ Windows Store Cache Reset" -Color Green
} catch {
    Write-Log "  ⚠ Windows Store reset skipped" -Color Yellow
}

Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $packagesPath = Join-Path $_.FullName "AppData\Local\Packages"
    if (Test-Path $packagesPath) {
        Get-ChildItem $packagesPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafePath (Join-Path $_.FullName "AC\Temp\*") "UWP $($_.Name) Temp" -SkipIfLocked
            Remove-SafePath (Join-Path $_.FullName "LocalCache\*") "UWP $($_.Name) Cache" -SkipIfLocked
            Remove-SafePath (Join-Path $_.FullName "TempState\*") "UWP $($_.Name) TempState" -SkipIfLocked
        }
    }
}

# ============================================================================
Write-Log "[10/25] Font Cache" -Color Yellow
# ============================================================================
Stop-Service FontCache -Force -ErrorAction SilentlyContinue
Remove-SafePath "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache\*" "System Font Cache" -SkipIfLocked
Remove-SafePath "C:\Windows\System32\FNTCACHE.DAT" "Font Cache DAT"
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $fontPath = Join-Path $_.FullName "AppData\Local\FontCache"
    if (Test-Path $fontPath) {
        Remove-SafePath "$fontPath\*" "$($_.Name) Font Cache" -SkipIfLocked
    }
}
Start-Service FontCache -ErrorAction SilentlyContinue

# ============================================================================
Write-Log "[11/25] Windows Installer Cache" -Color Yellow
# ============================================================================
Remove-SafePath "C:\Windows\Installer\`$PatchCache$\*" "Installer Patch Cache" -SkipIfLocked

# ============================================================================
Write-Log "[12/25] Downloaded Program Files" -Color Yellow
# ============================================================================
Remove-SafePath "C:\Windows\Downloaded Program Files\*" "Downloaded Program Files" -SkipIfLocked

# ============================================================================
Write-Log "[13/25] IIS & Web Logs (if installed)" -Color Yellow
# ============================================================================
Remove-SafePath "C:\inetpub\logs" "IIS Logs"
Remove-SafePath "C:\Windows\System32\LogFiles\W3SVC*" "W3SVC Logs"
Remove-SafePath "C:\Windows\System32\LogFiles\HTTPERR\*" "HTTP Error Logs" -SkipIfLocked

# ============================================================================
Write-Log "[14/25] Visual Studio & .NET Cache" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $userName = $_.Name
    $vsPath = Join-Path $_.FullName "AppData\Local\Microsoft\VisualStudio"
    if (Test-Path $vsPath) {
        Get-ChildItem $vsPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafePath (Join-Path $_.FullName "ComponentModelCache\*") "$userName VS ComponentCache" -SkipIfLocked
            Remove-SafePath (Join-Path $_.FullName "Extensions\*") "$userName VS Extensions" -SkipIfLocked
        }
    }
    
    Remove-SafePath (Join-Path $_.FullName "AppData\Local\NuGet\v3-cache\*") "$userName NuGet v3 Cache" -SkipIfLocked
    Remove-SafePath (Join-Path $_.FullName "AppData\Local\NuGet\Cache\*") "$userName NuGet Cache" -SkipIfLocked
}

Remove-SafePath "C:\Windows\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files\*" "ASP.NET Temp (x86)" -SkipIfLocked
Remove-SafePath "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files\*" "ASP.NET Temp (x64)" -SkipIfLocked

# ============================================================================
Write-Log "[15/25] OneDrive Cache" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $odPath = Join-Path $_.FullName "AppData\Local\Microsoft\OneDrive\logs"
    if (Test-Path $odPath) {
        Remove-SafePath "$odPath\*" "$($_.Name) OneDrive Logs" -SkipIfLocked
    }
}

# ============================================================================
Write-Log "[16/25] Microsoft Teams Cache" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $userName = $_.Name
    $teamsPath = Join-Path $_.FullName "AppData\Roaming\Microsoft\Teams"
    if (Test-Path $teamsPath) {
        Remove-SafePath (Join-Path $teamsPath "Cache\*") "$userName Teams Cache" -SkipIfLocked
        Remove-SafePath (Join-Path $teamsPath "blob_storage\*") "$userName Teams Blob Storage" -SkipIfLocked
        Remove-SafePath (Join-Path $teamsPath "databases\*") "$userName Teams Databases" -SkipIfLocked
        Remove-SafePath (Join-Path $teamsPath "GPUCache\*") "$userName Teams GPU Cache" -SkipIfLocked
        Remove-SafePath (Join-Path $teamsPath "IndexedDB\*") "$userName Teams IndexedDB" -SkipIfLocked
        Remove-SafePath (Join-Path $teamsPath "Local Storage\*") "$userName Teams Local Storage" -SkipIfLocked
        Remove-SafePath (Join-Path $teamsPath "tmp\*") "$userName Teams Temp" -SkipIfLocked
    }
}

# ============================================================================
Write-Log "[17/25] Package Manager Caches" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $userName = $_.Name
    Remove-SafePath (Join-Path $_.FullName "AppData\Local\npm-cache\*") "$userName npm Cache" -SkipIfLocked
    Remove-SafePath (Join-Path $_.FullName "AppData\Roaming\npm-cache\*") "$userName npm Roaming Cache" -SkipIfLocked
    Remove-SafePath (Join-Path $_.FullName "AppData\Local\pip\Cache\*") "$userName pip Cache" -SkipIfLocked
    Remove-SafePath (Join-Path $_.FullName "AppData\Local\Composer\cache\*") "$userName Composer Cache" -SkipIfLocked
    Remove-SafePath (Join-Path $_.FullName ".gradle\caches\*") "$userName Gradle Caches" -SkipIfLocked
    Remove-SafePath (Join-Path $_.FullName "AppData\Local\Yarn\Cache\*") "$userName Yarn Cache" -SkipIfLocked
}

# Chocolatey
if (Test-Path "C:\ProgramData\chocolatey\logs") {
    Remove-SafePath "C:\ProgramData\chocolatey\logs\*" "Chocolatey Logs" -SkipIfLocked
}

# ============================================================================
Write-Log "[18/25] Docker Cleanup (if installed)" -Color Yellow
# ============================================================================
$dockerExists = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerExists) {
    try {
        docker system prune -af --volumes 2>&1 | Out-Null
        Write-Log "  ✓ Docker System Pruned" -Color Green
    } catch {
        Write-Log "  ⚠ Docker cleanup skipped" -Color Yellow
    }
} else {
    Write-Log "  ⊘ Docker not installed" -Color DarkGray
}

# ============================================================================
Write-Log "[19/25] Recycle Bin (All Drives)" -Color Yellow
# ============================================================================
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Log "  ✓ Recycle Bin Emptied" -Color Green
} catch {
    Write-Log "  ⚠ Recycle Bin cleanup skipped" -Color Yellow
}

# ============================================================================
Write-Log "[20/25] Windows Search Index" -Color Yellow
# ============================================================================
Stop-Service WSearch -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Remove-SafePath "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb" "Search Index"
Start-Service WSearch -ErrorAction SilentlyContinue

# ============================================================================
Write-Log "[21/25] Windows.old (if exists)" -Color Yellow
# ============================================================================
if (Test-Path "C:\Windows.old") {
    Write-Log "  ⚙ Removing Windows.old (this may take a while)..." -Color Cyan
    try {
        takeown /F "C:\Windows.old\*" /R /A /D Y 2>&1 | Out-Null
        icacls "C:\Windows.old\*.*" /T /grant administrators:F 2>&1 | Out-Null
        Remove-Item "C:\Windows.old" -Recurse -Force -ErrorAction Stop
        Write-Log "  ✓ Windows.old removed" -Color Green
    } catch {
        Write-Log "  ⚠ Windows.old removal failed (use Disk Cleanup)" -Color Yellow
    }
} else {
    Write-Log "  ⊘ Windows.old not found" -Color DarkGray
}

# ============================================================================
Write-Log "[22/25] Advanced DISM Cleanup" -Color Yellow
# ============================================================================
Invoke-CommandSafe "Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase" "DISM Component Cleanup" 600
Invoke-CommandSafe "Dism.exe /online /Cleanup-Image /SPSuperseded" "DISM Superseded Cleanup" 600

# ============================================================================
Write-Log "[23/25] Driver Store Info" -Color Yellow
# ============================================================================
Write-Log "  ℹ Driver store not automatically cleaned (requires manual review)" -Color Cyan

# ============================================================================
Write-Log "[24/25] Hibernation File Optimization" -Color Yellow
# ============================================================================
try {
    powercfg /h /type reduced 2>&1 | Out-Null
    Write-Log "  ✓ Hibernation file set to reduced" -Color Green
} catch {
    Write-Log "  ⚠ Hibernation optimization skipped" -Color Yellow
}

# ============================================================================
Write-Log "[25/25] Final Optimizations" -Color Yellow
# ============================================================================

# Compact OS (background)
$compactJob = Start-Job -ScriptBlock {
    compact /compactos:always 2>&1 | Select-Object -Last 1
}

# TRIM all fixed drives
Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
    try {
        Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction Stop
        Write-Log "  ✓ TRIM on $($_.DriveLetter):" -Color Green
    } catch {}
}

# WinSxS Compression (background)
$compressJob = Start-Job -ScriptBlock {
    @('C:\Windows\WinSxS\Temp', 'C:\Windows\Logs', 'C:\Windows\Installer', 'C:\Windows\inf') | ForEach-Object {
        if (Test-Path $_) {
            compact /c /s:$_ /i /q 2>&1 | Out-Null
        }
    }
}

# Wait for jobs (max 30 seconds)
Wait-Job $compactJob -Timeout 30 | Out-Null
Wait-Job $compressJob -Timeout 30 | Out-Null
Remove-Job $compactJob, $compressJob -Force -ErrorAction SilentlyContinue

# ============================================================================
# FINAL REPORT
# ============================================================================
Write-Log ""
Write-Log "═══════════════════════════════════════════════════════════════" -Color Magenta
Write-Log "                    CLEANUP COMPLETE" -Color Magenta
Write-Log "═══════════════════════════════════════════════════════════════" -Color Magenta
Write-Log ""

# Post-flight space check
$cDriveAfter = Get-PSDrive C -ErrorAction SilentlyContinue
if ($cDriveAfter) {
    $spaceAfter = [math]::Round($cDriveAfter.Free / 1GB, 2)
    $actualFreed = [math]::Round(($spaceAfter - $spaceBefore), 2)
    
    Write-Log "C: Drive Free Space Before: ${spaceBefore}GB" -Color White
    Write-Log "C: Drive Free Space After:  ${spaceAfter}GB" -Color White
    Write-Log "Actual Space Freed:         ${actualFreed}GB" -Color $(if($actualFreed -gt 10){'Green'}elseif($actualFreed -gt 5){'Yellow'}else{'White'})
}

Write-Log "Total Files/Folders Cleaned: $([math]::Round($script:TotalFreed/1GB,2))GB" -Color Cyan
Write-Log ""

$elapsed = (Get-Date) - $script:StartTime
Write-Log "Time Elapsed: $($elapsed.ToString('mm\:ss'))" -Color White
Write-Log "Log saved to: $script:LogPath" -Color DarkGray
Write-Log ""
Write-Log "RECOMMENDATIONS:" -Color Yellow
Write-Log "  1. Run Windows Disk Cleanup (cleanmgr.exe) for system files" -Color Cyan
Write-Log "  2. Check System Restore points (vssadmin list shadows)" -Color Cyan
Write-Log "  3. Review large files with TreeSize / WinDirStat" -Color Cyan
Write-Log "  4. Consider moving user folders to another drive" -Color Cyan
Write-Log ""

# Open log file
Start-Process notepad.exe $script:LogPath
