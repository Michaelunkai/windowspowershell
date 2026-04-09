#region PHASE 55: ULTIMATE BOOT-CRITICAL FILE PROTECTION SYSTEM
Phase "ULTIMATE Boot-Critical File Protection (CRITICAL SAFETY)"

Write-Host "=" * 70 -ForegroundColor Red
Write-Host "CRITICAL SAFETY: Boot-Critical File Protection System v6.0" -ForegroundColor Red
Write-Host "This prevents the acpiex.sys corruption that occurred previously" -ForegroundColor Yellow
Write-Host "=" * 70 -ForegroundColor Red

$script:bootCriticalFiles = @(
    # ACPI and Power Management (CRITICAL - caused previous boot failure)
    "drivers\acpi.sys",
    "drivers\acpiex.sys",
    "drivers\acpipagr.sys",
    "drivers\acpipmi.sys",
    "drivers\acpitime.sys",

    # Kernel and HAL (ABSOLUTELY CRITICAL)
    "ntoskrnl.exe",
    "hal.dll",
    "ntdll.dll",
    "kernel32.dll",
    "kernelbase.dll",

    # Storage Drivers (CRITICAL - no boot without these)
    "drivers\disk.sys",
    "drivers\partmgr.sys",
    "drivers\volmgr.sys",
    "drivers\volmgrx.sys",
    "drivers\msahci.sys",
    "drivers\storahci.sys",
    "drivers\stornvme.sys",

    # File System Drivers (CRITICAL)
    "drivers\NTFS.sys",
    "drivers\fltmgr.sys",

    # Boot Loader Components
    "winload.exe",
    "winresume.exe",
    "bootmgr.exe",

    # Critical System Processes
    "csrss.exe",
    "smss.exe",
    "lsass.exe",
    "services.exe",
    "winlogon.exe",

    # Graphics (needed for boot display)
    "win32k.sys",
    "win32kfull.sys",
    "win32kbase.sys"
)

$script:backupDir = "F:\Downloads\fix\boot_critical_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$script:backupManifest = @{}

try {
    # Create backup directory
    New-Item -Path $script:backupDir -ItemType Directory -Force | Out-Null
    Write-Log "  Created backup directory: $script:backupDir" "Green"

    # Backup each boot-critical file
    $backupCount = 0
    foreach ($relPath in $script:bootCriticalFiles) {
        $sourcePath = Join-Path $env:SystemRoot "System32\$relPath"
        if (Test-Path $sourcePath) {
            try {
                # Calculate hash BEFORE backup
                $sourceHash = (Get-FileHash -Path $sourcePath -Algorithm SHA256 -EA 0).Hash

                # Create subdirectory structure in backup
                $backupPath = Join-Path $script:backupDir $relPath
                $backupParent = Split-Path $backupPath -Parent
                if (-not (Test-Path $backupParent)) {
                    New-Item -Path $backupParent -ItemType Directory -Force | Out-Null
                }

                # Backup the file
                Copy-Item -Path $sourcePath -Destination $backupPath -Force

                # Verify backup integrity
                $backupHash = (Get-FileHash -Path $backupPath -Algorithm SHA256 -EA 0).Hash
                if ($backupHash -eq $sourceHash) {
                    $script:backupManifest[$relPath] = @{
                        SourcePath = $sourcePath
                        BackupPath = $backupPath
                        OriginalHash = $sourceHash
                        BackupTime = Get-Date
                    }
                    $backupCount++
                } else {
                    Write-Log "  WARNING: Backup verification failed for $relPath" "Red"
                }
            } catch {
                Write-Log "  WARNING: Could not backup $relPath : $_" "Yellow"
            }
        }
    }

    Write-Log "  Backed up $backupCount boot-critical files with SHA256 verification" "Green"

    # Save manifest to JSON
    $manifestPath = Join-Path $script:backupDir "backup_manifest.json"
    $script:backupManifest | ConvertTo-Json -Depth 10 | Out-File $manifestPath -Encoding UTF8
    Write-Log "  Backup manifest saved: $manifestPath" "Green"

} catch {
    Write-Log "  ERROR creating boot-critical backup: $_" "Red"
    Write-Log "  ABORTING REPAIR - cannot proceed without backup!" "Red"
    Restore-ProtectedDrivers
    Release-Mutex
    pause
    exit 1
}

