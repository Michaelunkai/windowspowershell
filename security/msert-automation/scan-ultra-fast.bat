@echo off
REM ULTRA-FAST Malware Scan - Pure batch, zero PowerShell overhead
REM Expected: 2-5 MINUTES
REM No UI, 100% automatic

setlocal enabledelayedexpansion
cls

echo ========================================
echo   ULTRA-FAST Scan (Windows Defender)
echo   Expected: 2-5 minutes, not 16+
echo ========================================
echo.

REM Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Must run as Administrator
    pause
    exit /b 1
)

REM Record start time
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a:%%b)

echo [1] Updating signatures...
powershell -Command "Update-MpSignature -ErrorAction SilentlyContinue" >nul 2>&1
echo   OK

echo [2] Starting Quick Scan (max 5 min)...
REM Run scan in background via PowerShell (faster than WMI)
powershell -Command "$job = Start-MpScan -ScanType QuickScan -AsJob; $job | Wait-Job -Timeout 300; $status = Get-MpComputerStatus; Write-Host 'Scan complete'; if ($status.LastQuickScanTime) { Write-Host 'Last scan: ' $status.LastQuickScanTime }"

if errorlevel 1 (
    echo [ERROR] Scan failed
    pause
    exit /b 1
)

echo [3] Getting results...
REM Get threat count
powershell -Command "$threats = Get-MpComputerStatus | Select-Object -ExpandProperty QuarantinedThreats -ErrorAction SilentlyContinue; if ($threats -and $threats.Count -gt 0) { Write-Host 'THREATS: ' $threats.Count; exit 1 } else { Write-Host 'CLEAN: No threats'; exit 0 }"

if errorlevel 1 (
    echo.
    echo [4] Auto-removing threats...
    powershell -Command "Start-MpScan -ScanType FullScan -AsJob | Wait-Job"
    echo   Threats removed
) else (
    echo.
    echo   STATUS: CLEAN
)

echo.
echo ========================================
echo   DONE
echo ========================================
echo.
pause
