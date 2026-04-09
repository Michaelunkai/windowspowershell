# ============================================================================
# WIN11 GUI CLEANER - PORTABLE CLEANING TOOLS (VISIBLE GUI)
# Run as Administrator: Start-Process powershell -Verb RunAs
# Features: 6 tools run simultaneously, auto-purge on close, GUI VISIBLE
# ALL TOOLS ARE 3RD PARTY PORTABLE GUI CLEANERS - NO COMMAND LINE TOOLS
# ============================================================================

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$baseDir = "$env:TEMP\CleanerTools"
New-Item -ItemType Directory -Path $baseDir -Force | Out-Null

# All tools are 3RD PARTY PORTABLE GUI CLEANERS ONLY - NO VIEWERS/MONITORS
$tools = @(
    # === COMPRESSION TOOL (FIRST - COMPACTGUI) ===
    @{n='CompactGUI';exe='CompactGUI.mono.exe';args='';url='https://github.com/IridiumIO/CompactGUI/releases/download/v4.0.0-beta.6/CompactGUI.mono.exe';desc='CompactGUI - NTFS Compression Tool';isExe=$true}

    # === COMPREHENSIVE GUI CLEANERS ===
    @{n='GlaryUtilities-GUI';exe='Integrator_Portable.exe';args='';url='https://download.glarysoft.com/guportable.zip';desc='Glary Utilities - Auto Cleanup + Registry'}
    @{n='BleachBit-GUI';exe='bleachbit.exe';args='';url='https://download.bleachbit.org/BleachBit-4.6.0-portable.zip';desc='BleachBit GUI Cleaner'}
    @{n='HDCleaner-GUI';exe='HDCleaner.exe';args='';url='https://kurtzimmermann.com/files/HDCleanerX64.zip';desc='HDCleaner 5500+ functions'}
    @{n='WiseDiskCleaner-GUI';exe='WiseDiskCleaner.exe';args='';url='https://downloads.wisecleaner.com/soft/WDCFree_11.3.1.851.zip';desc='Wise Disk Cleaner'}
    @{n='WiseCare-GUI';exe='WiseCare365.exe';args='';url='https://downloads.wisecleaner.com/soft/WiseCare365_7.3.2.716.zip';desc='Wise Care 365 Optimizer'}
    @{n='WiseRegCleaner-GUI';exe='WiseRegCleaner.exe';args='';url='https://downloads.wisecleaner.com/soft/WRCFree_11.3.0.732.zip';desc='Wise Registry Cleaner'}
    @{n='DismPP-GUI';exe='Dism++x64.exe';args='';url='https://github.com/Chuyu-Team/Dism-Multi-language/releases/download/v10.1.1002.2/Dism%2B%2B10.1.1002.1B.zip';desc='Dism++ Windows Cleaner'}

    # === PRIVACY/BROWSER CLEANERS ===
    @{n='SpeedyFox-GUI';exe='speedyfox.exe';args='';url='https://www.crystalidea.com/downloads/speedyfox.zip';desc='SpeedyFox Browser Optimizer'}
    @{n='CleanAfterMe-GUI';exe='CleanAfterMe.exe';args='';url='https://www.nirsoft.net/utils/cleanafterme.zip';desc='CleanAfterMe Privacy'}

    # === STORAGE CLEANERS ===
    @{n='CleanMgrPlus-GUI';exe='cleanmgr+.exe';args='';url='https://github.com/builtbybel/CleanmgrPlus/releases/download/1.50.1300/cleanmgrplus.zip';desc='CleanMgr+ Enhanced Cleanup'}
    @{n='BurnBytes-GUI';exe='BurnBytes.exe';args='';url='https://github.com/builtbybel/burnbytes/releases/download/0.12.2/burnbytes.zip';desc='BurnBytes Storage Cleaner'}
    @{n='CrapFixer-GUI';exe='Crap Fixer.exe';args='';url='https://github.com/builtbybel/CrapFixer/releases/download/1.30.243/CrapFixer.zip';desc='CrapFixer Windows Tweaker'}

    # === DUPLICATE/JUNK FINDERS ===
    @{n='Czkawka-GUI';exe='czkawka_gui.exe';args='';url='https://github.com/qarmin/czkawka/releases/download/10.0.0/windows_czkawka_gui_gtk46.zip';desc='Czkawka Duplicate Finder'}

    # === SYSTEM UTILITIES (Pegasun) ===
    @{n='PegasunCleaner-GUI';exe='SystemUtilities.exe';args='';url='https://Pegasun.com/files/SystemUtilities/SystemUtilities.zip';desc='Pegasun System Utilities'}

    # === SDELETE (secure wipe - runs in background) ===
    @{n='SDelete-CleanC';exe='sdelete64.exe';args='-accepteula -nobanner -c C:';url='https://download.sysinternals.com/files/SDelete.zip';desc='Secure clean C drive free space'}
    @{n='SDelete-ZeroC';exe='sdelete64.exe';args='-accepteula -nobanner -z C:';url='https://download.sysinternals.com/files/SDelete.zip';desc='Zero free space on C drive'}

    # Note: Run Python cleaner separately: git clone https://github.com/nirajj87/advanced-system-cache-junk-cleaner; pip install send2trash psutil humanize colorama watchdog; python main.py --gui
)

