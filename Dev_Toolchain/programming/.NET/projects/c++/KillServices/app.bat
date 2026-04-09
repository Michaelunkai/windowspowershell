@echo off
setlocal

if "%~1"=="" (
    echo Usage: app ^<service1^> [service2] [service3] ...
    echo.
    echo Examples:
    echo   app chrome
    echo   app Todoist Notepad
    echo   app chrome Todoist Notepad docker
    exit /b 1
)

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This application requires Administrator privileges!
    echo Right-click and select "Run as Administrator"
    pause
    exit /b 1
)

echo ========================================
echo SERVICE FORCE TERMINATOR
echo ========================================
echo Targets: %*
echo.

rem Try service_killer first (handles multiple targets natively)
"%~dp0service_killer.exe" %*

echo.
echo ========================================
timeout /t 2 >nul
