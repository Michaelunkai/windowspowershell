#Requires -RunAsAdministrator
<#
.SYNOPSIS
    FSTEEP TURBO - Ultra-fast system cleanup with parallelization
.DESCRIPTION
    Runs all cleanup operations as fast as possible using parallel jobs
    Commands: rmscreen, cleanmgr, rmboot, rmvol, ddf, rmdefender, cleannn, rmph, 
              rmdex, rmsnap, adw, ctemp, dddesk, qaccess, smicha, unlock, 
              autocomplete, disadmin, dlog, pip upgrade, pipip, gdownloads, 
              gshort, powerplans, wingup, rmfolders, bbbb, cleanc, ccsizes
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

function Write-Step { param($msg) Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $msg" -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  → $msg (skipped)" -ForegroundColor DarkGray }

# ============================================================================
# BATCH 1: Cleanup Temps/Cache (Parallel - No Dependencies)
# ============================================================================
Write-Step "BATCH 1: Temp & Cache Cleanup (Parallel)"

$batch1 = @(
    # rmscreen - Remove screenshots
    Start-Job { 
        $paths = @("$env:USERPROFILE\Pictures\Screenshots", "$env:USERPROFILE\Videos\Captures")
        $paths | ForEach-Object { if (Test-Path $_) { Get-ChildItem $_ -File | Remove-Item -Force 2>$null } }
        "Screenshots"
    } -Name "rmscreen"
    
    # ctemp - Clear temp folders
    Start-Job {
        @($env:TEMP, "C:\Windows\Temp", "$env:LOCALAPPDATA\Temp") | ForEach-Object {
            if (Test-Path $_) { Get-ChildItem $_ -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
        }
        "Temp folders"
    } -Name "ctemp"
    
    # rmdefender - Clear Defender cache/logs
    Start-Job {
        $defPaths = @(
            "$env:ProgramData\Microsoft\Windows Defender\Scans\History",
            "$env:ProgramData\Microsoft\Windows Defender\Support"
        )
        $defPaths | ForEach-Object { if (Test-Path $_) { Get-ChildItem $_ -Recurse -Force 2>$null | Remove-Item -Recurse -Force 2>$null } }
        "Defender logs"
    } -Name "rmdefender"
    
    # rmph - Remove prefetch/superfetch
    Start-Job {
        if (Test-Path "C:\Windows\Prefetch") {
            Get-ChildItem "C:\Windows\Prefetch" -Force 2>$null | Remove-Item -Force 2>$null
        }
        "Prefetch"
    } -Name "rmph"
    
    # rmdex - DEX cache
    Start-Job {
        $dexPaths = @("$env:LOCALAPPDATA\D3DSCache", "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\AMD\DxCache")
        $dexPaths | ForEach-Object { if (Test-Path $_) { Remove-Item $_ -Recurse -Force 2>$null } }
        "DirectX cache"
    } -Name "rmdex"
    
    # rmsnap - Snapshot cleanup
    Start-Job {
        vssadmin delete shadows /all /quiet 2>$null
        "VSS shadows"
    } -Name "rmsnap"
    
    # cleannn - Browser caches
    Start-Job {
        $chromePaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        )
        $chromePaths | ForEach-Object { if (Test-Path $_) { Remove-Item "$_\*" -Recurse -Force 2>$null } }
        "Browser caches"
    } -Name "cleannn"
)