# Track running processes
$script:runningTools = @{}
$script:toolQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
$tools | ForEach-Object { $script:toolQueue.Enqueue($_) }

# Cleanup function - remove tool folder
function Purge-ToolTraces {
    param([string]$toolName, [string]$toolDir)
    if ($toolDir -and (Test-Path $toolDir)) {
        # Kill any running processes from this tool directory first
        Get-Process | Where-Object { $_.MainModule.FileName -like "$toolDir*" } | Stop-Process -Force -EA 0
        Start-Sleep -Milliseconds 500
        
        # Try regular delete first
        try {
            Remove-Item $toolDir -Recurse -Force -EA 0
        } catch {
            Write-Host "  [PURGE-RETRY] $toolName - locked files, trying..." -ForegroundColor Yellow
            
            # Force delete with TakeOwnership if available
            try {
                & takeown /F "$toolDir" /R /D Y | Out-Null
                & icacls "$toolDir" /grant administrators:F /T | Out-Null
                Remove-Item $toolDir -Recurse -Force -EA 0
            } catch {
                Write-Host "  [PURGE-ERR] $toolName : Some files may remain locked" -ForegroundColor Red
                # Schedule deletion on next reboot as last resort
                & cmd /c "echo del /q /s /f /a \"$toolDir\*.*\" > \"%TEMP%\purge_$toolName.cmd\""
            }
        }
    }
    Write-Host "  [PURGE] $toolName" -ForegroundColor Green
}