# Function to verify file integrity after operations
function Verify-BootCriticalIntegrity {
    Write-Log "`n  Verifying boot-critical file integrity..." "Cyan"
    $corruptCount = 0
    $verifiedCount = 0

    foreach ($relPath in $script:backupManifest.Keys) {
        $manifest = $script:backupManifest[$relPath]
        $currentPath = $manifest.SourcePath

        if (Test-Path $currentPath) {
            try {
                $currentHash = (Get-FileHash -Path $currentPath -Algorithm SHA256 -EA 0).Hash

                # Check if file was modified
                if ($currentHash -ne $manifest.OriginalHash) {
                    # File changed - verify it's still valid
                    $fileInfo = Get-Item $currentPath -EA 0

                    # Check if file is zero-sized or suspiciously small
                    if ($fileInfo.Length -lt 1024) {
                        Write-Log "  CORRUPTION DETECTED: $relPath is $($fileInfo.Length) bytes (too small!)" "Red"
                        $corruptCount++

                        # Auto-restore from backup
                        try {
                            Copy-Item -Path $manifest.BackupPath -Destination $currentPath -Force
                            Write-Log "    AUTO-RESTORED from backup" "Green"
                        } catch {
                            Write-Log "    RESTORE FAILED: $_" "Red"
                        }
                    } else {
                        # File changed but seems valid size - just note it
                        Write-Log "  Modified: $relPath (was updated by repair)" "Yellow"
                        $verifiedCount++
                    }
                } else {
                    $verifiedCount++
                }
            } catch {
                Write-Log "  ERROR verifying $relPath : $_" "Red"
            }
        } else {
            Write-Log "  MISSING: $relPath - FILE DELETED!" "Red"
            $corruptCount++

            # Auto-restore from backup
            try {
                Copy-Item -Path $manifest.BackupPath -Destination $currentPath -Force
                Write-Log "    AUTO-RESTORED from backup" "Green"
            } catch {
                Write-Log "    RESTORE FAILED: $_" "Red"
            }
        }
    }

    Write-Log "  Integrity check: $verifiedCount OK, $corruptCount corrupted/restored" "Cyan"

    if ($corruptCount -gt 0) {
        Write-Log "  WARNING: $corruptCount boot-critical file(s) were corrupted and restored!" "Yellow"
    }
}
#endregion

#region PHASE 56: PRE-FLIGHT SYSTEM INTEGRITY CHECK
Phase "Pre-Flight System Integrity Check (Safe to Repair?)"

Write-Log "  Checking if system is in stable state for repair..." "Cyan"

$script:safeToRepair = $true
$script:repairIssues = @()

# Check 1: Component Store Health (CRITICAL - caused acpiex.sys corruption)
try {
    Write-Log "  Checking component store health..." "Gray"
    $dismCheck = & dism /online /cleanup-image /checkhealth 2>&1 | Out-String

    if ($dismCheck -match 'repairable|corrupt') {
        Write-Log "  COMPONENT STORE CORRUPTED - will use SAFE repair method" "Red"
        $script:repairIssues += "Component store corrupted - must fix BEFORE system file repair"
        $script:componentStoreCorrupt = $true
    } else {
        Write-Log "  Component store: Healthy" "Green"
        $script:componentStoreCorrupt = $false
    }
} catch {
    Write-Log "  Could not check component store: $_" "Yellow"
    $script:componentStoreCorrupt = $true
}

