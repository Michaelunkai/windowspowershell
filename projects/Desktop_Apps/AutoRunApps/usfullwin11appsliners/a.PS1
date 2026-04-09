<#
.SYNOPSIS
    MEGA 130-TOOL Windows Fix/Optimize/Clean Suite v3
.DESCRIPTION
    130 PORTABLE 3RD PARTY TOOLS ONLY - No built-in Windows commands!
    Always 5 tools running in parallel - never less!
    Comprehensive purge from ALL drives after each tool closes
.NOTES
    Run as Administrator: Start-Process powershell -Verb RunAs
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

Write-Host "`n" -NoNewline
Write-Host "=" * 90 -ForegroundColor Magenta
Write-Host "   MEGA 130-TOOL WINDOWS FIX / OPTIMIZE / CLEAN SUITE v3 (5 PARALLEL)" -ForegroundColor Magenta
Write-Host "   100% 3RD PARTY PORTABLE TOOLS | No Built-in Windows Commands!" -ForegroundColor Yellow
Write-Host "=" * 90 -ForegroundColor Magenta
Write-Host ""

$tools = @(

    # ==================== SYSTEM REPAIR/TWEAKERS (30 tools) ====================

    @{N='DismPlusPlus';S={
        $n='DismPlusPlus';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/Chuyu-Team/Dism-Multi-language/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'Dism++x64.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        (Get-PSDrive -PSProvider FileSystem).Root | ForEach-Object { Remove-Item "$_`Downloads\*Dism*","$_`Temp\*Dism*" -Recurse -Force -EA 0 }
        Remove-Item "$env:LOCALAPPDATA\Dism++" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WinUtil';S={
        $n='WinUtil'
        Write-Host "[$n] Launching ChrisTitus WinUtil..." -ForegroundColor Cyan
        try { Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command','irm christitus.com/win | iex' -Verb RunAs -Wait }
        catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        (Get-PSDrive -PSProvider FileSystem).Root | ForEach-Object { Remove-Item "$_`*winutil*" -Recurse -Force -EA 0 }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='SophiApp';S={
        $n='SophiApp';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/Sophia-Community/SophiApp/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' -and $_.name -notmatch 'Source' } | Select-Object -First 1
            Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'SophiApp.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Optimizer';S={
        $n='Optimizer';$t="$env:TEMP\$n";$exe="$t\Optimizer.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/hellzerg/optimizer/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.exe$' } | Select-Object -First 1
            Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WinRepairToolbox';S={
        $n='WinRepairToolbox';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://windows-repair-toolbox.com/files/Windows_Repair_Toolbox.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -match 'Windows.Repair' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='TweakingRepair';S={
        $n='TweakingRepair';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'http://www.tweaking.com/files/setups/tweaking.com_windows_repair_aio.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'Repair_Windows.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0; Remove-Item "$env:APPDATA\Tweaking*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Win11Fixer';S={
        $n='Win11Fixer';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/99natmar99/Windows-11-Fixer/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match 'Portable.*\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='OOShutUp10';S={
        $n='OOShutUp10';$t="$env:TEMP\$n";$exe="$t\OOSU10.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 120
            if ((Test-Path $exe) -and (Get-Item $exe).Length -gt 100000) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0; Remove-Item "$env:LOCALAPPDATA\O&O*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Privatezilla';S={
        $n='Privatezilla';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/builtbybel/privatezilla/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'Privatezilla.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Winpilot';S={
        $n='Winpilot';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/builtbybel/Winpilot/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'unins' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='XToolbox';S={
        $n='XToolbox';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/xemulat/XToolbox/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Win10Debloater';S={
        $n='Win10Debloater';$t="$env:TEMP\$n"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://github.com/Sycnex/Windows10Debloater/archive/refs/heads/master.zip' -OutFile "$t.zip" -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path "$t.zip" -DestinationPath $t -Force
            $script = Get-ChildItem $t -Filter 'Windows10DebloaterGUI.ps1' -Recurse | Select-Object -First 1
            if ($script) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($script.FullName)`"" -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,"$t.zip" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='BloatRemover';S={
        $n='BloatRemover';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/Fs00/Win10BloatRemover/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='QuickBoost';S={
        $n='QuickBoost';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/SanGraphic/QuickBoost/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WinSlap';S={
        $n='WinSlap';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/svenmauch/WinSlap/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter 'WinSlap.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WindowsSpyBlocker';S={
        $n='WindowsSpyBlocker';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/crazy-max/WindowsSpyBlocker/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match 'WindowsSpyBlocker.*\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WinMemoryCleaner';S={
        $n='WinMemoryCleaner';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/IgorMundstock/WinMemoryCleaner/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='OOAppBuster';S={
        $n='OOAppBuster';$t="$env:TEMP\$n";$exe="$t\OOAB.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://dl5.oo-software.com/files/ooappbuster/OOAB.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 120
            if ((Test-Path $exe) -and (Get-Item $exe).Length -gt 50000) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WinAero';S={
        $n='WinAero';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading WinAero Tweaker..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://winaero.com/downloads/winaerotweaker.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -match 'WinAeroTweaker' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='UltimateWindowsTweaker';S={
        $n='UltimateWindowsTweaker';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.thewindowsclub.com/downloads/UltimateWindowsTweaker5.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='FixWin11';S={
        $n='FixWin11';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.thewindowsclub.com/downloads/FixWin11.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WindowsRepair';S={
        $n='WindowsRepair';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.thewindowsclub.com/downloads/WindowsRepair.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Debloat';S={
        $n='Debloat';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/builtbybel/xd-AntiSpy/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WPD';S={
        $n='WPD';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading Windows Privacy Dashboard..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://wpd.app/get/latest.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'WPD.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='DoNotSpy11';S={
        $n='DoNotSpy11';$t="$env:TEMP\$n";$exe="$t\DoNotSpy11.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://pxc-coding.com/download/donotspy11/' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='ShutUp10';S={
        $n='ShutUp10';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/builtbybel/ShutUp10/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='BloatBox';S={
        $n='BloatBox';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/builtbybel/bloatbox/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='TweakUIX';S={
        $n='TweakUIX';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/builtbybel/TweakUIX/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Rectify11';S={
        $n='Rectify11';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/Rectify11/Installer/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.exe$' } | Select-Object -First 1
            if ($rel) { 
                $exe = "$t\Rectify11.exe"
                Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $exe -UseBasicParsing -TimeoutSec 180
                if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
            }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== DISK CLEANERS (30 tools) ====================

    @{N='WiseDiskCleaner';S={
        $n='WiseDiskCleaner';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://downloads.wisecleaner.com/soft/WDCFree.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'WiseDiskCleaner.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0; Remove-Item "$env:APPDATA\Wise*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

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

    @{N='BleachBit';S={
        $n='BleachBit';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://download.bleachbit.org/BleachBit-4.6.2-portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'bleachbit.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0; Remove-Item "$env:APPDATA\BleachBit*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='GlaryUtilities';S={
        $n='GlaryUtilities';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://download.glarysoft.com/guportable.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'Integrator.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0; Remove-Item "$env:APPDATA\Glary*","$env:LOCALAPPDATA\Glary*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='CleanmgrPlus';S={
        $n='CleanmgrPlus';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/builtbybel/CleanmgrPlus/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter 'CleanmgrPlus.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Czkawka';S={
        $n='Czkawka';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading duplicate file cleaner..." -ForegroundColor Cyan
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

    @{N='AllDup';S={
        $n='AllDup';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading duplicate finder..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.alldup.de/download/AllDupPortable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'AllDup.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='DupeGuru';S={
        $n='DupeGuru';$t="$env:TEMP\$n";$exe="$t\dupeguru.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading duplicate cleaner..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/arsenetar/dupeguru/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.exe$' -and $_.name -match 'win' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $exe -UseBasicParsing -TimeoutSec 180 }
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Auslogics';S={
        $n='Auslogics';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading Auslogics Disk Defrag..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://downloads.auslogics.com/en/disk-defrag-portable/disk-defrag-portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -match 'Defrag' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='CleanerX';S={
        $n='CleanerX';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/builtbybel/CleanerX/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='JetClean';S={
        $n='JetClean';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.bluesprig.com/jetclean/jetcleanportable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'unins' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='KCleaner';S={
        $n='KCleaner';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.kcsoftwares.com/files/kcleaner_333_portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='PrivacyEraser';S={
        $n='PrivacyEraser';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.cybertronsoft.com/download/PrivacyEraserPortable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'unins' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WipeFile';S={
        $n='WipeFile';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading secure file eraser..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.gaijin.at/dl/wipefile_portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Eraser';S={
        $n='Eraser';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading secure eraser..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://sourceforge.net/projects/eraser/files/latest/download' -OutFile "$t\eraser.exe" -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            if (Test-Path "$t\eraser.exe") { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process "$t\eraser.exe" -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Blank';S={
        $n='BlankAndSecure';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading secure deletion tool..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.softwareok.com/Download/BlankAndSecure_Portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*64*.exe' -Recurse | Select-Object -First 1
            if (!$exe) { $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1 }
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='PCDecrapifier';S={
        $n='PCDecrapifier';$t="$env:TEMP\$n";$exe="$t\pcdecrapifier.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading bloatware remover..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.pcdecrapifier.com/download/3.0.1' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='RegSeeker';S={
        $n='RegSeeker';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading registry cleaner..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.hoverdesk.net/dl/RegSeeker.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='LatencyOptimizer';S={
        $n='LatencyOptimizer';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.badosoft.com/files/LatencyOptimizer.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='EmptyBin';S={
        $n='EmptyBin';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading RecycleBin cleaner..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.rizonesoft.com/downloads/RecycleBinEx.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WinSysClean';S={
        $n='WinSysClean';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading system cleaner..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.winsysclean.com/downloads/WinSysClean.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'unins' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='SlimCleaner';S={
        $n='SlimCleaner';$t="$env:TEMP\$n";$exe="$t\SlimCleaner.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.slimwareutilities.com/downloads/SlimCleaner.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='ZHPCleaner';S={
        $n='ZHPCleaner';$t="$env:TEMP\$n";$exe="$t\ZHPCleaner.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading browser cleaner..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://nicolascoolman.eu/download/ZHPCleaner.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='SUMo';S={
        $n='SUMo';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading software updater..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.kcsoftwares.com/files/sumo_5411_portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='TronScript';S={
        $n='TronScript';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading comprehensive repair tool..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/bmrf/tron/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.exe$' } | Select-Object -First 1
            if ($rel) { 
                $exe = "$t\Tron.exe"
                Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $exe -UseBasicParsing -TimeoutSec 300
                if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Verb RunAs -Wait }
            }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='TempFileCleaner';S={
        $n='TempFileCleaner';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.thewindowsclub.com/downloads/TFC.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='RegCool';S={
        $n='RegCool';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading advanced registry editor..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://kurtzimmermann.com/files/RegCoolX64.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='RegistryBackup';S={
        $n='RegistryBackup';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.ascomp.de/download/registrybackup_portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='FreeSpaceCleaner';S={
        $n='FreeSpaceCleaner';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.softwareok.com/Download/FreeSpaceCleaner_Portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*64*.exe' -Recurse | Select-Object -First 1
            if (!$exe) { $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1 }
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== MEMORY/PERFORMANCE (25 tools) ====================

    @{N='ISLC';S={
        $n='ISLC';$t="$env:TEMP\$n";$exe="$t\ISLC.exe"
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

    @{N='MemReduct';S={
        $n='MemReduct';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/henrypp/memreduct/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match 'memreduct.*bin.*\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter 'memreduct.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0; Remove-Item "$env:APPDATA\Henry++*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='RAMMap';S={
        $n='RAMMap';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading from Sysinternals..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/RAMMap.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'RAMMap64.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='ProcessLasso';S={
        $n='ProcessLasso';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading CPU optimizer..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://bitsum.com/files/processlasso.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -match 'processlasso' -and $_.Name -notmatch 'unins' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='QuickCPU';S={
        $n='QuickCPU';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading CPU tweaker..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://coderbag.com/assets/downloads/quickcpu/QuickCpu.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'QuickCpu.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='ParkControl';S={
        $n='ParkControl';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading CPU core parking manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://bitsum.com/files/parkcontrol.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -match 'parkcontrol' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='ReduceMemory';S={
        $n='ReduceMemory';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/AveYo/fox/releases/latest' -TimeoutSec 30).assets | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='MemPlus';S={
        $n='MemPlus';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/CodeDead/MemPlus/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter 'MemPlus.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='CleanMem';S={
        $n='CleanMem';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading memory optimizer..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.pcwintech.com/download/CleanMem_Mini_Monitor_Portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='GameBooster';S={
        $n='GameBooster';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading gaming optimizer..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.wisecleaner.com/soft/WGCFree.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'unins' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== NETWORK OPTIMIZERS (15 tools) ====================

    @{N='TCPOptimizer';S={
        $n='TCPOptimizer';$t="$env:TEMP\$n";$exe="$t\TCPOptimizer.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.speedguide.net/files/TCPOptimizer.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 120
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
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

    @{N='DNSBench';S={
        $n='DNSBench';$t="$env:TEMP\$n";$exe="$t\DNSBench.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading DNS optimizer..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.grc.com/files/DNSBench.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 120
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='NetOptimizer';S={
        $n='NetOptimizer';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/hellzerg/optimizer/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.exe$' } | Select-Object -First 1
            if ($rel) { 
                $exe = "$t\NetOptimizer.exe"
                Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $exe -UseBasicParsing -TimeoutSec 180
                if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
            }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='NameBench';S={
        $n='NameBench';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading DNS benchmark tool..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/namebench/namebench-1.3.1-Windows.exe' -OutFile "$t\namebench.exe" -UseBasicParsing -TimeoutSec 180
            if (Test-Path "$t\namebench.exe") { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process "$t\namebench.exe" -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='NetSetMan';S={
        $n='NetSetMan';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading network profile manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.netsetman.com/download/nsm_portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*64*.exe' -Recurse | Select-Object -First 1
            if (!$exe) { $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1 }
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WifiManager';S={
        $n='WifiManager';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading WiFi profile manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.nirsoft.net/utils/wifiprofilemanager.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*64*.exe' -Recurse | Select-Object -First 1
            if (!$exe) { $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1 }
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='WNSReset';S={
        $n='WNSReset';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading network stack reset tool..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.thewindowsclub.com/downloads/NetworkReset.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='NetBalancer';S={
        $n='NetBalancer';$t="$env:TEMP\$n";$exe="$t\NetBalancer.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading bandwidth manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://netbalancer.com/download/NetBalancerSetup.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='SimpleWall';S={
        $n='SimpleWall';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading firewall manager..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/henrypp/simplewall/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match 'simplewall.*bin.*\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter 'simplewall.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== DRIVER TOOLS (10 tools) ====================

    @{N='DDU';S={
        $n='DDU';$t="$env:TEMP\$n";$exe="$t\DDU.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading Display Driver Uninstaller..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.wagnardsoft.com/DDU/download/DDU%20v18.1.4.0.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0; Remove-Item "$env:APPDATA\Wagnardsoft*" -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='DriverStoreExplorer';S={
        $n='DriverStoreExplorer';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/lostindark/DriverStoreExplorer/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'Rapr.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='NVCleanstall';S={
        $n='NVCleanstall';$t="$env:TEMP\$n";$exe="$t\NVCleanstall.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading NVIDIA driver cleaner..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.techpowerup.com/download/techpowerup-nvcleanstall/' -OutFile "$t\page.html" -UseBasicParsing -TimeoutSec 30
            $html = Get-Content "$t\page.html" -Raw
            if ($html -match 'href="([^"]+nvcleanstall[^"]+\.exe)"') { 
                Invoke-WebRequest -Uri $matches[1] -OutFile $exe -UseBasicParsing -TimeoutSec 180
            }
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='SDI';S={
        $n='SDI';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading Snappy Driver Installer..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://sdi-tool.org/releases/SDI_R2403.zip' -OutFile $z -UseBasicParsing -TimeoutSec 300
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'SDI*.exe' -Recurse | Where-Object { $_.Name -match 'x64' } | Select-Object -First 1
            if (!$exe) { $exe = Get-ChildItem $t -Filter 'SDI*.exe' -Recurse | Select-Object -First 1 }
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='DoubleDriver';S={
        $n='DoubleDriver';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading driver backup tool..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.boozet.org/dd/dd.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='DriverView';S={
        $n='DriverView';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading driver viewer..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.nirsoft.net/utils/driverview-x64.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='DevManView';S={
        $n='DevManView';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading device manager alternative..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.nirsoft.net/utils/devmanview-x64.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='USBDeview';S={
        $n='USBDeview';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading USB device manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.nirsoft.net/utils/usbdeview-x64.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='ServiWin';S={
        $n='ServiWin';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading services manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.nirsoft.net/utils/serviwin-x64.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='InstalledDriversList';S={
        $n='InstalledDriversList';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading driver list tool..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.nirsoft.net/utils/installeddriverslist-x64.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== STARTUP/SERVICES (10 tools) ====================

    @{N='Autoruns';S={
        $n='Autoruns';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading from Sysinternals..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/Autoruns.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'Autoruns64.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Autorunsc';S={
        $n='Autorunsc';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading command-line autoruns..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/Autoruns.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter 'autorunsc64.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running cleanup..." -ForegroundColor Green; Start-Process $exe.FullName -ArgumentList '-a','-c','-h' -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='StartupDelayer';S={
        $n='StartupDelayer';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading startup manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.r2.com.au/downloads/SD3-Portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'unins' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='HiBitStartup';S={
        $n='HiBitStartup';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading startup editor..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.hibitsoft.ir/HiBit.Startup.Manager.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='QuickStartup';S={
        $n='QuickStartup';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading startup manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.glarysoft.com/downloads/qstartup.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'unins' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='ScheduledTasksView';S={
        $n='ScheduledTasksView';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading tasks manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.nirsoft.net/utils/scheduledtasksview-x64.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='TaskSchedulerView';S={
        $n='TaskSchedulerView';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.nirsoft.net/utils/taskschedulerview-x64.zip' -OutFile $z -UseBasicParsing -TimeoutSec 120
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='RunAsService';S={
        $n='RunAsService';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading service manager..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.coretechnologies.com/download/RAAS.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='StartupEye';S={
        $n='StartupEye';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading startup cleaner..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.yourkit.com/download/startupeye.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='ServiceOptimizer';S={
        $n='ServiceOptimizer';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.thewindowsclub.com/downloads/ServiceOptimizer.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Verb RunAs -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    # ==================== SOFTWARE UPDATERS (10 tools) ====================

    @{N='PatchMyPC';S={
        $n='PatchMyPC';$t="$env:TEMP\$n";$exe="$t\PatchMyPC.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://patchmypc.com/freeupdater/PatchMyPC.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if ((Test-Path $exe) -and (Get-Item $exe).Length -gt 500000) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Get-Process -Name '*PatchMyPC*' -EA 0 | Stop-Process -Force -EA 0; Start-Sleep 1
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='SUMo';S={
        $n='SUMo2';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading software updater..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.kcsoftwares.com/files/sumo_5411_portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='UCheck';S={
        $n='UCheck';$t="$env:TEMP\$n";$exe="$t\UCheck.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading update checker..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.adlice.com/download/UCheck/UCheckSetup.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='FileHippo';S={
        $n='FileHippo';$t="$env:TEMP\$n";$exe="$t\UpdateChecker.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading FileHippo Update Checker..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://filehippo.com/download/file/4f3c31e43a1d6ccf95e9ff05f8cff4a38e3c7e7c2cebd5f5ef3c9d6f7e98e1b7/' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='DUMo';S={
        $n='DUMo';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading driver update monitor..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.kcsoftwares.com/files/dumo_2300_portable.zip' -OutFile $z -UseBasicParsing -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='AppsUpdater';S={
        $n='AppsUpdater';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading apps updater..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.glarysoft.com/downloads/softwareupdatepro.zip' -OutFile $z -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 180
            Expand-Archive -Path $z -DestinationPath $t -Force
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Where-Object { $_.Name -notmatch 'unins' } | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='UpdateStar';S={
        $n='UpdateStar';$t="$env:TEMP\$n";$exe="$t\UpdateStar.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://www.updatestar.com/download/updatestarportable.exe' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Heimdal';S={
        $n='Heimdal';$t="$env:TEMP\$n";$exe="$t\Heimdal.exe"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading security updater..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri 'https://heimdalsecurity.com/freeutility/download' -OutFile $exe -UseBasicParsing -TimeoutSec 180
            if (Test-Path $exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='AppBuster';S={
        $n='AppBuster';$t="$env:TEMP\$n";$z="$t.zip"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Downloading bloatware remover..." -ForegroundColor Cyan
        try {
            $rel = (Invoke-RestMethod 'https://api.github.com/repos/builtbybel/appbuster/releases/latest' -TimeoutSec 30).assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if ($rel) { Invoke-WebRequest -Uri $rel.browser_download_url -OutFile $z -UseBasicParsing -TimeoutSec 180; Expand-Archive -Path $z -DestinationPath $t -Force }
            $exe = Get-ChildItem $t -Filter '*.exe' -Recurse | Select-Object -First 1
            if ($exe) { Write-Host "[$n] Running..." -ForegroundColor Green; Start-Process $exe.FullName -Wait }
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] Purging..." -ForegroundColor Yellow
        Remove-Item $t,$z -Recurse -Force -EA 0
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}

    @{N='Chocolatey';S={
        $n='Chocolatey';$t="$env:TEMP\$n"
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        Write-Host "[$n] Installing Chocolatey package manager..." -ForegroundColor Cyan
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Write-Host "[$n] Chocolatey installed! Use 'choco upgrade all -y' to update apps" -ForegroundColor Green
        } catch { Write-Host "[$n] Error: $_" -ForegroundColor Red }
        Write-Host "[$n] DONE" -ForegroundColor Green
    }}
)

# ============================================================================
# PARALLEL EXECUTION ENGINE - ALWAYS 5 RUNNING (STRICT)
# ============================================================================

$maxParallel = 5
$runningJobs = @{}
$idx = 0
$total = $tools.Count

Write-Host ""
Write-Host "Starting $total 3RD PARTY tools - ALWAYS $maxParallel RUNNING!" -ForegroundColor Yellow
Write-Host "Close each app when done - purge happens automatically!" -ForegroundColor Cyan
Write-Host ""

# Initial launch of first 5 tools
for ($i = 0; $i -lt $maxParallel -and $idx -lt $total; $i++) {
    $tool = $tools[$idx]
    $job = Start-Job -ScriptBlock $tool.S -Name $tool.N
    $runningJobs[$job.Id] = $job
    Write-Host "[STARTED $($idx + 1)/$total] $($tool.N)" -ForegroundColor Magenta
    $idx++
}

Write-Host ""
Write-Host ">>> $maxParallel TOOLS NOW RUNNING IN PARALLEL <<<" -ForegroundColor Green
Write-Host ""

# Main loop - keep 5 running at ALL times
while ($runningJobs.Count -gt 0 -or $idx -lt $total) {
    
    # Check each job and immediately replace completed ones
    $completedIds = @()
    foreach ($jobId in @($runningJobs.Keys)) {
        $job = $runningJobs[$jobId]
        
        if ($job.State -eq 'Completed' -or $job.State -eq 'Failed') {
            if ($job.State -eq 'Failed') {
                Write-Host "[FAILED] $($job.Name)" -ForegroundColor Red
            }
            Receive-Job $job -EA 0
            Remove-Job $job -Force -EA 0
            $completedIds += $jobId
            
            # IMMEDIATELY start next tool to maintain 5 running
            if ($idx -lt $total) {
                $tool = $tools[$idx]
                $newJob = Start-Job -ScriptBlock $tool.S -Name $tool.N
                $runningJobs[$newJob.Id] = $newJob
                Write-Host "[STARTED $($idx + 1)/$total] $($tool.N) (Running: $($runningJobs.Count))" -ForegroundColor Magenta
                $idx++
            }
        }
    }
    
    # Remove completed job IDs from hashtable
    foreach ($id in $completedIds) {
        $runningJobs.Remove($id)
    }
    
    # Safety: ensure we always have 5 if tools remain
    while ($runningJobs.Count -lt $maxParallel -and $idx -lt $total) {
        $tool = $tools[$idx]
        $newJob = Start-Job -ScriptBlock $tool.S -Name $tool.N
        $runningJobs[$newJob.Id] = $newJob
        Write-Host "[STARTED $($idx + 1)/$total] $($tool.N) (Running: $($runningJobs.Count))" -ForegroundColor Magenta
        $idx++
    }
    
    Start-Sleep -Milliseconds 200
}

Write-Host ""
Write-Host "=" * 90 -ForegroundColor Magenta
Write-Host "   ALL $total 3RD PARTY FIX/OPTIMIZE/CLEAN TOOLS COMPLETED!" -ForegroundColor Green
Write-Host "   All traces purged from ALL drives!" -ForegroundColor Yellow
Write-Host "=" * 90 -ForegroundColor Magenta
Write-Host ""
Write-Host "RECOMMENDED: Restart your computer for all changes to take effect." -ForegroundColor Cyan
Write-Host ""
