@echo off
:: Fast Restore Point Creator - Auto-elevating launcher
:: Right-click and "Run as Administrator" or just double-click

:: Check for admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c cd /d \"%~dp0\" && python \"%~dp0fast_restore.py\" %*' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
python fast_restore.py %*
pause