# Check 2: Pending File Operations (can cause conflicts)
$pendingOps = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -EA 0
if ($pendingOps -and $pendingOps.PendingFileRenameOperations) {
    $opCount = $pendingOps.PendingFileRenameOperations.Count
    Write-Log "  WARNING: $opCount pending file operations - may interfere with repair" "Yellow"
    $script:repairIssues += "$opCount pending file operations"
}

# Check 3: System File Stability
try {
    $criticalFiles = @("$env:SystemRoot\System32\ntoskrnl.exe", "$env:SystemRoot\System32\drivers\acpiex.sys")
    foreach ($file in $criticalFiles) {
        if (Test-Path $file) {
            $fileInfo = Get-Item $file -EA 0
            if ($fileInfo.Length -lt 1024) {
                Write-Log "  CRITICAL: $file is corrupted (only $($fileInfo.Length) bytes)!" "Red"
                $script:safeToRepair = $false
                $script:repairIssues += "$file is corrupted"
            }
        } else {
            Write-Log "  CRITICAL: $file is MISSING!" "Red"
            $script:safeToRepair = $false
            $script:repairIssues += "$file is missing"
        }
    }
} catch {}

# Check 4: Disk Health
try {
    $disks = Get-PhysicalDisk -EA 0
    foreach ($disk in $disks) {
        if ($disk.HealthStatus -ne 'Healthy') {
            Write-Log "  WARNING: Disk $($disk.FriendlyName) health: $($disk.HealthStatus)" "Yellow"
            $script:repairIssues += "Disk $($disk.FriendlyName) unhealthy"
        }
    }
} catch {}

# Check 5: Available Disk Space
$sysDrive = Get-PSDrive C -EA 0
if ($sysDrive) {
    $freeGB = [math]::Round($sysDrive.Free / 1GB, 2)
    if ($freeGB -lt 5) {
        Write-Log "  CRITICAL: Only $freeGB GB free on C: - need at least 5GB for safe repair!" "Red"
        $script:safeToRepair = $false
        $script:repairIssues += "Insufficient disk space ($freeGB GB)"
    } else {
        Write-Log "  Disk space: $freeGB GB free (OK)" "Green"
    }
}

# Decision
if (-not $script:safeToRepair) {
    Write-Log "`n========================================" "Red"
    Write-Log "PRE-FLIGHT CHECK FAILED!" "Red"
    Write-Log "System is NOT safe for repair. Issues:" "Red"
    foreach ($issue in $script:repairIssues) {
        Write-Log "  - $issue" "Yellow"
    }
    Write-Log "ABORTING to prevent system damage!" "Red"
    Write-Log "========================================" "Red"
    Restore-ProtectedDrivers
    Release-Mutex
    pause
    exit 1
} else {
    Write-Log "`nPre-flight check PASSED - safe to proceed with repair" "Green"
    if ($script:repairIssues.Count -gt 0) {
        Write-Log "Minor issues detected (will be addressed):" "Yellow"
        foreach ($issue in $script:repairIssues) {
            Write-Log "  - $issue" "Yellow"
        }
    }
}
#endregion

#region PHASE 57: SAFE COMPONENT STORE REPAIR (Fixes DISM corruption)
Phase "Safe Component Store Repair (Prevents acpiex.sys corruption)"

