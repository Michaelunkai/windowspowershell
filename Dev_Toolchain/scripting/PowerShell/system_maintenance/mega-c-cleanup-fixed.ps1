#Requires -RunAsAdministrator
<#
.SYNOPSIS
    MEGA C: DRIVE CLEANUP - Maximum Safe Space Recovery
.DESCRIPTION
    Comprehensive cleanup script - targets every safe temp/cache location
.NOTES
    Created: 2026-03-11
    Safe: Does not touch user data, applications, or system files
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

$script:TotalFreed = 0
$script:StartTime = Get-Date
$script:LogPath = Join-Path $env:TEMP "mega-cleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Color = 'White')
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $logMsg = "[$timestamp] $Message"
    Write-Host $logMsg -ForegroundColor $Color
    try {
        $logMsg | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    } catch {}
}

function Get-Size {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = (Get-ChildItem $Path -Recurse -Force -EA 0 | Measure-Object Length -Sum -EA 0).Sum
        if ($size) { return $size } else { return 0 }
    } catch { return 0 }
}

function Remove-Safe {
    param([string]$Path, [string]$Label)
    
    if (-not (Test-Path $Path)) {
        Write-Log "  ⊘ $Label - Not found" -Color DarkGray
        return
    }
    
    $sizeBefore = Get-Size $Path
    if ($sizeBefore -eq 0) {
        Write-Log "  ○ $Label - Already empty" -Color DarkGray
        return
    }
    
    try {
        Get-ChildItem $Path -Force -EA 0 | Remove-Item -Recurse -Force -EA 0
        $sizeAfter = Get-Size $Path
        $freed = $sizeBefore - $sizeAfter
        
        if ($freed -gt 0) {
            $script:TotalFreed += $freed
            $freedMB = [math]::Round($freed / 1MB, 2)
            $color = if ($freed -gt 100MB) { 'Green' } elseif ($freed -gt 10MB) { 'Yellow' } else { 'Gray' }
            Write-Log "  ✓ $Label - Freed: ${freedMB}MB | Total: $([math]::Round($script:TotalFreed/1GB,2))GB" -Color $color
        } else {
            Write-Log "  ○ $Label - Already clean" -Color DarkGray
        }
    } catch {
        Write-Log "  ⚠ $Label - Partially cleaned (locked files)" -Color Yellow
    }
}

Write-Log "═══════════════════════════════════════════════════════════════" -Color Magenta
Write-Log "    MEGA C: DRIVE CLEANUP - MAXIMUM SAFE SPACE RECOVERY" -Color Magenta
Write-Log "═══════════════════════════════════════════════════════════════" -Color Magenta
Write-Log ""

$cDrive = Get-PSDrive C -EA 0
if ($cDrive) {
    $spaceBefore = [math]::Round($cDrive.Free / 1GB, 2)
    Write-Log "C: Drive Free Space Before: ${spaceBefore}GB" -Color White
}
Write-Log ""

# ============================================================================
Write-Log "[1/25] Windows Temp Folders" -Color Yellow
# ============================================================================
Remove-Safe "C:\Windows\Temp" "Windows Temp"
Remove-Safe "C:\Windows\Prefetch" "Prefetch"
Remove-Safe "$env:TEMP" "User Temp"

Get-ChildItem "C:\Users" -Directory -EA 0 | ForEach-Object {
    $tempPath = Join-Path $_.FullName "AppData\Local\Temp"
    if (Test-Path $tempPath) {
        Remove-Safe $tempPath "User $($_.Name) Temp"
    }
}

# ============================================================================
Write-Log "[2/25] Windows Update Cleanup" -Color Yellow
# ============================================================================
Stop-Service wuauserv -Force -EA 0
Stop-Service UsoSvc -Force -EA 0
Start-Sleep -Seconds 1
Remove-Safe "C:\Windows\SoftwareDistribution\Download" "Update Downloads"
Remove-Safe "C:\Windows\SoftwareDistribution\DataStore\Logs" "Update Logs"
Remove-Safe "C:\`$Windows.~BT" "Windows Update Temp"
Remove-Safe "C:\`$Windows.~WS" "Windows Update Setup"
Start-Service wuauserv -EA 0
Start-Service UsoSvc -EA 0

