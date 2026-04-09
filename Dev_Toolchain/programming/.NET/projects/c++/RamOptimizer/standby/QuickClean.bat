@echo off
REM Quick Memory Cleaner - Single click execution

REM Check for admin privileges
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -Command "& '%~dp0ClearMemoryCache.ps1'"
pause
