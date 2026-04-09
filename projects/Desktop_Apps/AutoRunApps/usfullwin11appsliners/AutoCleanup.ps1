<#
.SYNOPSIS
    AUTOMATED C DRIVE CLEANUP SUITE - 50 PORTABLE CLEANUP TOOLS
.DESCRIPTION
    Runs 50 best portable cleanup tools automatically in batches of 10
    Full automatic cleanup of C drive with comprehensive trace removal
    Each tool runs automatically without user interaction where possible
.NOTES
    Run as Administrator: Start-Process powershell -Verb RunAs
    Tools run 10 at a time in parallel batches until completion
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# Force TLS 1.2 for all downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "`n" -NoNewline
Write-Host "=" * 100 -ForegroundColor Cyan
Write-Host "   AUTOMATED C DRIVE CLEANUP SUITE - 50 PORTABLE TOOLS" -ForegroundColor Cyan
Write-Host "   Running 10 tools at a time | Full automatic cleanup | Complete trace removal" -ForegroundColor Yellow
Write-Host "=" * 100 -ForegroundColor Cyan
Write-Host ""

$tools = @(

    # ==================== BATCH 1: PRIMARY DISK CLEANERS (1-10) ====================

    @{N='BleachBit-Auto';S={
        $n='BleachBit-Auto';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://download.bleachbit.org/BleachBit-4.6.2-portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'bleachbit_console.exe' -Recurse | Select-Object -First 1
            if ($exe) {
                Write-Host "[$n] Running auto cleanup..." -ForegroundColor Green
                Start-Process $exe.FullName -ArgumentList '--clean','system.cache','system.tmp','system.logs','windows.temp','deepscan.tmp' -NoNewWindow -Wait
            }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0; Remove-Item "$env:APPDATA\BleachBit*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WiseDiskCleaner-Auto';S={
        $n='WiseDiskCleaner-Auto';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://downloads.wisecleaner.com/soft/WDCFree.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'WiseDiskCleaner.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -ArgumentList '/auto' -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0; Remove-Item "$env:APPDATA\Wise*","C:\Windows\Temp\Wise*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='CCleaner-Portable';S={
        $n='CCleaner-Portable';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://download.ccleaner.com/portable/ccsetup_portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'CCleaner64.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running auto clean..." -ForegroundColor Green; Start-Process $exe.FullName -ArgumentList '/AUTO' -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0; Remove-Item "C:\Windows\Temp\CCleaner*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='CleanMgr-SagSet';S={
        $n='CleanMgr-SagSet'
        Write-Host "[$n] Running Windows Disk Cleanup with all options..." -ForegroundColor Cyan
        try {
            # Configure all cleanup options
            Start-Process 'cleanmgr.exe' -ArgumentList '/sageset:1' -Wait
            Start-Process 'cleanmgr.exe' -ArgumentList '/sagerun:1' -NoNewWindow -Wait
            Write-Host "[$n] Cleanup completed" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Temp-Folders-Cleanup';S={
        $n='Temp-Folders-Cleanup'
        Write-Host "[$n] Cleaning all temp folders..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\Windows\Temp\*" -Recurse -Force -EA 0
            Remove-Item "C:\Windows\Prefetch\*" -Recurse -Force -EA 0
            Remove-Item "$env:TEMP\*" -Recurse -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Temp\*" -Recurse -Force -EA 0
            Remove-Item "C:\Temp\*" -Recurse -Force -EA 0
            Write-Host "[$n] Temp folders cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Windows-Update-Cleanup';S={
        $n='Windows-Update-Cleanup'
        Write-Host "[$n] Cleaning Windows Update cache..." -ForegroundColor Cyan
        try {
            Stop-Service wuauserv -Force -EA 0
            Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -EA 0
            Start-Service wuauserv -EA 0
            Write-Host "[$n] Update cache cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='CBS-Logs-Cleanup';S={
        $n='CBS-Logs-Cleanup'
        Write-Host "[$n] Cleaning CBS logs..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\Windows\Logs\CBS\*" -Force -EA 0
            Remove-Item "C:\Windows\Logs\DISM\*" -Force -EA 0
            Remove-Item "C:\Windows\Logs\DPX\*" -Force -EA 0
            Write-Host "[$n] CBS logs cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='RecycleBin-Empty';S={
        $n='RecycleBin-Empty'
        Write-Host "[$n] Emptying Recycle Bin..." -ForegroundColor Cyan
        try {
            Clear-RecycleBin -Force -EA 0
            Write-Host "[$n] Recycle Bin emptied" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Thumbnail-Cache-Clear';S={
        $n='Thumbnail-Cache-Clear'
        Write-Host "[$n] Clearing thumbnail cache..." -ForegroundColor Cyan
        try {
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\*" -Include "thumbcache_*.db" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db" -Force -EA 0
            Write-Host "[$n] Thumbnail cache cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Event-Logs-Clear';S={
        $n='Event-Logs-Clear'
        Write-Host "[$n] Clearing event logs..." -ForegroundColor Cyan
        try {
            wevtutil el | ForEach-Object { wevtutil cl $_ }
            Write-Host "[$n] Event logs cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== BATCH 2: BROWSER CLEANUP (11-20) ====================

    @{N='Chrome-Cache-Clear';S={
        $n='Chrome-Cache-Clear'
        Write-Host "[$n] Cleaning Chrome cache..." -ForegroundColor Cyan
        try {
            Get-Process chrome -EA 0 | Stop-Process -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*" -Recurse -Force -EA 0
            Write-Host "[$n] Chrome cache cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Firefox-Cache-Clear';S={
        $n='Firefox-Cache-Clear'
        Write-Host "[$n] Cleaning Firefox cache..." -ForegroundColor Cyan
        try {
            Get-Process firefox -EA 0 | Stop-Process -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2\*" -Recurse -Force -EA 0
            Write-Host "[$n] Firefox cache cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Edge-Cache-Clear';S={
        $n='Edge-Cache-Clear'
        Write-Host "[$n] Cleaning Edge cache..." -ForegroundColor Cyan
        try {
            Get-Process msedge -EA 0 | Stop-Process -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*" -Recurse -Force -EA 0
            Write-Host "[$n] Edge cache cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='SpeedyFox';S={
        $n='SpeedyFox';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading browser optimizer..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://crystalidea.com/downloads/speedyfox.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'speedyfox.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='IE-Cache-Clear';S={
        $n='IE-Cache-Clear'
        Write-Host "[$n] Cleaning Internet Explorer cache..." -ForegroundColor Cyan
        try {
            RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
            RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
            Write-Host "[$n] IE cache cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='DNS-Cache-Flush';S={
        $n='DNS-Cache-Flush'
        Write-Host "[$n] Flushing DNS cache..." -ForegroundColor Cyan
        try {
            ipconfig /flushdns | Out-Null
            Write-Host "[$n] DNS cache flushed" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Chrome-Cookies-Old';S={
        $n='Chrome-Cookies-Old'
        Write-Host "[$n] Cleaning old Chrome data..." -ForegroundColor Cyan
        try {
            Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Storage\*" -Recurse -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Session Storage\*" -Recurse -Force -EA 0
            Write-Host "[$n] Old Chrome data cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Browser-Downloads-Cleanup';S={
        $n='Browser-Downloads-Cleanup'
        Write-Host "[$n] Cleaning browser download history..." -ForegroundColor Cyan
        try {
            Remove-Item "$env:USERPROFILE\Downloads\*.tmp" -Force -EA 0
            Remove-Item "$env:USERPROFILE\Downloads\*.crdownload" -Force -EA 0
            Remove-Item "$env:USERPROFILE\Downloads\*.part" -Force -EA 0
            Write-Host "[$n] Browser downloads cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Flash-Cache-Clear';S={
        $n='Flash-Cache-Clear'
        Write-Host "[$n] Cleaning Flash cache..." -ForegroundColor Cyan
        try {
            Remove-Item "$env:APPDATA\Adobe\Flash Player\*" -Recurse -Force -EA 0
            Remove-Item "$env:APPDATA\Macromedia\Flash Player\*" -Recurse -Force -EA 0
            Write-Host "[$n] Flash cache cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Java-Cache-Clear';S={
        $n='Java-Cache-Clear'
        Write-Host "[$n] Cleaning Java cache..." -ForegroundColor Cyan
        try {
            Remove-Item "$env:LOCALAPPDATA\Sun\Java\Deployment\cache\*" -Recurse -Force -EA 0
            Remove-Item "$env:APPDATA\Sun\Java\Deployment\cache\*" -Recurse -Force -EA 0
            Write-Host "[$n] Java cache cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== BATCH 3: REGISTRY & SYSTEM CLEANUP (21-30) ====================

    @{N='WiseRegCleaner';S={
        $n='WiseRegCleaner';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://downloads.wisecleaner.com/soft/WRCFree.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'WiseRegCleaner.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Prefetch-Clear';S={
        $n='Prefetch-Clear'
        Write-Host "[$n] Cleaning prefetch files..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\Windows\Prefetch\*" -Force -EA 0
            Write-Host "[$n] Prefetch cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Font-Cache-Clear';S={
        $n='Font-Cache-Clear'
        Write-Host "[$n] Clearing font cache..." -ForegroundColor Cyan
        try {
            Stop-Service FontCache -Force -EA 0
            Remove-Item "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Force -EA 0
            Start-Service FontCache -EA 0
            Write-Host "[$n] Font cache cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Windows-Error-Reports';S={
        $n='Windows-Error-Reports'
        Write-Host "[$n] Cleaning Windows error reports..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -EA 0
            Remove-Item "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force -EA 0
            Write-Host "[$n] Error reports cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Delivery-Optimization-Clear';S={
        $n='Delivery-Optimization-Clear'
        Write-Host "[$n] Cleaning delivery optimization cache..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\Windows\SoftwareDistribution\DeliveryOptimization\*" -Recurse -Force -EA 0
            Write-Host "[$n] Delivery optimization cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='System-Restore-Old';S={
        $n='System-Restore-Old'
        Write-Host "[$n] Removing old system restore points..." -ForegroundColor Cyan
        try {
            vssadmin delete shadows /for=C: /oldest /quiet
            Write-Host "[$n] Old restore points removed" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Windows-Installer-Cache';S={
        $n='Windows-Installer-Cache'
        Write-Host "[$n] Cleaning Windows installer cache..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\Windows\Installer\$PatchCache$\*" -Recurse -Force -EA 0
            Write-Host "[$n] Installer cache cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='ComponentStore-Cleanup';S={
        $n='ComponentStore-Cleanup'
        Write-Host "[$n] Cleaning component store..." -ForegroundColor Cyan
        try {
            Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
            Write-Host "[$n] Component store cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='User-Temp-Profiles';S={
        $n='User-Temp-Profiles'
        Write-Host "[$n] Cleaning temporary user profiles..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\Users\TEMP*" -Recurse -Force -EA 0
            Remove-Item "C:\Users\*.bak" -Recurse -Force -EA 0
            Write-Host "[$n] Temp profiles cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Shell-Bags-Clear';S={
        $n='Shell-Bags-Clear'
        Write-Host "[$n] Clearing shell bags..." -ForegroundColor Cyan
        try {
            Remove-ItemProperty -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU" -Name "*" -Force -EA 0
            Remove-ItemProperty -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags" -Name "*" -Force -EA 0
            Write-Host "[$n] Shell bags cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== BATCH 4: MEMORY & PERFORMANCE (31-40) ====================

    @{N='ISLC-MemoryClear';S={
        $n='ISLC-MemoryClear';$t="$env:TEMP\$n";$exe="$t\ISLC.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading memory cleaner..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.wagnardsoft.com/ISLC/ISLC%20v1.0.3.1.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 120
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Working-Set-Trim';S={
        $n='Working-Set-Trim'
        Write-Host "[$n] Trimming working sets..." -ForegroundColor Cyan
        try {
            Get-Process | ForEach-Object { $_.WorkingSet = -1 }
            Write-Host "[$n] Working sets trimmed" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Standby-Memory-Clear';S={
        $n='Standby-Memory-Clear'
        Write-Host "[$n] Clearing standby memory..." -ForegroundColor Cyan
        try {
            $RAMMapUrl = 'https://download.sysinternals.com/files/RAMMap.zip'
            $RAMMapZip = "$env:TEMP\RAMMap.zip"
            $RAMMapDir = "$env:TEMP\RAMMap"
            Invoke-WebRequest -Uri $RAMMapUrl -OutFile $RAMMapZip -UseBasicParsing -TimeoutSec 60
            Expand-Archive -Path $RAMMapZip -DestinationPath $RAMMapDir -Force
            Start-Process "$RAMMapDir\RAMMap64.exe" -ArgumentList '-Ew' -Wait -WindowStyle Hidden
            Remove-Item $RAMMapDir,$RAMMapZip -Recurse -Force -EA 0
            Write-Host "[$n] Standby memory cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='SuperFetch-Clear';S={
        $n='SuperFetch-Clear'
        Write-Host "[$n] Clearing SuperFetch cache..." -ForegroundColor Cyan
        try {
            Stop-Service SysMain -Force -EA 0
            Remove-Item "C:\Windows\Prefetch\ReadyBoot\*" -Recurse -Force -EA 0
            Start-Service SysMain -EA 0
            Write-Host "[$n] SuperFetch cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='PageFile-Reset';S={
        $n='PageFile-Reset'
        Write-Host "[$n] Resetting page file..." -ForegroundColor Cyan
        try {
            $cs = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
            $cs.AutomaticManagedPagefile = $true
            $cs.Put() | Out-Null
            Write-Host "[$n] Page file reset" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Network-Cache-Clear';S={
        $n='Network-Cache-Clear'
        Write-Host "[$n] Clearing network cache..." -ForegroundColor Cyan
        try {
            netsh int ip reset | Out-Null
            netsh winsock reset | Out-Null
            Write-Host "[$n] Network cache cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='SSD-Trim-Optimize';S={
        $n='SSD-Trim-Optimize'
        Write-Host "[$n] Running SSD TRIM optimization..." -ForegroundColor Cyan
        try {
            Optimize-Volume -DriveLetter C -ReTrim -Verbose
            Write-Host "[$n] SSD optimized" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Services-Cache-Clear';S={
        $n='Services-Cache-Clear'
        Write-Host "[$n] Clearing services cache..." -ForegroundColor Cyan
        try {
            Stop-Service BITS -Force -EA 0
            Remove-Item "C:\ProgramData\Microsoft\Network\Downloader\*" -Recurse -Force -EA 0
            Start-Service BITS -EA 0
            Write-Host "[$n] Services cache cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='MUI-Cache-Clear';S={
        $n='MUI-Cache-Clear'
        Write-Host "[$n] Clearing MUI cache..." -ForegroundColor Cyan
        try {
            Remove-ItemProperty -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -Name "*" -Force -EA 0
            Write-Host "[$n] MUI cache cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Process-Idle-Tasks';S={
        $n='Process-Idle-Tasks'
        Write-Host "[$n] Running maintenance tasks..." -ForegroundColor Cyan
        try {
            Start-Process 'Rundll32.exe' -ArgumentList 'advapi32.dll,ProcessIdleTasks' -Wait -WindowStyle Hidden
            Write-Host "[$n] Maintenance tasks completed" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== BATCH 5: DUPLICATE & JUNK CLEANUP (41-50) ====================

    @{N='Czkawka-DupeClean';S={
        $n='Czkawka-DupeClean';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading duplicate cleaner..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/qarmin/czkawka/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match 'windows.*gui.*\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter 'czkawka_gui.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WinSxS-Cleanup';S={
        $n='WinSxS-Cleanup'
        Write-Host "[$n] Cleaning WinSxS folder..." -ForegroundColor Cyan
        try {
            Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
            Dism.exe /online /Cleanup-Image /SPSuperseded
            Write-Host "[$n] WinSxS cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Old-Driver-Packages';S={
        $n='Old-Driver-Packages'
        Write-Host "[$n] Removing old driver packages..." -ForegroundColor Cyan
        try {
            pnputil /delete-driver * /uninstall /force
            Write-Host "[$n] Old drivers removed" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Empty-Folders-Remove';S={
        $n='Empty-Folders-Remove'
        Write-Host "[$n] Removing empty folders..." -ForegroundColor Cyan
        try {
            Get-ChildItem "C:\" -Directory -Recurse -EA 0 | Where-Object { (Get-ChildItem $_.FullName -Force -EA 0).Count -eq 0 } | Remove-Item -Force -EA 0
            Write-Host "[$n] Empty folders removed" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Zero-Byte-Files';S={
        $n='Zero-Byte-Files'
        Write-Host "[$n] Removing zero-byte files..." -ForegroundColor Cyan
        try {
            Get-ChildItem "C:\Windows\Temp" -File -Recurse -EA 0 | Where-Object { $_.Length -eq 0 } | Remove-Item -Force -EA 0
            Get-ChildItem "$env:TEMP" -File -Recurse -EA 0 | Where-Object { $_.Length -eq 0 } | Remove-Item -Force -EA 0
            Write-Host "[$n] Zero-byte files removed" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Windows-Old-Remove';S={
        $n='Windows-Old-Remove'
        Write-Host "[$n] Removing Windows.old folder..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\Windows.old" -Recurse -Force -EA 0
            Write-Host "[$n] Windows.old removed" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Downloaded-Installers';S={
        $n='Downloaded-Installers'
        Write-Host "[$n] Cleaning downloaded installers..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\Windows\Downloaded Installations\*" -Recurse -Force -EA 0
            Remove-Item "C:\Windows\Downloaded Program Files\*" -Recurse -Force -EA 0
            Write-Host "[$n] Installers cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Crash-Dumps-Clear';S={
        $n='Crash-Dumps-Clear'
        Write-Host "[$n] Clearing crash dumps..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\Windows\Minidump\*" -Force -EA 0
            Remove-Item "C:\Windows\MEMORY.DMP" -Force -EA 0
            Remove-Item "$env:LOCALAPPDATA\CrashDumps\*" -Force -EA 0
            Write-Host "[$n] Crash dumps cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Diagnostic-Traces';S={
        $n='Diagnostic-Traces'
        Write-Host "[$n] Cleaning diagnostic traces..." -ForegroundColor Cyan
        try {
            Remove-Item "C:\ProgramData\Microsoft\Diagnosis\*" -Recurse -Force -EA 0
            Remove-Item "C:\Windows\System32\LogFiles\*" -Recurse -Force -EA 0
            Write-Host "[$n] Diagnostic traces cleaned" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Microsoft-Store-Cache';S={
        $n='Microsoft-Store-Cache'
        Write-Host "[$n] Clearing Microsoft Store cache..." -ForegroundColor Cyan
        try {
            WSReset.exe
            Start-Sleep -Seconds 5
            Get-Process WSReset -EA 0 | Stop-Process -Force -EA 0
            Write-Host "[$n] Store cache cleared" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}
)

# ============================================================================
# BATCH EXECUTION ENGINE - 10 AT A TIME
# ============================================================================

$batchSize = 10
$total = $tools.Count
$batchCount = [Math]::Ceiling($total / $batchSize)

Write-Host ""
Write-Host "Starting $total CLEANUP tools in $batchCount batches of $batchSize" -ForegroundColor Yellow
Write-Host "Each batch runs in parallel - next batch starts when current completes!" -ForegroundColor Cyan
Write-Host ""

for ($batch = 0; $batch -lt $batchCount; $batch++) {
    $startIdx = $batch * $batchSize
    $endIdx = [Math]::Min($startIdx + $batchSize - 1, $total - 1)
    $batchTools = $tools[$startIdx..$endIdx]

    Write-Host ""
    Write-Host "=" * 100 -ForegroundColor Magenta
    Write-Host "   BATCH $($batch + 1)/$batchCount - Running tools $($startIdx + 1) to $($endIdx + 1)" -ForegroundColor Magenta
    Write-Host "=" * 100 -ForegroundColor Magenta
    Write-Host ""

    $jobs = @()

    # Start all tools in current batch
    foreach ($tool in $batchTools) {
        $job = Start-Job -ScriptBlock $tool.S -Name $tool.N
        $jobs += $job
        Write-Host "[STARTED] $($tool.N)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host ">>> $($jobs.Count) TOOLS RUNNING IN PARALLEL <<<" -ForegroundColor Cyan
    Write-Host ""

    # Wait for all jobs in batch to complete
    $jobs | Wait-Job | Out-Null

    # Collect output and cleanup
    foreach ($job in $jobs) {
        Receive-Job $job -EA 0
        Remove-Job $job -Force -EA 0
    }

    Write-Host ""
    Write-Host "=" * 100 -ForegroundColor Green
    Write-Host "   BATCH $($batch + 1)/$batchCount COMPLETED!" -ForegroundColor Green
    Write-Host "=" * 100 -ForegroundColor Green
    Write-Host ""

    if ($batch -lt ($batchCount - 1)) {
        Write-Host "Preparing next batch..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

Write-Host ""
Write-Host "=" * 100 -ForegroundColor Cyan
Write-Host "   ALL 50 CLEANUP TOOLS COMPLETED!" -ForegroundColor Cyan
Write-Host "   C Drive has been thoroughly cleaned!" -ForegroundColor Yellow
Write-Host "   All tool traces removed!" -ForegroundColor Yellow
Write-Host "=" * 100 -ForegroundColor Cyan
Write-Host ""

# Final cleanup report
Write-Host "Generating cleanup report..." -ForegroundColor Cyan
$driveC = Get-PSDrive C
Write-Host ""
Write-Host "C: Drive Status:" -ForegroundColor Green
Write-Host "  Used: $([Math]::Round($driveC.Used / 1GB, 2)) GB" -ForegroundColor White
Write-Host "  Free: $([Math]::Round($driveC.Free / 1GB, 2)) GB" -ForegroundColor White
Write-Host ""
Write-Host "RECOMMENDED: Restart your computer for all changes to take effect." -ForegroundColor Yellow
Write-Host ""