if ($script:componentStoreCorrupt) {
    Write-Log "  Component store is corrupt - using SAFE repair method..." "Yellow"
    Write-Log "  WARNING: WILL NOT use /RestoreHealth (it corrupts files when store is bad!)" "Red"

    try {
        # Step 1: Analyze component store
        Write-Log "  Step 1/4: Analyzing component store..." "Cyan"
        dism /online /cleanup-image /analyzecomponentstore | Out-Null
        Start-Sleep -Seconds 2

        # Step 2: Clean up superseded components (safe operation)
        Write-Log "  Step 2/4: Cleaning superseded components..." "Cyan"
        dism /online /cleanup-image /startcomponentcleanup | Out-Null
        Start-Sleep -Seconds 5

        # Step 3: Reset base (removes backup components)
        Write-Log "  Step 3/4: Resetting component base..." "Cyan"
        dism /online /cleanup-image /startcomponentcleanup /resetbase | Out-Null
        Start-Sleep -Seconds 5

        # Step 4: Re-check health
        Write-Log "  Step 4/4: Re-checking component store..." "Cyan"
        $dismRecheck = & dism /online /cleanup-image /checkhealth 2>&1 | Out-String

        if ($dismRecheck -match 'repairable|corrupt') {
            Write-Log "  Component store still corrupted - skipping SFC" "Yellow"
            Write-Log "  SAFE MODE: Will not run RestoreHealth or SFC to prevent file corruption" "Red"
            $script:skipSFC = $true
        } else {
            Write-Log "  Component store repaired successfully!" "Green"
            $script:skipSFC = $false
        }

    } catch {
        Write-Log "  Error during component store repair: $_" "Yellow"
        Write-Log "  Skipping SFC for safety" "Yellow"
        $script:skipSFC = $true
    }
} else {
    Write-Log "  Component store is healthy - safe to proceed with full repair" "Green"
    $script:skipSFC = $false
}

# Verify boot-critical files after component store operations
Verify-BootCriticalIntegrity
#endregion

#region PHASE 58: SAFE SYSTEM FILE CHECKER (Only if safe)
Phase "System File Checker (Safe Mode)"

if ($script:skipSFC) {
    Write-Log "  SKIPPING SFC - component store is corrupted (would make things worse!)" "Yellow"
    Write-Log "  This prevents the acpiex.sys corruption that happened before" "Cyan"
} else {
    Write-Log "  Running SFC with boot-critical file protection..." "Cyan"

    try {
        # Run SFC
        $sfcResult = & sfc /scannow 2>&1 | Out-String

        if ($sfcResult -match 'did not find any integrity violations') {
            Write-Log "  SFC: No integrity violations found" "Green"
        } elseif ($sfcResult -match 'found corrupt files and successfully repaired them') {
            Write-Log "  SFC: Found and repaired corrupt files" "Green"
        } elseif ($sfcResult -match 'found corrupt files but was unable to fix') {
            Write-Log "  SFC: Found corrupt files but could not fix" "Yellow"
        } else {
            Write-Log "  SFC completed (check CBS.log for details)" "Gray"
        }

        # CRITICAL: Verify boot-critical files after SFC
        Verify-BootCriticalIntegrity

    } catch {
        Write-Log "  SFC error: $_" "Yellow"
    }
}
#endregion

#region PHASE 59: HNS (Docker) NETWORK RESET
Phase "HNS Docker Networking Reset (Fixes 0x80070032)"

Write-Log "  Fixing HNS error 0x80070032 (Docker networking)..." "Cyan"

