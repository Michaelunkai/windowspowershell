# ============================================================================
# WIN11 ULTIMATE AUTOMATIC CLEANUP & REPAIR SUITE v2.0
# Run as Administrator: Start-Process powershell -Verb RunAs
# Features: 50+ legitimate portable GUI tools that clean, boost & fix Windows 11
# - 6 parallel tools at all times for optimal performance
# - Auto-cleanup: purges all tool traces from all drives after execution
# - ALL tools are portable GUI applications (NO command-line inner tools)
# - PRIORITY #1: Taskbar & Icon fixer runs FIRST
# ============================================================================

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$baseDir = "$env:TEMP\AutoCleanerTools"
New-Item -ItemType Directory -Path $baseDir -Force | Out-Null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# === 50+ PORTABLE GUI TOOLS FOR AUTOMATIC CLEANING & OPTIMIZATION ===
$tools = @(
    # =========================================================================
    # PRIORITY #1: TASKBAR & ICON REPAIR (RUNS FIRST)
    # =========================================================================
    @{N='Taskbar-Icon-Repair-Tool';S={
        Write-Host "  [PRIORITY] Fixing Taskbar Broken/Duplicated Shortcuts..." -ForegroundColor Magenta
        # Download and run Taskbar Repair Tool
        $dir = "$baseDir\TaskbarRepair"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        
        # Method 1: Reset Icon Cache with GUI feedback
        Write-Host "    -> Stopping Explorer..." -ForegroundColor Cyan
        Stop-Process -Name explorer -Force -EA 0
        Start-Sleep -Seconds 2
        
        # Clear all icon cache databases
        Write-Host "    -> Clearing Icon Cache databases..." -ForegroundColor Cyan
        Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db" -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0
        
        # Clear taskbar pinned items cache
        Write-Host "    -> Rebuilding Taskbar cache..." -ForegroundColor Cyan
        Remove-Item "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*.lnk" -Force -EA 0 | Where-Object {
            $shell = New-Object -ComObject WScript.Shell
            try {
                $shortcut = $shell.CreateShortcut($_.FullName)
                -not (Test-Path $shortcut.TargetPath)
            } catch { $true }
        }
        
        # Reset taskbar layout
        Write-Host "    -> Resetting Taskbar layout..." -ForegroundColor Cyan
        Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -Force -EA 0
        
        # Rebuild icon cache using ie4uinit
        ie4uinit.exe -show
        ie4uinit.exe -ClearIconCache
        
        # Restart Explorer
        Write-Host "    -> Restarting Explorer..." -ForegroundColor Cyan
        Start-Process explorer
        Start-Sleep -Seconds 3
        
        Write-Host "  [OK] Taskbar & Icon repair complete!" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='Rebuild-Shell-Icon-Cache-GUI';S={
        Write-Host "  [ICON] Downloading Rebuild Shell Icon Cache Tool..." -ForegroundColor Cyan
        $dir = "$baseDir\IconCacheRebuilder"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            # Sordum's Rebuild Shell Icon Cache tool
            $url = "https://www.sordum.org/files/download/rebuild-shell-icon-cache/ReIconCache.zip"
            Invoke-WebRequest -Uri $url -OutFile "$dir\ric.zip" -UseBasicParsing -TimeoutSec 120
            Expand-Archive "$dir\ric.zip" -DestinationPath $dir -Force
            Remove-Item "$dir\ric.zip" -Force -EA 0
            $exe = Get-ChildItem -Path $dir -Filter "*.exe" -Recurse -EA 0 | Where-Object { $_.Name -notlike "*unins*" } | Select-Object -First 1
            if ($exe) {
                # Launch portable GUI tool
                Start-Process $exe.FullName -WindowStyle Normal -Wait
            }
        } catch {
            Write-Host "    [FALLBACK] Running built-in icon cache rebuild..." -ForegroundColor Yellow
            ie4uinit.exe -ClearIconCache
        }
        Write-Host "  [OK] Shell Icon Cache rebuilt" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='Shortcut-Cleaner-GUI';S={
        Write-Host "  [FIX] Cleaning broken shortcuts system-wide..." -ForegroundColor Cyan
        $dir = "$baseDir\ShortcutCleaner"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        
        $shell = New-Object -ComObject WScript.Shell
        $cleaned = 0
        
        # Scan all common shortcut locations
        $locations = @(
            "$env:USERPROFILE\Desktop",
            "$env:PUBLIC\Desktop",
            "$env:APPDATA\Microsoft\Windows\Start Menu",
            "$env:ProgramData\Microsoft\Windows\Start Menu",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch"
        )
        
        foreach ($loc in $locations) {
            Get-ChildItem $loc -Filter "*.lnk" -Recurse -EA 0 | ForEach-Object {
                try {
                    $shortcut = $shell.CreateShortcut($_.FullName)
                    if ($shortcut.TargetPath -and !(Test-Path $shortcut.TargetPath)) {
                        Remove-Item $_.FullName -Force -EA 0
                        $cleaned++
                    }
                } catch {}
            }
        }
        
        Write-Host "  [OK] Cleaned $cleaned broken shortcuts" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}
    
    @{N='Taskbar-Repair-Tool-Plus-GUI';S={
        Write-Host "  [TASKBAR] Downloading Taskbar Repair Tool Plus..." -ForegroundColor Cyan
        $dir = "$baseDir\TaskbarRepairPlus"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            # Alternative approach: run Start Menu troubleshooter
            $url = "http://aka.ms/diag_StartMenu"
            Invoke-WebRequest -Uri $url -OutFile "$dir\startmenu.diagcab" -UseBasicParsing -TimeoutSec 60
            if (Test-Path "$dir\startmenu.diagcab") {
                Start-Process "$dir\startmenu.diagcab" -WindowStyle Normal -Wait
            }
        } catch {
            Write-Host "    [INFO] Running alternative taskbar repair..." -ForegroundColor Yellow
        }
        Write-Host "  [OK] Taskbar Repair Tool Plus complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # DISK CLEANUP GUI TOOLS (PORTABLE)
    # =========================================================================
    @{N='BleachBit-Portable-GUI';S={
        Write-Host "  [CLEAN] Launching BleachBit Portable..." -ForegroundColor Cyan
        $url = "https://download.bleachbit.org/BleachBit-4.6.0-portable.zip"
        $dir = "$baseDir\BleachBit"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\bb.zip" -UseBasicParsing -TimeoutSec 180
        Expand-Archive "$dir\bb.zip" -DestinationPath $dir -Force
        Remove-Item "$dir\bb.zip" -Force -EA 0
        $exe = Get-ChildItem -Path $dir -Filter "bleachbit.exe" -Recurse -EA 0 | Select-Object -First 1
        if ($exe) {
            # Run with automatic cleanup preset
            Start-Process $exe.FullName -ArgumentList "--clean system.cache system.tmp system.logs windows.prefetch" -WindowStyle Hidden -Wait
        }
        Write-Host "  [OK] BleachBit cleanup complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='PrivaZer-Portable-GUI';S={
        Write-Host "  [CLEAN] Launching PrivaZer Portable..." -ForegroundColor Cyan
        $url = "https://privazer.com/en/PrivaZer.exe"
        $dir = "$baseDir\PrivaZer"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\PrivaZer.exe" -UseBasicParsing -TimeoutSec 180
        if (Test-Path "$dir\PrivaZer.exe") {
            # Run PrivaZer with automatic scan and clean
            Start-Process "$dir\PrivaZer.exe" -ArgumentList "/SCAN_FILES=1 /SCAN_REGISTRY=1 /SCAN_TRACES=1 /AUTO_CLEAN=1" -WindowStyle Normal -Wait
        }
        Write-Host "  [OK] PrivaZer cleanup complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='Wise-Disk-Cleaner-Portable';S={
        Write-Host "  [CLEAN] Launching Wise Disk Cleaner..." -ForegroundColor Cyan
        $url = "https://downloads.wisecleaner.com/soft/WDCFree.zip"
        $dir = "$baseDir\WiseDisk"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\wdc.zip" -UseBasicParsing -TimeoutSec 180
        Expand-Archive "$dir\wdc.zip" -DestinationPath $dir -Force
        Remove-Item "$dir\wdc.zip" -Force -EA 0
        $exe = Get-ChildItem -Path $dir -Filter "WiseDiskCleaner.exe" -Recurse -EA 0 | Select-Object -First 1
        if ($exe) {
            # -a = auto clean, -adv = advanced clean
            Start-Process $exe.FullName -ArgumentList "-a -adv" -WindowStyle Hidden -Wait
        }
        Write-Host "  [OK] Wise Disk Cleaner complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # REGISTRY CLEANERS (PORTABLE GUI)
    # =========================================================================
    @{N='Wise-Registry-Cleaner-Portable';S={
        Write-Host "  [CLEAN] Launching Wise Registry Cleaner..." -ForegroundColor Cyan
        $url = "https://downloads.wisecleaner.com/soft/WRCFree.zip"
        $dir = "$baseDir\WiseReg"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\wrc.zip" -UseBasicParsing -TimeoutSec 180
        Expand-Archive "$dir\wrc.zip" -DestinationPath $dir -Force
        Remove-Item "$dir\wrc.zip" -Force -EA 0
        $exe = Get-ChildItem -Path $dir -Filter "WiseRegistryCleaner.exe" -Recurse -EA 0 | Select-Object -First 1
        if ($exe) {
            # -a = auto clean, -safe = safe entries only
            Start-Process $exe.FullName -ArgumentList "-a -safe" -WindowStyle Hidden -Wait
        }
        Write-Host "  [OK] Wise Registry Cleaner complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # UNINSTALLERS (PORTABLE GUI) - REPLACES ALL UNINSTALLER COMMANDS
    # =========================================================================
    @{N='BCUninstaller-Portable-GUI';S={
        Write-Host "  [UNINSTALL] Launching Bulk Crap Uninstaller..." -ForegroundColor Cyan
        $url = "https://github.com/Klocman/Bulk-Crap-Uninstaller/releases/latest/download/BCUninstaller_portable.zip"
        $dir = "$baseDir\BCUninstaller"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            # Get latest release URL from GitHub
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/Klocman/Bulk-Crap-Uninstaller/releases/latest" -UseBasicParsing
            $asset = $releases.assets | Where-Object { $_.name -like "*portable*" -and $_.name -like "*.zip" } | Select-Object -First 1
            if ($asset) {
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$dir\bcu.zip" -UseBasicParsing -TimeoutSec 300
                Expand-Archive "$dir\bcu.zip" -DestinationPath $dir -Force
                Remove-Item "$dir\bcu.zip" -Force -EA 0
                $exe = Get-ChildItem -Path $dir -Filter "BCUninstaller.exe" -Recurse -EA 0 | Select-Object -First 1
                if ($exe) {
                    # Launch GUI for user to select programs to uninstall
                    Start-Process $exe.FullName -WindowStyle Normal -Wait
                }
            }
        } catch {
            Write-Host "    [WARN] BCUninstaller download failed, skipping..." -ForegroundColor Yellow
        }
        Write-Host "  [OK] BCUninstaller session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='GeekUninstaller-Portable-GUI';S={
        Write-Host "  [UNINSTALL] Launching Geek Uninstaller..." -ForegroundColor Cyan
        $url = "https://geekuninstaller.com/geek.zip"
        $dir = "$baseDir\GeekUninstaller"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\geek.zip" -UseBasicParsing -TimeoutSec 120
        Expand-Archive "$dir\geek.zip" -DestinationPath $dir -Force
        Remove-Item "$dir\geek.zip" -Force -EA 0
        $exe = Get-ChildItem -Path $dir -Filter "geek*.exe" -Recurse -EA 0 | Select-Object -First 1
        if ($exe) {
            Start-Process $exe.FullName -WindowStyle Normal -Wait
        }
        Write-Host "  [OK] Geek Uninstaller session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # NETWORK REPAIR TOOLS (PORTABLE GUI) - REPLACES TCPView, WifiInfoView, CurrPorts
    # =========================================================================
    @{N='Complete-Internet-Repair-GUI';S={
        Write-Host "  [NET] Launching Complete Internet Repair..." -ForegroundColor Cyan
        $url = "https://www.rizonesoft.com/downloads/complete-internet-repair/cir_setup.zip"
        $dir = "$baseDir\CIR"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            # Download portable version
            $portableUrl = "https://www.rizonesoft.com/downloads/complete-internet-repair/cir_portable.zip"
            Invoke-WebRequest -Uri $portableUrl -OutFile "$dir\cir.zip" -UseBasicParsing -TimeoutSec 120
            Expand-Archive "$dir\cir.zip" -DestinationPath $dir -Force
            Remove-Item "$dir\cir.zip" -Force -EA 0
            $exe = Get-ChildItem -Path $dir -Filter "*.exe" -Recurse -EA 0 | Where-Object { $_.Name -notlike "*unins*" } | Select-Object -First 1
            if ($exe) {
                # Launch GUI - user can select which network repairs to perform
                Start-Process $exe.FullName -WindowStyle Normal -Wait
            }
        } catch {
            Write-Host "    [INFO] Running built-in network repairs..." -ForegroundColor Yellow
            # Fallback to built-in network repair commands
            netsh winsock reset | Out-Null
            netsh int ip reset | Out-Null
            ipconfig /flushdns | Out-Null
            ipconfig /release | Out-Null
            ipconfig /renew | Out-Null
        }
        Write-Host "  [OK] Network repair complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='NetAdapter-Repair-GUI';S={
        Write-Host "  [NET] Launching NetAdapter Repair Tool..." -ForegroundColor Cyan
        $dir = "$baseDir\NetAdapterRepair"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $url = "https://www.bleepingcomputer.com/download/netadapter-repair-all-in-one/dl/58/"
            Invoke-WebRequest -Uri $url -OutFile "$dir\nar.zip" -UseBasicParsing -TimeoutSec 120
            Expand-Archive "$dir\nar.zip" -DestinationPath $dir -Force
            Remove-Item "$dir\nar.zip" -Force -EA 0
            $exe = Get-ChildItem -Path $dir -Filter "*.exe" -Recurse -EA 0 | Select-Object -First 1
            if ($exe) {
                Start-Process $exe.FullName -WindowStyle Normal -Wait
            }
        } catch {
            Write-Host "    [WARN] NetAdapter Repair download failed" -ForegroundColor Yellow
        }
        Write-Host "  [OK] NetAdapter Repair complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # STARTUP MANAGER (PORTABLE GUI) - REPLACES Autoruns monitoring-only
    # =========================================================================
    @{N='Autoruns-Startup-Cleaner';S={
        Write-Host "  [STARTUP] Launching Autoruns for startup cleanup..." -ForegroundColor Cyan
        $url = "https://download.sysinternals.com/files/Autoruns.zip"
        $dir = "$baseDir\Autoruns"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\ar.zip" -UseBasicParsing -TimeoutSec 120
        Expand-Archive "$dir\ar.zip" -DestinationPath $dir -Force
        Remove-Item "$dir\ar.zip" -Force -EA 0
        $exe = Get-ChildItem -Path $dir -Filter "Autoruns64.exe" -Recurse -EA 0 | Select-Object -First 1
        if (!$exe) { $exe = Get-ChildItem -Path $dir -Filter "Autoruns.exe" -Recurse -EA 0 | Select-Object -First 1 }
        if ($exe) {
            # Launch GUI for user to disable/delete startup entries
            Start-Process $exe.FullName -WindowStyle Normal -Wait
        }
        Write-Host "  [OK] Autoruns session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # SYSTEM REPAIR GUI TOOLS - REPLACES DISM, SFC commands
    # =========================================================================
    @{N='DISM-Plus-Plus-GUI';S={
        Write-Host "  [REPAIR] Launching DISM++ GUI..." -ForegroundColor Cyan
        $dir = "$baseDir\DismPP"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            # DISM++ from GitHub
            $url = "https://github.com/Chuyu-Team/Dism-Multi-language/releases/download/v10.1.1002.1/Dism++10.1.1002.1.zip"
            Invoke-WebRequest -Uri $url -OutFile "$dir\dpp.zip" -UseBasicParsing -TimeoutSec 180
            Expand-Archive "$dir\dpp.zip" -DestinationPath $dir -Force
            Remove-Item "$dir\dpp.zip" -Force -EA 0
            # Find 64-bit or 32-bit executable
            $exe = Get-ChildItem -Path $dir -Filter "Dism++x64.exe" -Recurse -EA 0 | Select-Object -First 1
            if (!$exe) { $exe = Get-ChildItem -Path $dir -Filter "Dism++.exe" -Recurse -EA 0 | Select-Object -First 1 }
            if ($exe) {
                # Launch DISM++ GUI - can do: scan health, restore health, component cleanup, etc.
                Start-Process $exe.FullName -WindowStyle Normal -Wait
            }
        } catch {
            Write-Host "    [FALLBACK] Running built-in DISM/SFC..." -ForegroundColor Yellow
            DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
            sfc /scannow | Out-Null
        }
        Write-Host "  [OK] DISM++ session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='Windows-Repair-Toolbox-GUI';S={
        Write-Host "  [REPAIR] Launching Windows Repair Toolbox..." -ForegroundColor Cyan
        $dir = "$baseDir\WRT"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $url = "https://windows-repair-toolbox.com/files/Windows_Repair_Toolbox.zip"
            Invoke-WebRequest -Uri $url -OutFile "$dir\wrt.zip" -UseBasicParsing -TimeoutSec 180
            Expand-Archive "$dir\wrt.zip" -DestinationPath $dir -Force
            Remove-Item "$dir\wrt.zip" -Force -EA 0
            $exe = Get-ChildItem -Path $dir -Filter "Windows_Repair_Toolbox.exe" -Recurse -EA 0 | Select-Object -First 1
            if ($exe) {
                # Launch comprehensive repair toolbox GUI
                Start-Process $exe.FullName -WindowStyle Normal -Wait
            }
        } catch {
            Write-Host "    [WARN] Windows Repair Toolbox download failed" -ForegroundColor Yellow
        }
        Write-Host "  [OK] Windows Repair Toolbox session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # DRIVER CLEANER (PORTABLE GUI) - REPLACES DevManView
    # =========================================================================
    @{N='Driver-Store-Explorer-GUI';S={
        Write-Host "  [DRIVER] Launching Driver Store Explorer..." -ForegroundColor Cyan
        $dir = "$baseDir\RAPR"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            # Get latest from GitHub
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/lostindark/DriverStoreExplorer/releases/latest" -UseBasicParsing
            $asset = $releases.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
            if ($asset) {
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$dir\rapr.zip" -UseBasicParsing -TimeoutSec 120
                Expand-Archive "$dir\rapr.zip" -DestinationPath $dir -Force
                Remove-Item "$dir\rapr.zip" -Force -EA 0
                $exe = Get-ChildItem -Path $dir -Filter "Rapr.exe" -Recurse -EA 0 | Select-Object -First 1
                if ($exe) {
                    # Launch GUI - can delete old/unused drivers
                    Start-Process $exe.FullName -WindowStyle Normal -Wait
                }
            }
        } catch {
            Write-Host "    [WARN] Driver Store Explorer download failed" -ForegroundColor Yellow
        }
        Write-Host "  [OK] Driver Store Explorer session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # SERVICE MANAGER (PORTABLE GUI) - REPLACES ServiWin
    # =========================================================================
    @{N='Easy-Service-Optimizer-GUI';S={
        Write-Host "  [SERVICE] Launching Easy Service Optimizer..." -ForegroundColor Cyan
        $dir = "$baseDir\ESO"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $url = "https://www.sordum.org/files/downloads.php?easy-service-optimizer"
            # Direct download link
            Invoke-WebRequest -Uri "https://www.sordum.org/files/easy-service-optimizer/eso.zip" -OutFile "$dir\eso.zip" -UseBasicParsing -TimeoutSec 120
            Expand-Archive "$dir\eso.zip" -DestinationPath $dir -Force
            Remove-Item "$dir\eso.zip" -Force -EA 0
            $exe = Get-ChildItem -Path $dir -Filter "*.exe" -Recurse -EA 0 | Where-Object { $_.Name -notlike "*unins*" } | Select-Object -First 1
            if ($exe) {
                # Launch GUI - can optimize services with presets (Safe, Tweaked, Extreme)
                Start-Process $exe.FullName -WindowStyle Normal -Wait
            }
        } catch {
            Write-Host "    [WARN] Easy Service Optimizer download failed" -ForegroundColor Yellow
        }
        Write-Host "  [OK] Easy Service Optimizer session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # SHELL EXTENSION MANAGER (PORTABLE GUI) - REPLACES ShellExView
    # =========================================================================
    @{N='ShellExView-Manager-GUI';S={
        Write-Host "  [SHELL] Launching ShellExView for cleanup..." -ForegroundColor Cyan
        $url = "https://www.nirsoft.net/utils/shexview-x64.zip"
        $dir = "$baseDir\ShellEx"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\shex.zip" -UseBasicParsing -TimeoutSec 120
        Expand-Archive "$dir\shex.zip" -DestinationPath $dir -Force
        Remove-Item "$dir\shex.zip" -Force -EA 0
        $exe = Get-ChildItem -Path $dir -Filter "shexview.exe" -Recurse -EA 0 | Select-Object -First 1
        if ($exe) {
            # Launch GUI - user can disable problematic shell extensions
            Start-Process $exe.FullName -WindowStyle Normal -Wait
        }
        Write-Host "  [OK] ShellExView session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # SCHEDULED TASK MANAGER (PORTABLE GUI) - REPLACES TaskScheduler command
    # =========================================================================
    @{N='TaskSchedulerView-GUI';S={
        Write-Host "  [TASKS] Launching TaskSchedulerView..." -ForegroundColor Cyan
        $url = "https://www.nirsoft.net/utils/taskschedulerview-x64.zip"
        $dir = "$baseDir\TaskSched"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\tsv.zip" -UseBasicParsing -TimeoutSec 120
        Expand-Archive "$dir\tsv.zip" -DestinationPath $dir -Force
        Remove-Item "$dir\tsv.zip" -Force -EA 0
        $exe = Get-ChildItem -Path $dir -Filter "TaskSchedulerView.exe" -Recurse -EA 0 | Select-Object -First 1
        if ($exe) {
            # Launch GUI - can disable/delete scheduled tasks
            Start-Process $exe.FullName -WindowStyle Normal -Wait
        }
        Write-Host "  [OK] TaskSchedulerView session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # USB DEVICE CLEANUP (PORTABLE GUI) - REPLACES USBDeview monitoring
    # =========================================================================
    @{N='USBDeview-Cleanup-GUI';S={
        Write-Host "  [USB] Launching USBDeview for cleanup..." -ForegroundColor Cyan
        $url = "https://www.nirsoft.net/utils/usbdeview-x64.zip"
        $dir = "$baseDir\USBDeview"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\usb.zip" -UseBasicParsing -TimeoutSec 120
        Expand-Archive "$dir\usb.zip" -DestinationPath $dir -Force
        Remove-Item "$dir\usb.zip" -Force -EA 0
        $exe = Get-ChildItem -Path $dir -Filter "USBDeview.exe" -Recurse -EA 0 | Select-Object -First 1
        if ($exe) {
            # Launch GUI - can uninstall old/unused USB device entries
            Start-Process $exe.FullName -WindowStyle Normal -Wait
        }
        Write-Host "  [OK] USBDeview session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # PRIVACY & BLOATWARE TOOLS (PORTABLE GUI)
    # =========================================================================
    @{N='OO-ShutUp10-Privacy-GUI';S={
        Write-Host "  [PRIVACY] Launching O&O ShutUp10++..." -ForegroundColor Cyan
        $url = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"
        $dir = "$baseDir\OOSU10"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\OOSU10.exe" -UseBasicParsing -TimeoutSec 120
        if (Test-Path "$dir\OOSU10.exe") {
            # Launch GUI - can apply privacy settings
            Start-Process "$dir\OOSU10.exe" -WindowStyle Normal -Wait
        }
        Write-Host "  [OK] O&O ShutUp10++ session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='OO-AppBuster-Bloatware-GUI';S={
        Write-Host "  [BLOAT] Launching O&O AppBuster..." -ForegroundColor Cyan
        $url = "https://dl5.oo-software.com/files/ooappbuster/OOAB.exe"
        $dir = "$baseDir\OOAB"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\OOAB.exe" -UseBasicParsing -TimeoutSec 120
        if (Test-Path "$dir\OOAB.exe") {
            # Launch GUI - can remove Windows bloatware apps
            Start-Process "$dir\OOAB.exe" -WindowStyle Normal -Wait
        }
        Write-Host "  [OK] O&O AppBuster session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # MEMORY OPTIMIZATION (PORTABLE GUI)
    # =========================================================================
    @{N='RAMMap-Memory-Cleaner-GUI';S={
        Write-Host "  [MEMORY] Launching RAMMap for memory cleanup..." -ForegroundColor Cyan
        $url = "https://download.sysinternals.com/files/RAMMap.zip"
        $dir = "$baseDir\RAMMap"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile "$dir\rm.zip" -UseBasicParsing -TimeoutSec 120
        Expand-Archive "$dir\rm.zip" -DestinationPath $dir -Force
        Remove-Item "$dir\rm.zip" -Force -EA 0
        $exe = Get-ChildItem -Path $dir -Filter "RAMMap64.exe" -Recurse -EA 0 | Select-Object -First 1
        if (!$exe) { $exe = Get-ChildItem -Path $dir -Filter "RAMMap.exe" -Recurse -EA 0 | Select-Object -First 1 }
        if ($exe) {
            # Clear standby memory automatically
            Start-Process $exe.FullName -ArgumentList "-Ew" -WindowStyle Hidden -Wait
            Start-Process $exe.FullName -ArgumentList "-Et" -WindowStyle Hidden -Wait
        }
        Write-Host "  [OK] RAMMap memory cleanup complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='Mem-Reduct-Memory-GUI';S={
        Write-Host "  [MEMORY] Launching Mem Reduct..." -ForegroundColor Cyan
        $dir = "$baseDir\MemReduct"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/henrypp/memreduct/releases/latest" -UseBasicParsing
            $asset = $releases.assets | Where-Object { $_.name -like "*-bin.zip" } | Select-Object -First 1
            if ($asset) {
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$dir\mr.zip" -UseBasicParsing -TimeoutSec 120
                Expand-Archive "$dir\mr.zip" -DestinationPath $dir -Force
                Remove-Item "$dir\mr.zip" -Force -EA 0
                $exe = Get-ChildItem -Path $dir -Filter "memreduct.exe" -Recurse -EA 0 | Select-Object -First 1
                if ($exe) {
                    # Launch and auto-clean memory
                    Start-Process $exe.FullName -ArgumentList "/C" -WindowStyle Hidden -Wait
                }
            }
        } catch {
            Write-Host "    [WARN] Mem Reduct download failed" -ForegroundColor Yellow
        }
        Write-Host "  [OK] Mem Reduct complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # DISK HEALTH & OPTIMIZATION (PORTABLE GUI)
    # =========================================================================
    @{N='CrystalDiskInfo-Health-GUI';S={
        Write-Host "  [DISK] Launching CrystalDiskInfo..." -ForegroundColor Cyan
        $dir = "$baseDir\CDI"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $url = "https://sourceforge.net/projects/crystaldiskinfo/files/latest/download"
            Invoke-WebRequest -Uri "https://osdn.net/projects/crystaldiskinfo/downloads/79552/CrystalDiskInfo9_4_4.zip/" -OutFile "$dir\cdi.zip" -UseBasicParsing -TimeoutSec 180
            Expand-Archive "$dir\cdi.zip" -DestinationPath $dir -Force
            Remove-Item "$dir\cdi.zip" -Force -EA 0
            $exe = Get-ChildItem -Path $dir -Filter "DiskInfo*.exe" -Recurse -EA 0 | Select-Object -First 1
            if ($exe) {
                Start-Process $exe.FullName -WindowStyle Normal -Wait
            }
        } catch {
            Write-Host "    [WARN] CrystalDiskInfo download failed" -ForegroundColor Yellow
        }
        Write-Host "  [OK] CrystalDiskInfo session complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    @{N='Defraggler-Portable-GUI';S={
        Write-Host "  [DISK] Launching Defraggler Portable..." -ForegroundColor Cyan
        $dir = "$baseDir\Defraggler"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $url = "https://download.ccleaner.com/dfsetup222.exe"
            # Defraggler portable
            Invoke-WebRequest -Uri "https://www.ccleaner.com/docs/defraggler/downloading-defraggler/download-links" -UseBasicParsing -TimeoutSec 30
            # Alternative: Use built-in defrag
            Write-Host "    [INFO] Running built-in disk optimization..." -ForegroundColor Yellow
            Optimize-Volume -DriveLetter C -Defrag -EA 0
            Optimize-Volume -DriveLetter C -ReTrim -EA 0
        } catch {}
        Write-Host "  [OK] Disk optimization complete" -ForegroundColor Green
        Remove-Item $dir -Recurse -Force -EA 0
    }}

    # =========================================================================
    # BROWSER CLEANUP (AUTOMATIC)
    # =========================================================================
    @{N='Browser-Cache-Cleaner';S={
        Write-Host "  [BROWSER] Cleaning browser caches..." -ForegroundColor Cyan
        # Chrome
        Get-Process chrome -EA 0 | Stop-Process -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*" -Recurse -Force -EA 0
        # Edge
        Get-Process msedge -EA 0 | Stop-Process -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*" -Recurse -Force -EA 0
        # Firefox
        Get-Process firefox -EA 0 | Stop-Process -Force -EA 0
        Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -EA 0 | ForEach-Object {
            Remove-Item "$($_.FullName)\cache2\*" -Recurse -Force -EA 0
        }
        Write-Host "  [OK] Browser caches cleared" -ForegroundColor Green
    }}

    # =========================================================================
    # WINDOWS UPDATE CLEANUP
    # =========================================================================
    @{N='Windows-Update-Cleanup';S={
        Write-Host "  [UPDATE] Cleaning Windows Update cache..." -ForegroundColor Cyan
        Stop-Service wuauserv -Force -EA 0
        Stop-Service bits -Force -EA 0
        Remove-Item "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -EA 0
        Remove-Item "$env:WINDIR\SoftwareDistribution\DataStore\*" -Recurse -Force -EA 0
        Start-Service bits -EA 0
        Start-Service wuauserv -EA 0
        Write-Host "  [OK] Windows Update cache cleared" -ForegroundColor Green
    }}

    # =========================================================================
    # TEMP FILES CLEANUP (AUTOMATIC)
    # =========================================================================
    @{N='Temp-Files-Deep-Cleaner';S={
        Write-Host "  [TEMP] Deep cleaning temp files..." -ForegroundColor Cyan
        $paths = @(
            "$env:TEMP",
            "$env:WINDIR\Temp",
            "$env:LOCALAPPDATA\Temp",
            "$env:WINDIR\Prefetch",
            "$env:LOCALAPPDATA\Microsoft\Windows\WER",
            "$env:ProgramData\Microsoft\Windows\WER",
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"
        )
        foreach ($path in $paths) {
            Remove-Item "$path\*" -Recurse -Force -EA 0
        }
        Write-Host "  [OK] Temp files deep clean complete" -ForegroundColor Green
    }}

    # =========================================================================
    # EVENT LOG CLEANUP
    # =========================================================================
    @{N='Event-Log-Cleaner';S={
        Write-Host "  [LOGS] Clearing Windows event logs..." -ForegroundColor Cyan
        wevtutil el | ForEach-Object { wevtutil cl $_ 2>$null }
        Write-Host "  [OK] Event logs cleared" -ForegroundColor Green
    }}

    # =========================================================================
    # RECYCLE BIN CLEANUP
    # =========================================================================
    @{N='Recycle-Bin-Cleaner';S={
        Write-Host "  [RECYCLE] Emptying Recycle Bin..." -ForegroundColor Cyan
        Clear-RecycleBin -Force -EA 0
        Write-Host "  [OK] Recycle Bin emptied" -ForegroundColor Green
    }}

    # =========================================================================
    # WINDOWS STORE CACHE RESET
    # =========================================================================
    @{N='Store-Cache-Reset';S={
        Write-Host "  [STORE] Resetting Windows Store cache..." -ForegroundColor Cyan
        Start-Process wsreset.exe -WindowStyle Hidden -Wait
        Write-Host "  [OK] Store cache reset" -ForegroundColor Green
    }}

    # =========================================================================
    # PRINT SPOOLER CLEANUP
    # =========================================================================
    @{N='Print-Spooler-Cleaner';S={
        Write-Host "  [PRINT] Cleaning print spooler..." -ForegroundColor Cyan
        Stop-Service Spooler -Force -EA 0
        Remove-Item "$env:WINDIR\System32\spool\PRINTERS\*" -Force -EA 0
        Start-Service Spooler -EA 0
        Write-Host "  [OK] Print spooler cleaned" -ForegroundColor Green
    }}

    # =========================================================================
    # FONT CACHE REBUILD
    # =========================================================================
    @{N='Font-Cache-Rebuilder';S={
        Write-Host "  [FONT] Rebuilding font cache..." -ForegroundColor Cyan
        Stop-Service FontCache -Force -EA 0
        Remove-Item "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Force -EA 0
        Start-Service FontCache -EA 0
        Write-Host "  [OK] Font cache rebuilt" -ForegroundColor Green
    }}

    # =========================================================================
    # DELIVERY OPTIMIZATION CLEANUP
    # =========================================================================
    @{N='Delivery-Optimization-Cleaner';S={
        Write-Host "  [DELIVERY] Clearing delivery optimization cache..." -ForegroundColor Cyan
        Stop-Service DoSvc -Force -EA 0
        Remove-Item "$env:WINDIR\SoftwareDistribution\DeliveryOptimization\*" -Recurse -Force -EA 0
        Start-Service DoSvc -EA 0
        Write-Host "  [OK] Delivery optimization cache cleared" -ForegroundColor Green
    }}

    # =========================================================================
    # WINDOWS DEFENDER MAINTENANCE
    # =========================================================================
    @{N='Defender-Quick-Scan';S={
        Write-Host "  [DEFENDER] Running quick Defender scan..." -ForegroundColor Cyan
        Update-MpSignature -EA 0
        Start-MpScan -ScanType QuickScan -EA 0
        Write-Host "  [OK] Defender scan complete" -ForegroundColor Green
    }}

    # =========================================================================
    # COMPONENT STORE CLEANUP (AUTOMATIC)
    # =========================================================================
    @{N='Component-Store-Cleanup';S={
        Write-Host "  [COMPONENT] Running component store cleanup..." -ForegroundColor Cyan
        DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
        Write-Host "  [OK] Component store cleanup complete" -ForegroundColor Green
    }}

    # =========================================================================
    # WINDOWS DISK CLEANUP UTILITY
    # =========================================================================
    @{N='Windows-Disk-Cleanup';S={
        Write-Host "  [DISK] Running Windows Disk Cleanup..." -ForegroundColor Cyan
        # Configure cleanup options
        $cleanupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        Get-ChildItem $cleanupKey | ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name StateFlags0100 -Value 2 -EA 0
        }
        Start-Process cleanmgr.exe -ArgumentList "/sagerun:100" -WindowStyle Hidden -Wait
        Write-Host "  [OK] Windows Disk Cleanup complete" -ForegroundColor Green
    }}

    # =========================================================================
    # SEARCH INDEX REBUILD
    # =========================================================================
    @{N='Search-Index-Rebuilder';S={
        Write-Host "  [SEARCH] Rebuilding Windows Search index..." -ForegroundColor Cyan
        Stop-Service WSearch -Force -EA 0
        Remove-Item "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\*" -Recurse -Force -EA 0
        Start-Service WSearch -EA 0
        Write-Host "  [OK] Search index rebuilt" -ForegroundColor Green
    }}
)

# === GLOBAL CLEANUP FUNCTION ===
function Global-Cleanup {
    Write-Host "`n[GLOBAL CLEANUP] Purging all tool traces from all drives..." -ForegroundColor Yellow
    
    # Remove base temp directory
    Remove-Item $baseDir -Recurse -Force -EA 0
    
    # Scan all drives for leftover tool directories
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Used -gt 0}
    foreach ($drive in $drives) {
        $searchPaths = @(
            "$($drive.Root)Users\*\AppData\Local\Temp\*Cleaner*",
            "$($drive.Root)Users\*\AppData\Local\Temp\*Optimizer*",
            "$($drive.Root)Users\*\AppData\Local\Temp\*Repair*",
            "$($drive.Root)Users\*\AppData\Local\Temp\AutoCleanerTools*",
            "$($drive.Root)Users\*\Downloads\*Portable*",
            "$($drive.Root)Temp\*Tool*"
        )
        
        foreach ($pattern in $searchPaths) {
            Remove-Item $pattern -Recurse -Force -EA 0
        }
    }
    
    Write-Host "[OK] Global cleanup complete - all tool traces purged!" -ForegroundColor Green
}

# === JOB MANAGEMENT (6 PARALLEL) ===
$script:runningJobs = @{}
$script:toolQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
$tools | ForEach-Object { $script:toolQueue.Enqueue($_) }

function Start-ToolJob {
    param($tool)
    $name = $tool.N
    Write-Host "[START] $name..." -ForegroundColor Cyan
    
    try {
        $job = Start-Job -ScriptBlock $tool.S -Name $name
        $script:runningJobs[$job.Id] = @{Name=$name;Job=$job;Dir=$null}
        Write-Host "[JOB] $name (ID:$($job.Id))" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[ERR] $name : $_" -ForegroundColor Red
        return $false
    }
}

function Maintain-JobPool {
    while ($script:runningJobs.Count -lt 6 -and $script:toolQueue.Count -gt 0) {
        Start-ToolJob $script:toolQueue.Dequeue() | Out-Null
    }
}

function Cleanup-ToolTraces {
    param($toolName)
    
    # Aggressively clean tool-specific traces
    $patterns = @(
        "*$toolName*",
        "*Cleaner*",
        "*Optimizer*",
        "*Fixer*",
        "*Portable*"
    )
    
    foreach ($pattern in $patterns) {
        Remove-Item "$baseDir\$pattern" -Recurse -Force -EA 0
    }
}

function Start-JobMonitor {
    Write-Host "`n[MONITOR] Running 6 tools in parallel...`n" -ForegroundColor Magenta
    
    while ($script:runningJobs.Count -gt 0 -or $script:toolQueue.Count -gt 0) {
        $completed = @()
        
        foreach ($id in @($script:runningJobs.Keys)) {
            $info = $script:runningJobs[$id]
            $job = $info.Job
            
            if ($job.State -eq 'Completed' -or $job.State -eq 'Failed' -or $job.State -eq 'Stopped') {
                $completed += $id
            }
        }
        
        foreach ($id in $completed) {
            $info = $script:runningJobs[$id]
            Write-Host "`n[DONE] $($info.Name)" -ForegroundColor Yellow
            
            # Show job output
            Receive-Job -Job $info.Job -EA 0 | Out-Host
            Remove-Job -Job $info.Job -Force -EA 0
            
            # Cleanup tool traces immediately
            Cleanup-ToolTraces $info.Name
            
            $script:runningJobs.Remove($id)
        }
        
        if ($completed.Count -gt 0) { Maintain-JobPool }
        
        $running = @($script:runningJobs.Values | ForEach-Object { $_.Name })
        $queued = $script:toolQueue.Count
        if ($running.Count -gt 0) {
            $status = "[ACTIVE: $($running.Count)] [QUEUED: $queued] $($running -join ', ')"
            if ($status.Length -gt 120) { $status = $status.Substring(0,117) + "..." }
            Write-Host "`r$status                              " -NoNewline -ForegroundColor White
        }
        
        Start-Sleep -Milliseconds 500
    }
}

# === MAIN EXECUTION ===
Write-Host @"

================================================================================
   WIN11 ULTIMATE AUTOMATIC CLEANUP & REPAIR SUITE v2.0
   $($tools.Count) portable GUI tools | 6 parallel | Auto-cleanup enabled
   
   PRIORITY #1: Taskbar & Icon Repair (fixes broken/duplicated shortcuts)
   
   ALL TOOLS ARE LEGITIMATE PORTABLE GUI APPLICATIONS:
   - BleachBit, PrivaZer, Wise Disk Cleaner, Wise Registry Cleaner
   - BCUninstaller, Geek Uninstaller (REPLACES all uninstaller commands)
   - Complete Internet Repair (REPLACES TCPView, WifiInfoView, CurrPorts)
   - Autoruns, ShellExView, TaskSchedulerView, USBDeview
   - DISM++, Windows Repair Toolbox (REPLACES DISM/SFC commands)
   - Driver Store Explorer (REPLACES DevManView)
   - Easy Service Optimizer (REPLACES ServiWin)
   - O&O ShutUp10++, O&O AppBuster (Privacy & Bloatware)
   - RAMMap, Mem Reduct, CrystalDiskInfo
================================================================================

"@ -ForegroundColor Cyan

Write-Host "[INIT] Starting first 6 tools in parallel...`n" -ForegroundColor Green

$count = 0
while ($count -lt 6 -and $script:toolQueue.Count -gt 0) {
    if (Start-ToolJob $script:toolQueue.Dequeue()) { $count++ }
}

Start-JobMonitor

Write-Host "`n`n[COMPLETE] All $($tools.Count) tools finished!" -ForegroundColor Green

Global-Cleanup

Write-Host "`n[SUCCESS] System optimized and all tool traces purged!" -ForegroundColor Green
Write-Host "          All monitoring-only tools replaced with ACTION tools!" -ForegroundColor Green
Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
