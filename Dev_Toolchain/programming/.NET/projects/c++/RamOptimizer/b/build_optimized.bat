@echo off
echo Compiling RAM Optimizer with custom icon...
echo.

REM Compile resource file
rc /fo ram_optimizer.res ram_optimizer.rc
if %ERRORLEVEL% NEQ 0 (
    echo Failed to compile resource file
    pause
    exit /b 1
)

REM Compile the C++ code with the resource file
cl /EHsc /O2 /GL /DNDEBUG ram_optimizer.cpp ram_optimizer.res ^
    /link /SUBSYSTEM:WINDOWS /ENTRY:WinMainCRTStartup /LTCG ^
    psapi.lib shell32.lib user32.lib ^
    /OUT:ram_optimizer.exe

if %ERRORLEVEL% NEQ 0 (
    echo Compilation failed
    pause
    exit /b 1
)

echo.
echo Compilation successful!
echo Output: ram_optimizer.exe
echo.

REM Clean up intermediate files
del *.obj 2>nul
del *.res 2>nul
del *.exp 2>nul
del *.lib 2>nul

pause