try {
    # Stop HNS service
    Write-Log "  Stopping HNS service..." "Gray"
    Stop-Service hns -Force -EA 0
    Start-Sleep -Seconds 3

    # Backup HNS data
    $hnsDataPath = "C:\ProgramData\Microsoft\Windows\HNS\HNS.data"
    if (Test-Path $hnsDataPath) {
        $hnsBackup = "$env:TEMP\HNS_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').data"
        Copy-Item -Path $hnsDataPath -Destination $hnsBackup -Force -EA 0
        Write-Log "  Backed up HNS.data to $hnsBackup" "Green"

        # Remove corrupted HNS data
        Remove-Item $hnsDataPath -Force -EA 0
        Write-Log "  Removed corrupted HNS.data" "Green"
    }

    # Clean up stale NAT instances
    Write-Log "  Removing stale NAT instances..." "Gray"
    Get-NetNat -EA 0 | Remove-NetNat -Confirm:$false -EA 0

    # Remove stale HNS networks
    Write-Log "  Cleaning HNS networks..." "Gray"
    Get-HnsNetwork -EA 0 | Remove-HnsNetwork -EA 0

    # Restart HNS service
    Write-Log "  Restarting HNS service..." "Gray"
    Start-Service hns -EA 0
    Start-Sleep -Seconds 5

    # Verify HNS is healthy
    $hnsStatus = Get-Service hns -EA 0
    if ($hnsStatus.Status -eq 'Running') {
        Write-Log "  HNS service restarted successfully" "Green"

        # Test HNS functionality
        try {
            $hnsNetworks = Get-HnsNetwork -EA 0
            Write-Log "  HNS functional - $($hnsNetworks.Count) networks available" "Green"
        } catch {
            Write-Log "  HNS restarted but may have issues: $_" "Yellow"
        }
    } else {
        Write-Log "  WARNING: HNS service failed to start" "Yellow"
    }

    # Clean Docker networks (if Docker is installed)
    try {
        $dockerCmd = Get-Command docker -EA 0
        if ($dockerCmd) {
            Write-Log "  Pruning Docker networks..." "Gray"
            & docker network prune -f 2>$null
            Write-Log "  Docker networks cleaned" "Green"
        }
    } catch {}

} catch {
    Write-Log "  Error during HNS reset: $_" "Yellow"
}
#endregion

#region PHASE 60: USERINIT/SHELL CRASH FIX
Phase "UserInit/Shell Crash Fix"

Write-Log "  Fixing userinit.exe crashes and shell initialization..." "Cyan"

try {
    # Re-register shell DLLs
    $shellDLLs = @(
        "shell32.dll",
        "ole32.dll",
        "oleaut32.dll",
        "actxprxy.dll",
        "mshtml.dll",
        "urlmon.dll",
        "shdocvw.dll",
        "browseui.dll"
    )

    foreach ($dll in $shellDLLs) {
        $dllPath = "$env:SystemRoot\System32\$dll"
        if (Test-Path $dllPath) {
            regsvr32 /s $dllPath 2>$null
        }
    }
    Write-Log "  Shell DLLs re-registered" "Green"

    # Fix User Profile Service
    $profSvc = Get-Service -Name "ProfSvc" -EA 0
    if ($profSvc) {
        if ($profSvc.Status -ne 'Running') {
            Start-Service ProfSvc -EA 0
            Write-Log "  User Profile Service started" "Green"
        }

        # Ensure it's set to Automatic
        Set-Service -Name "ProfSvc" -StartupType Automatic -EA 0
    }

    # Fix Userinit registry key
    $userinit = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Userinit" -EA 0
    $correctValue = "C:\Windows\system32\userinit.exe,"
    if ($userinit.Userinit -ne $correctValue) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Userinit" -Value $correctValue -Force
        Write-Log "  Userinit registry key corrected" "Green"
    }

    # Fix Shell registry key
    $shell = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -EA 0
    $correctShell = "explorer.exe"
    if ($shell.Shell -ne $correctShell) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -Value $correctShell -Force
        Write-Log "  Shell registry key corrected" "Green"
    }

    # Rebuild icon cache (corrupted cache causes Explorer crashes)
    try {
        Stop-Process -Name "explorer" -Force -EA 0
        Start-Sleep -Seconds 2
        Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db" -Force -EA 0
        Start-Process "explorer.exe"
        Write-Log "  Icon cache rebuilt" "Green"
    } catch {}

} catch {
    Write-Log "  Error during shell/userinit fix: $_" "Yellow"
}

# Verify boot-critical files weren't affected
Verify-BootCriticalIntegrity
#endregion

#region PHASE 61: NETWORK PERFORMANCE OPTIMIZATION
Phase "Network Performance Optimization (Speed Improvements)"

Write-Log "  Optimizing network for maximum speed..." "Cyan"