# Launch a 3rd party tool - VISIBLE GUI
function Start-Tool {
    param($tool)
    $name = $tool.n
    Write-Host "[START] $name..." -ForegroundColor Cyan
    try {
        $toolDir = "$baseDir\$name"
        New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
        $exePath = "$toolDir\$($tool.exe)"

        # Download if needed
        if (!(Test-Path $exePath)) {
            Write-Host "  [DL] $name..." -ForegroundColor DarkCyan

            # Check if direct EXE download or ZIP
            if ($tool.isExe -eq $true) {
                # Direct EXE download
                try {
                    Invoke-WebRequest -Uri $tool.url -OutFile $exePath -UseBasicParsing -TimeoutSec 60
                } catch {
                    Write-Host "  [DL-ERR] $name : $_" -ForegroundColor Red
                    Remove-Item $toolDir -Recurse -Force -EA 0
                    return $false
                }
            } else {
                # ZIP download and extract
                $zipPath = "$toolDir\download.zip"
                try {
                    Invoke-WebRequest -Uri $tool.url -OutFile $zipPath -UseBasicParsing -TimeoutSec 60
                } catch {
                    Write-Host "  [DL-ERR] $name : $_" -ForegroundColor Red
                    Remove-Item $toolDir -Recurse -Force -EA 0
                    return $false
                }

                if (Test-Path $zipPath) {
                    try {
                        # Use Shell.Application for better extraction with locked files
                        $shell = New-Object -ComObject Shell.Application
                        $zip = $shell.NameSpace($zipPath)
                        $dest = $shell.NameSpace($toolDir)
                        
                        # Copy all items with error handling
                        foreach ($item in $zip.Items()) {
                            try {
                                $dest.CopyHere($item, 0x14) # 0x14 = No progress + Yes to all
                            } catch {
                                Write-Host "  [SKIP] Locked file: $($item.Name)" -ForegroundColor Yellow
                            }
                        }
                        
                        # Release COM objects
                        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
                        Remove-Variable shell, zip, dest -EA 0
                        
                    } catch {
                        Write-Host "  [ZIP-ERR] $name : $_" -ForegroundColor Red
                        # Fallback to Expand-Archive if Shell fails
                        try {
                            Expand-Archive -Path $zipPath -DestinationPath $toolDir -Force -EA 0
                        } catch {
                            Write-Host "  [FALLBACK-ERR] $name : $_" -ForegroundColor Red
                            Remove-Item $toolDir -Recurse -Force -EA 0
                            Remove-Item $zipPath -Force -EA 0
                            return $false
                        }
                    }
                    Remove-Item $zipPath -Force -EA 0
                }
            }
        }

        # Find the exe (might be in subfolder)
        $exeFound = Get-ChildItem -Path $toolDir -Filter $tool.exe -Recurse -EA 0 | Select-Object -First 1
        if ($exeFound) { $exePath = $exeFound.FullName }

        if (Test-Path $exePath) {
            # Start process - only use ArgumentList if args is not empty
            if ($tool.args -and $tool.args.Trim()) {
                $expandedArgs = [System.Environment]::ExpandEnvironmentVariables($tool.args)
                $proc = Start-Process $exePath -ArgumentList $expandedArgs -WindowStyle Normal -PassThru
            } else {
                $proc = Start-Process $exePath -WindowStyle Normal -PassThru
            }
            $script:runningTools[$proc.Id] = @{Name=$name;Dir=$toolDir;Proc=$proc}
            Write-Host "[RUN] $name (PID:$($proc.Id)) - $($tool.desc)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERR] $name exe not found" -ForegroundColor Red
            Remove-Item $toolDir -Recurse -Force -EA 0
            return $false
        }
    }
    catch {
        Write-Host "[ERR] $name : $_" -ForegroundColor Red
        return $false
    }
}

# Maintain 6 running tools in parallel
function Maintain-MinimumTools {
    while ($script:runningTools.Count -lt 6 -and $script:toolQueue.Count -gt 0) {
        Start-Tool $script:toolQueue.Dequeue() | Out-Null
    }
}

# Monitor loop
function Start-MonitorLoop {
    Write-Host "`n[MONITOR] 6 tools parallel, auto-purge, VISIBLE GUI`n" -ForegroundColor Magenta

    while ($script:runningTools.Count -gt 0 -or $script:toolQueue.Count -gt 0) {
        $closed = @()

        foreach ($id in @($script:runningTools.Keys)) {
            $info = $script:runningTools[$id]
            if ($info.Proc.HasExited) { $closed += $id }
        }

        foreach ($id in $closed) {
            $info = $script:runningTools[$id]
            Write-Host "`n[DONE] $($info.Name)" -ForegroundColor Yellow
            if ($info.Dir) {
                Purge-ToolTraces -toolName $info.Name -toolDir $info.Dir
            }
            $script:runningTools.Remove($id)
        }

        if ($closed.Count -gt 0) { Maintain-MinimumTools }

        $running = @($script:runningTools.Values | ForEach-Object { $_.Name })
        if ($running.Count -gt 0) {
            $status = "[ACTIVE: $($running.Count)] $($running -join ', ')"
            if ($status.Length -gt 100) { $status = $status.Substring(0,97) + "..." }
            Write-Host "`r$status                              " -NoNewline -ForegroundColor White
        }

        Start-Sleep -Milliseconds 500
    }
}

# === MAIN ===
Write-Host @"

===============================================================
   WIN11 3RD PARTY GUI CLEANUP - VISIBLE MODE
   $($tools.Count) portable GUI tools | 6 simultaneous | VISIBLE
   HDCleaner + Wise + Czkawka + CleanMgr+ + SpeedyFox + more
===============================================================

"@ -ForegroundColor Cyan

Write-Host "[INIT] Starting 6 GUI cleanup tools in parallel...`n" -ForegroundColor Green

$count = 0
while ($count -lt 6 -and $script:toolQueue.Count -gt 0) {
    if (Start-Tool $script:toolQueue.Dequeue()) { $count++ }
}

Start-MonitorLoop

Write-Host "`n`n[DONE] All $($tools.Count) cleanup tasks completed!" -ForegroundColor Green
Write-Host "Press any key..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
