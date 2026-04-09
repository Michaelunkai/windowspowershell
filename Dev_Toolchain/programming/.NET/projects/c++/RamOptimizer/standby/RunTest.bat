@echo off
REM Test script for MemoryCleaner.exe

REM Check for admin privileges
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Requesting Administrator privileges for testing...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

echo.
echo ╔════════════════════════════════════════════╗
echo ║   Testing Memory Cleaner (C++ Edition)    ║
echo ╚════════════════════════════════════════════╝
echo.
echo This will run the memory cleaner and verify:
echo   - No applications crash or freeze
echo   - Memory is actually cleared
echo   - System remains stable
echo.
pause

echo.
echo Running MemoryCleaner.exe...
echo.

MemoryCleaner.exe

echo.
echo ╔════════════════════════════════════════════╗
echo ║   Test Complete - Please Verify:          ║
echo ╚════════════════════════════════════════════╝
echo.
echo Check if:
echo   [  ] All applications still running normally
echo   [  ] No programs crashed or froze
echo   [  ] Memory stats showed improvement
echo   [  ] System is responsive
echo.
pause