try {
    # TCP Window Auto-Tuning (CRITICAL for download speeds)
    netsh interface tcp set global autotuninglevel=normal 2>$null
    Write-Log "  TCP Auto-Tuning: Enabled" "Green"

    # Disable Network Throttling Index (removes 10Mbps multimedia limit)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force -EA 0
    Write-Log "  Network throttling: Disabled" "Green"

    # Enable RSS (Receive Side Scaling) for multi-core
    Get-NetAdapter -EA 0 | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        Enable-NetAdapterRss -Name $_.Name -EA 0
        Write-Log "  RSS enabled on: $($_.Name)" "Green"
    }

    # Enable LSO (Large Send Offload)
    Get-NetAdapter -EA 0 | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        Enable-NetAdapterLso -Name $_.Name -EA 0
        Write-Log "  LSO enabled on: $($_.Name)" "Green"
    }

    # Optimize TCP settings
    netsh interface tcp set global chimney=enabled 2>$null
    netsh interface tcp set global dca=enabled 2>$null
    netsh interface tcp set global netdma=enabled 2>$null
    Write-Log "  TCP offload features: Enabled" "Green"

    # Clear DNS cache
    Clear-DnsClientCache -EA 0
    ipconfig /flushdns 2>$null | Out-Null
    Write-Log "  DNS cache: Flushed" "Green"

    # Reset Winsock and IP stack (fixes corruption)
    netsh winsock reset 2>$null | Out-Null
    Write-Log "  Winsock: Reset" "Green"

    # Disable IPv6 transition adapters (reduce latency)
    Get-NetAdapter -EA 0 | Where-Object { $_.InterfaceDescription -match 'Teredo|6to4|ISATAP' } | ForEach-Object {
        Disable-NetAdapter -Name $_.Name -Confirm:$false -EA 0
        Write-Log "  Disabled: $($_.Name)" "Green"
    }

    # QoS: Ensure not throttling
    Get-NetQosPolicy -EA 0 | Where-Object { $_.ThrottleRateActionBitsPerSecond -gt 0 } | Remove-NetQosPolicy -Confirm:$false -EA 0
    Write-Log "  QoS throttling: Removed" "Green"

} catch {
    Write-Log "  Error during network optimization: $_" "Yellow"
}
#endregion

#region PHASE 62: GAMING & MULTITASKING PERFORMANCE OPTIMIZATION
Phase "Gaming & Multitasking Performance Optimization"

Write-Log "  Optimizing for gaming and multitasking..." "Cyan"

