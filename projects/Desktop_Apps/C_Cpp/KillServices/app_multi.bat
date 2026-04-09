@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: app_multi ^<service1^> [service2] [service3] ...
    echo.
    echo Examples:
    echo   app_multi chrome
    echo   app_multi Todoist Notepad
    echo   app_multi chrome Todoist docker
    exit /b 1
)

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Requires Administrator privileges!
    echo Right-click and select "Run as Administrator"
    pause
    exit /b 1
)

echo ========================================
echo SERVICE FORCE TERMINATOR - MULTI MODE
echo ========================================
echo.

set "targets=%*"
echo Targets: %targets%
echo.

rem Get RAM before
for /f "tokens=*" %%a in ('powershell -command "$os = Get-CimInstance Win32_OperatingSystem; [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1024)"') do set ramBefore=%%a

echo [INFO] RAM Before: %ramBefore% MB
echo.

set totalKilled=0

rem Process each argument
:loop
if "%~1"=="" goto done

echo [TARGET] %1
"%~dp0ultimate_killer.exe" "%1" >nul 2>&1
if errorlevel 1 (
    echo [TRYING] Alternative method for %1...
    for /f %%i in ('powershell -command "Get-Process -Name '%1' -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }"') do (
        taskkill /F /PID %%i >nul 2>&1
        if not errorlevel 1 (
            echo [KILLED] Process PID: %%i
            set /a totalKilled+=1
        )
    )
)

shift
goto loop

:done

rem Get RAM after
for /f "tokens=*" %%a in ('powershell -command "$os = Get-CimInstance Win32_OperatingSystem; [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1024)"') do set ramAfter=%%a

set /a ramFreed=%ramBefore% - %ramAfter%

echo.
echo ========================================
echo [COMPLETE] Processes killed: %totalKilled%
echo [RAM] Before: %ramBefore% MB
echo [RAM] After: %ramAfter% MB
echo [RAM] Freed: %ramFreed% MB
echo ========================================
echo.

timeout /t 3 >nul