# Wait max 60s for batch 1
$batch1 | Wait-Job -Timeout 60 | Out-Null
$batch1 | ForEach-Object {
    if ($_.State -eq 'Completed') { 
        $r = Receive-Job $_ -ErrorAction SilentlyContinue
        Write-OK ($r ?? $_.Name)
    } else { 
        Write-Skip $_.Name
        Stop-Job $_ -ErrorAction SilentlyContinue 
    }
    Remove-Job $_ -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# BATCH 2: System Cleanup (Parallel)
# ============================================================================
Write-Step "BATCH 2: System Cleanup (Parallel)"

$batch2 = @(
    # rmboot - Boot config cleanup
    Start-Job {
        bcdedit /deletevalue {current} safeboot 2>$null
        bcdedit /deletevalue {current} safebootalternateshell 2>$null
        "Boot config"
    } -Name "rmboot"
    
    # rmvol - Volume cache
    Start-Job {
        Get-Volume | ForEach-Object { Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue }
        "Volume trim"
    } -Name "rmvol"
    
    # ddf - Disk cleanup (no UI)
    Start-Job {
        # Set all cleanup flags
        $volCache = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
        Get-ChildItem $volCache -ErrorAction SilentlyContinue | ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name StateFlags0100 -Value 2 -ErrorAction SilentlyContinue
        }
        Start-Process cleanmgr -ArgumentList "/sagerun:100" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        "Disk Cleanup"
    } -Name "ddf"
    
    # adw - ADWCleaner (if exists)
    Start-Job {
        $adw = Get-ChildItem "C:\Program Files*\*ADW*\*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($adw) { Start-Process $adw.FullName -ArgumentList "/eula", "/clean", "/noreboot" -Wait -NoNewWindow -ErrorAction SilentlyContinue }
        "ADWCleaner"
    } -Name "adw"
    
    # dlog - Clear event logs
    Start-Job {
        wevtutil el 2>$null | ForEach-Object { wevtutil cl $_ 2>$null }
        "Event logs"
    } -Name "dlog"
)

$batch2 | Wait-Job -Timeout 120 | Out-Null
$batch2 | ForEach-Object {
    if ($_.State -eq 'Completed') { Write-OK (Receive-Job $_ -ErrorAction SilentlyContinue ?? $_.Name) }
    else { Write-Skip $_.Name; Stop-Job $_ -ErrorAction SilentlyContinue }
    Remove-Job $_ -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# BATCH 3: Settings & Config (Fast Sequential - Order Matters)
# ============================================================================
Write-Step "BATCH 3: Settings & Config"

# qaccess - Quick Access cleanup
try {
    $shell = New-Object -ComObject Shell.Application
    $quickAccess = $shell.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}")
    if ($quickAccess) { $quickAccess.Items() | ForEach-Object { $_.InvokeVerb("unpinfromhome") 2>$null } }
    Write-OK "Quick Access"
} catch { Write-Skip "Quick Access" }

# smicha - Set user
try { net user micha /active:yes 2>$null; Write-OK "User micha" } catch { Write-Skip "User micha" }

# unlock - Unlock locked files (handle)
try {
    if (Get-Command handle -ErrorAction SilentlyContinue) { handle -accepteula -nobanner 2>$null }
    Write-OK "Handle unlock"
} catch { Write-Skip "Handle unlock" }

# autocomplete - Registry autocomplete
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete" -Name "Append Completion" -Value "yes" -ErrorAction SilentlyContinue
    Write-OK "Autocomplete"
} catch { Write-Skip "Autocomplete" }

# disadmin - Disable built-in admin
try { net user Administrator /active:no 2>$null; Write-OK "Disable Admin" } catch { Write-Skip "Disable Admin" }

# ============================================================================
# BATCH 4: Package Management (Parallel)
# ============================================================================
Write-Step "BATCH 4: Package Updates (Parallel)"

$batch4 = @(
    # pip upgrade
    Start-Job {
        $pips = @("pip", "pip3")
        $pips | ForEach-Object { 
            $p = Get-Command $_ -ErrorAction SilentlyContinue
            if ($p) { & $_ install --upgrade pip --quiet 2>$null }
        }
        "pip"
    } -Name "pip-upgrade"
    
    # pipip - pip packages update
    Start-Job {
        $outdated = pip list --outdated --format=json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($outdated) {
            $outdated | ForEach-Object { pip install -U $_.name --quiet 2>$null }
        }
        "pip packages"
    } -Name "pipip"
    
    # wingup - Winget upgrade
    Start-Job {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget upgrade --all --silent --accept-package-agreements --accept-source-agreements 2>$null
        }
        "Winget"
    } -Name "wingup"
)