# ============================================================================
Write-Log "[3/25] Windows Error Reporting" -Color Yellow
# ============================================================================
Remove-Safe "C:\ProgramData\Microsoft\Windows\WER\ReportQueue" "WER Queue"
Remove-Safe "C:\ProgramData\Microsoft\Windows\WER\ReportArchive" "WER Archive"
Remove-Safe "C:\Windows\Minidump" "Minidumps"
if (Test-Path "C:\Windows\MEMORY.DMP") {
    Remove-Item "C:\Windows\MEMORY.DMP" -Force -EA 0
}

Get-ChildItem "C:\Users" -Directory -EA 0 | ForEach-Object {
    $crashPath = Join-Path $_.FullName "AppData\Local\CrashDumps"
    if (Test-Path $crashPath) {
        Remove-Safe $crashPath "User $($_.Name) Crash Dumps"
    }
}

# ============================================================================
Write-Log "[4/25] Browser Caches" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -EA 0 | ForEach-Object {
    $user = $_.Name
    
    # Chrome
    $chromePath = Join-Path $_.FullName "AppData\Local\Google\Chrome\User Data"
    if (Test-Path $chromePath) {
        Get-ChildItem $chromePath -Directory -EA 0 | ForEach-Object {
            Remove-Safe (Join-Path $_.FullName "Cache") "$user Chrome Cache"
            Remove-Safe (Join-Path $_.FullName "Code Cache") "$user Chrome Code Cache"
            Remove-Safe (Join-Path $_.FullName "GPUCache") "$user Chrome GPU Cache"
        }
    }
    
    # Edge
    $edgePath = Join-Path $_.FullName "AppData\Local\Microsoft\Edge\User Data"
    if (Test-Path $edgePath) {
        Get-ChildItem $edgePath -Directory -EA 0 | ForEach-Object {
            Remove-Safe (Join-Path $_.FullName "Cache") "$user Edge Cache"
            Remove-Safe (Join-Path $_.FullName "Code Cache") "$user Edge Code Cache"
        }
    }
    
    # Firefox
    $ffPath = Join-Path $_.FullName "AppData\Local\Mozilla\Firefox\Profiles"
    if (Test-Path $ffPath) {
        Get-ChildItem $ffPath -Directory -EA 0 | ForEach-Object {
            Remove-Safe (Join-Path $_.FullName "cache2") "$user Firefox Cache"
        }
    }
}

# ============================================================================
Write-Log "[5/25] Thumbnail and Icon Cache" -Color Yellow
# ============================================================================
Stop-Process -Name explorer -Force -EA 0
Start-Sleep -Seconds 2

Get-ChildItem "C:\Users" -Directory -EA 0 | ForEach-Object {
    $explorerPath = Join-Path $_.FullName "AppData\Local\Microsoft\Windows\Explorer"
    if (Test-Path $explorerPath) {
        Get-ChildItem $explorerPath -File -Filter "thumbcache_*.db" -EA 0 | Remove-Item -Force -EA 0
        Get-ChildItem $explorerPath -File -Filter "iconcache_*.db" -EA 0 | Remove-Item -Force -EA 0
    }
}

Start-Process explorer.exe -EA 0

# ============================================================================
Write-Log "[6/25] Windows Logs" -Color Yellow
# ============================================================================
Remove-Safe "C:\Windows\Logs\CBS" "CBS Logs"
Remove-Safe "C:\Windows\Logs\DISM" "DISM Logs"
Remove-Safe "C:\Windows\Logs\WindowsUpdate" "Windows Update Logs"
Remove-Safe "C:\Windows\Panther" "Setup Logs"