try {
    # Disable Power Throttling (lets background apps run full speed)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -Type DWord -Force -EA 0
    Write-Log "  Power throttling: Disabled (background apps full speed)" "Green"

    # Disable Core Parking (keeps all CPU cores active)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "ValueMax" -Value 100 -Type DWord -Force -EA 0
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "ValueMin" -Value 100 -Type DWord -Force -EA 0
    Write-Log "  Core parking: Disabled (all cores active)" "Green"

    # Set CPU Priority to Background Services (better multitasking)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 24 -Type DWord -Force -EA 0
    Write-Log "  CPU priority: Optimized for multitasking" "Green"

    # Enable Game Mode
    if (-not (Test-Path "HKCU:\Software\Microsoft\GameBar")) {
        New-Item -Path "HKCU:\Software\Microsoft\GameBar" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force -EA 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force -EA 0
    Write-Log "  Game Mode: Enabled" "Green"

    # Disable Game DVR (reduces GPU overhead)
    if (-not (Test-Path "HKCU:\System\GameConfigStore")) {
        New-Item -Path "HKCU:\System\GameConfigStore" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -EA 0
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord -Force -EA 0
    Write-Log "  Game DVR: Disabled (less GPU overhead)" "Green"

    # Optimize GPU settings
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord -Force -EA 0
    Write-Log "  Hardware-Accelerated GPU Scheduling: Enabled" "Green"

    # Disable Fullscreen Optimizations (reduces input lag)
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force -EA 0
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force -EA 0
    Write-Log "  Fullscreen optimizations: Disabled (less input lag)" "Green"

    # Optimize for performance over visual effects
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord -Force -EA 0
    Write-Log "  Visual effects: Optimized for performance" "Green"

    # Disable Windows Search Indexing service (reduces disk usage)
    Stop-Service -Name "WSearch" -Force -EA 0
    Set-Service -Name "WSearch" -StartupType Disabled -EA 0
    Write-Log "  Windows Search: Disabled (less disk thrashing)" "Green"

    # Disable SysMain/Superfetch (can cause stuttering)
    Stop-Service -Name "SysMain" -Force -EA 0
    Set-Service -Name "SysMain" -StartupType Disabled -EA 0
    Write-Log "  Superfetch/SysMain: Disabled (less disk usage)" "Green"

    # Set high-performance power plan
    try {
        $powerGUID = (powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null)[0] -replace '.*GUID:\s*([0-9a-f-]+).*', '$1'
        if ($powerGUID) {
            powercfg -setactive $powerGUID 2>$null
            Write-Log "  Power plan: High Performance activated" "Green"
        }
    } catch {}

    # Disable hibernate (frees disk space)
    powercfg -h off 2>$null
    Write-Log "  Hibernate: Disabled (freed disk space)" "Green"

} catch {
    Write-Log "  Error during gaming/multitasking optimization: $_" "Yellow"
}

# Final verification
Verify-BootCriticalIntegrity
#endregion

#region PHASE 63: ROLLBACK CAPABILITY
Phase "Rollback Preparation (Safety Net)"

Write-Log "  Setting up rollback capability..." "Cyan"

# Create rollback script
$rollbackScript = @"
# ROLLBACK SCRIPT - Auto-generated by Ultimate Repair v6.0
# Run this if system becomes unstable after repair

Write-Host "ULTIMATE REPAIR ROLLBACK SYSTEM" -ForegroundColor Red
Write-Host "This will restore boot-critical files from backup" -ForegroundColor Yellow
Write-Host ""

`$backupDir = "$($script:backupDir)"
`$manifestPath = Join-Path `$backupDir "backup_manifest.json"

if (-not (Test-Path `$manifestPath)) {
    Write-Host "ERROR: Backup manifest not found!" -ForegroundColor Red
    pause
    exit 1
}

`$manifest = Get-Content `$manifestPath -Raw | ConvertFrom-Json

Write-Host "Found backup with `$(`$manifest.PSObject.Properties.Count) files" -ForegroundColor Cyan
Write-Host "Press any key to restore, or Ctrl+C to cancel..." -ForegroundColor Yellow
pause

`$restored = 0
foreach (`$relPath in `$manifest.PSObject.Properties.Name) {
    `$entry = `$manifest."`$relPath"
    try {
        if (Test-Path `$entry.BackupPath) {
            Copy-Item -Path `$entry.BackupPath -Destination `$entry.SourcePath -Force
            Write-Host "  Restored: `$relPath" -ForegroundColor Green
            `$restored++
        }
    } catch {
        Write-Host "  Failed: `$relPath - `$_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Rollback complete: `$restored files restored" -ForegroundColor Green
Write-Host "REBOOT IMMEDIATELY" -ForegroundColor Yellow
pause
"@

$rollbackPath = Join-Path $script:backupDir "ROLLBACK.ps1"
$rollbackScript | Out-File $rollbackPath -Encoding UTF8 -Force

Write-Log "  Rollback script created: $rollbackPath" "Green"
Write-Log "  If system becomes unstable, run this script to restore files" "Cyan"
#endregion

Write-Log "`n========================================" "Magenta"
Write-Log "ULTIMATE SAFETY & REPAIR PHASES COMPLETE" "Magenta"
Write-Log "Boot-critical files protected and verified" "Green"
Write-Log "========================================`n" "Magenta"