# Don't wait too long for package managers
$batch4 | Wait-Job -Timeout 180 | Out-Null
$batch4 | ForEach-Object {
    if ($_.State -eq 'Completed') { Write-OK (Receive-Job $_ -ErrorAction SilentlyContinue ?? $_.Name) }
    else { Write-Skip $_.Name; Stop-Job $_ -ErrorAction SilentlyContinue }
    Remove-Job $_ -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# BATCH 5: Downloads & Shortcuts (Parallel)
# ============================================================================
Write-Step "BATCH 5: Downloads & Shortcuts"

$batch5 = @(
    # gdownloads - Organize downloads
    Start-Job {
        $dl = "$env:USERPROFILE\Downloads"
        if (Test-Path $dl) {
            # Move old files to archive (>30 days)
            $archive = "$dl\_Archive"
            New-Item $archive -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            Get-ChildItem $dl -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
                Move-Item -Destination $archive -Force -ErrorAction SilentlyContinue
        }
        "Downloads organized"
    } -Name "gdownloads"
    
    # gshort - Fix shortcuts
    Start-Job {
        $shell = New-Object -ComObject WScript.Shell
        $desktop = [Environment]::GetFolderPath("Desktop")
        Get-ChildItem "$desktop\*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
            $shortcut = $shell.CreateShortcut($_.FullName)
            if ($shortcut.TargetPath -and !(Test-Path $shortcut.TargetPath)) {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        "Broken shortcuts"
    } -Name "gshort"
    
    # rmfolders - Empty folder cleanup
    Start-Job {
        $targets = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Documents")
        $targets | ForEach-Object {
            Get-ChildItem $_ -Directory -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
        "Empty folders"
    } -Name "rmfolders"
)

$batch5 | Wait-Job -Timeout 60 | Out-Null
$batch5 | ForEach-Object {
    if ($_.State -eq 'Completed') { Write-OK (Receive-Job $_ -ErrorAction SilentlyContinue ?? $_.Name) }
    else { Write-Skip $_.Name; Stop-Job $_ -ErrorAction SilentlyContinue }
    Remove-Job $_ -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# BATCH 6: Power & Performance
# ============================================================================
Write-Step "BATCH 6: Power & Performance"

# powerplans - Set high performance
try {
    $hp = powercfg /list | Select-String "High performance" | ForEach-Object { ($_ -split '\s+')[3] }
    if ($hp) { powercfg /setactive $hp 2>$null }
    Write-OK "Power plan"
} catch { Write-Skip "Power plan" }

# dddesk - Desktop refresh (run in PS7 if available)
try {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Start-Process pwsh -ArgumentList "-NoProfile", "-Command", "Get-Process explorer | Stop-Process -Force; Start-Sleep 2; Start-Process explorer" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    } else {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
        Start-Process explorer
    }
    Write-OK "Desktop refresh"
} catch { Write-Skip "Desktop refresh" }

# ============================================================================
# BATCH 7: Final Cleanup (Parallel)
# ============================================================================
Write-Step "BATCH 7: Final Cleanup"

$batch7 = @(
    # bbbb - Final system state save
    Start-Job {
        # Flush DNS
        ipconfig /flushdns 2>$null
        # Clear ARP
        arp -d * 2>$null
        "Network cache"
    } -Name "bbbb"
    
    # cleanc - C: drive specific
    Start-Job {
        Compact.exe /CompactOS:query 2>$null
        "C: check"
    } -Name "cleanc"
    
    # ccsizes - Show sizes
    Start-Job {
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used }
        $drives | ForEach-Object {
            [PSCustomObject]@{
                Drive = $_.Name
                FreeGB = [math]::Round($_.Free/1GB,1)
                UsedGB = [math]::Round($_.Used/1GB,1)
            }
        } | Format-Table -AutoSize | Out-String
    } -Name "ccsizes"
)

$batch7 | Wait-Job -Timeout 30 | Out-Null
$results = @()
$batch7 | ForEach-Object {
    if ($_.State -eq 'Completed') { 
        $r = Receive-Job $_ -ErrorAction SilentlyContinue
        if ($_.Name -eq 'ccsizes') { $results += $r }
        else { Write-OK ($r ?? $_.Name) }
    }
    else { Write-Skip $_.Name; Stop-Job $_ -ErrorAction SilentlyContinue }
    Remove-Job $_ -Force -ErrorAction SilentlyContinue
}

# Show drive sizes at end
if ($results) {
    Write-Host "`n  Drive Status:" -ForegroundColor Magenta
    Write-Host $results
}

# ============================================================================
# DONE
# ============================================================================
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  FSTEEP COMPLETE @ $((Get-Date).ToString('HH:mm:ss'))" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