$clearedCount = 0
Get-WinEvent -ListLog * -EA 0 | ForEach-Object {
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
Remove-Safe "C:\ProgramData\Microsoft\Windows Defender\Scans\History" "Defender History"
Remove-Safe "C:\ProgramData\Microsoft\Windows Defender\Support" "Defender Support"

# ============================================================================
Write-Log "[8/25] Network Cache" -Color Yellow
# ============================================================================
ipconfig /flushdns 2>&1 | Out-Null
Write-Log "  ✓ DNS Cache Flushed" -Color Green

Get-ChildItem "C:\Users" -Directory -EA 0 | ForEach-Object {
    $cryptPath = Join-Path $_.FullName "AppData\LocalLow\Microsoft\CryptnetUrlCache"
    if (Test-Path $cryptPath) {
        Remove-Safe $cryptPath "$($_.Name) Cryptnet Cache"
    }
}

# ============================================================================
Write-Log "[9/25] Windows Store Cache" -Color Yellow
# ============================================================================
try {
    Start-Process "wsreset.exe" -WindowStyle Hidden -EA 0
    Start-Sleep -Seconds 3
    Stop-Process -Name WinStore.App -Force -EA 0
    Write-Log "  ✓ Store Cache Reset" -Color Green
} catch {}

# ============================================================================
Write-Log "[10/25] Font Cache" -Color Yellow
# ============================================================================
Stop-Service FontCache -Force -EA 0
Remove-Safe "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache" "System Font Cache"
if (Test-Path "C:\Windows\System32\FNTCACHE.DAT") {
    Remove-Item "C:\Windows\System32\FNTCACHE.DAT" -Force -EA 0
}
Start-Service FontCache -EA 0

# ============================================================================
Write-Log "[11/25] Windows Installer Cache" -Color Yellow
# ============================================================================
Remove-Safe "C:\Windows\Installer\`$PatchCache$" "Installer Patch Cache"

# ============================================================================
Write-Log "[12/25] Downloaded Program Files" -Color Yellow
# ============================================================================
Remove-Safe "C:\Windows\Downloaded Program Files" "Downloaded Program Files"

# ============================================================================
Write-Log "[13/25] IIS Logs" -Color Yellow
# ============================================================================
Remove-Safe "C:\inetpub\logs" "IIS Logs"
Remove-Safe "C:\Windows\System32\LogFiles\HTTPERR" "HTTP Error Logs"

# ============================================================================
Write-Log "[14/25] Visual Studio and .NET Cache" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -EA 0 | ForEach-Object {
    Remove-Safe (Join-Path $_.FullName "AppData\Local\NuGet\v3-cache") "$($_.Name) NuGet Cache"
    Remove-Safe (Join-Path $_.FullName "AppData\Local\NuGet\Cache") "$($_.Name) NuGet Cache v2"
}

Remove-Safe "C:\Windows\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files" "ASP.NET Temp x86"
Remove-Safe "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files" "ASP.NET Temp x64"

# ============================================================================
Write-Log "[15/25] OneDrive Logs" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -EA 0 | ForEach-Object {
    Remove-Safe (Join-Path $_.FullName "AppData\Local\Microsoft\OneDrive\logs") "$($_.Name) OneDrive Logs"
}

# ============================================================================
Write-Log "[16/25] Teams Cache" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -EA 0 | ForEach-Object {
    $teamsPath = Join-Path $_.FullName "AppData\Roaming\Microsoft\Teams"
    if (Test-Path $teamsPath) {
        Remove-Safe (Join-Path $teamsPath "Cache") "$($_.Name) Teams Cache"
        Remove-Safe (Join-Path $teamsPath "blob_storage") "$($_.Name) Teams Blob"
        Remove-Safe (Join-Path $teamsPath "databases") "$($_.Name) Teams DB"
        Remove-Safe (Join-Path $teamsPath "GPUCache") "$($_.Name) Teams GPU"
    }
}

# ============================================================================
Write-Log "[17/25] Package Manager Caches" -Color Yellow
# ============================================================================
Get-ChildItem "C:\Users" -Directory -EA 0 | ForEach-Object {
    Remove-Safe (Join-Path $_.FullName "AppData\Local\npm-cache") "$($_.Name) npm Cache"
    Remove-Safe (Join-Path $_.FullName "AppData\Local\pip\Cache") "$($_.Name) pip Cache"
    Remove-Safe (Join-Path $_.FullName ".gradle\caches") "$($_.Name) Gradle Cache"
}

# ============================================================================
Write-Log "[18/25] Docker Cleanup" -Color Yellow
# ============================================================================
if (Get-Command docker -EA 0) {
    try {
        docker system prune -af --volumes 2>&1 | Out-Null
        Write-Log "  ✓ Docker Pruned" -Color Green
    } catch {}
}

# ============================================================================
Write-Log "[19/25] Recycle Bin" -Color Yellow
# ============================================================================
try {
    Clear-RecycleBin -Force -EA 0
    Write-Log "  ✓ Recycle Bin Emptied" -Color Green
} catch {}

# ============================================================================
Write-Log "[20/25] Search Index" -Color Yellow
# ============================================================================
Stop-Service WSearch -Force -EA 0
Start-Sleep -Seconds 1
if (Test-Path "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb") {
    Remove-Item "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb" -Force -EA 0
}
Start-Service WSearch -EA 0

# ============================================================================
Write-Log "[21/25] Windows.old" -Color Yellow
# ============================================================================
if (Test-Path "C:\Windows.old") {
    Write-Log "  ⚙ Removing Windows.old..." -Color Cyan
    try {
        takeown /F "C:\Windows.old\*" /R /A /D Y 2>&1 | Out-Null
        icacls "C:\Windows.old\*.*" /T /grant administrators:F 2>&1 | Out-Null
        Remove-Item "C:\Windows.old" -Recurse -Force -EA 0
        Write-Log "  ✓ Windows.old removed" -Color Green
    } catch {
        Write-Log "  ⚠ Windows.old removal failed" -Color Yellow
    }
}

# ============================================================================
Write-Log "[22/25] DISM Cleanup" -Color Yellow
# ============================================================================
Write-Log "  ⚙ DISM Component Cleanup (may take 5-10 min)..." -Color Cyan
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
Write-Log "  ✓ DISM Complete" -Color Green

# ============================================================================
Write-Log "[23/25] Hibernation Optimization" -Color Yellow
# ============================================================================
powercfg /h /type reduced 2>&1 | Out-Null
Write-Log "  ✓ Hibernation set to reduced" -Color Green

# ============================================================================
Write-Log "[24/25] TRIM Optimization" -Color Yellow
# ============================================================================
Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
    Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -EA 0
    Write-Log "  ✓ TRIM on $($_.DriveLetter):" -Color Green
}

