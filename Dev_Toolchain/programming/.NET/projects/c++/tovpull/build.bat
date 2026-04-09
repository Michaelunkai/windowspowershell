@echo off
echo Compiling Git Auto Monitor...
cl.exe /EHsc /O2 /Fe:GitAutoMonitor.exe GitAutoMonitor.cpp /link user32.lib gdi32.lib comctl32.lib shell32.lib /SUBSYSTEM:WINDOWS
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Build successful! GitAutoMonitor.exe created.
) else (
    echo.
    echo Build failed!
)
