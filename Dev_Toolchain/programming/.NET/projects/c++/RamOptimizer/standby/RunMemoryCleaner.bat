@echo off
title Memory Cache Cleaner

REM Check for admin privileges
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

echo.
echo ╔════════════════════════════════════════════╗
echo ║   Memory Cache Cleaner Launcher           ║
echo ╚════════════════════════════════════════════╝
echo.

:menu
echo Choose an option:
echo.
echo [1] Run PowerShell Script (Fast, Recommended)
echo [2] Run C# Executable (if compiled)
echo [3] Exit
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" goto powershell
if "%choice%"=="2" goto csharp
if "%choice%"=="3" goto end
echo Invalid choice, please try again.
echo.
goto menu

:powershell
echo.
echo Running PowerShell script...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0ClearMemoryCache.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Script execution failed!
    pause
)
goto end

:csharp
if not exist "%~dp0MemoryCleaner.exe" (
    echo.
    echo ERROR: MemoryCleaner.exe not found!
    echo Please compile it first using compile.bat
    echo.
    pause
    goto menu
)
echo.
echo Running C# executable...
echo.
"%~dp0MemoryCleaner.exe"
goto end

:end
exit /b