# ============================================================================
Write-Log "[25/25] CompactOS" -Color Yellow
# ============================================================================
Write-Log "  ⚙ Enabling CompactOS (may take 5-10 min)..." -Color Cyan
compact /compactos:always 2>&1 | Out-Null
Write-Log "  ✓ CompactOS Complete" -Color Green

# ============================================================================
# FINAL REPORT
# ============================================================================
Write-Log ""
Write-Log "═══════════════════════════════════════════════════════════════" -Color Magenta
Write-Log "                    CLEANUP COMPLETE" -Color Magenta
Write-Log "═══════════════════════════════════════════════════════════════" -Color Magenta
Write-Log ""

$cDriveAfter = Get-PSDrive C -EA 0
if ($cDriveAfter) {
    $spaceAfter = [math]::Round($cDriveAfter.Free / 1GB, 2)
    $actualFreed = [math]::Round(($spaceAfter - $spaceBefore), 2)
    
    Write-Log "C: Drive Free Space Before: ${spaceBefore}GB" -Color White
    Write-Log "C: Drive Free Space After:  ${spaceAfter}GB" -Color White
    Write-Log "Actual Space Freed:         ${actualFreed}GB" -Color $(if($actualFreed -gt 10){'Green'}elseif($actualFreed -gt 5){'Yellow'}else{'White'})
}

Write-Log "Total Cleaned: $([math]::Round($script:TotalFreed/1GB,2))GB" -Color Cyan

$elapsed = (Get-Date) - $script:StartTime
Write-Log "Time Elapsed: $($elapsed.ToString('mm\`:ss'))" -Color White
Write-Log "Log: $($script:LogPath)" -Color DarkGray
Write-Log ""

Start-Process notepad.exe $script:LogPath
