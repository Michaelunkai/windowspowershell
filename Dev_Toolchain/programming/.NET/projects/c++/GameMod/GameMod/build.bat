@echo off
echo Building Game Optimizer...

:: Check for Visual Studio C++ compiler
where cl.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo Visual Studio C++ compiler not found in PATH.
    echo Attempting to locate Visual Studio...
    
    :: Try to find and run vcvarsall.bat
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
        call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    ) else if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat" (
        call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
    ) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" (
        call "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
    ) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat" (
        call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
    ) else (
        echo Could not find Visual Studio installation.
        echo Please run this script from a Visual Studio Developer Command Prompt.
        pause
        exit /b 1
    )
)

:: Compile with optimizations
cl.exe /EHsc /O2 /W3 /DNDEBUG GameOptimizer.cpp ^
    /Fe:GameOptimizer.exe ^
    /link user32.lib shell32.lib advapi32.lib powrprof.lib ntdll.lib ^
    /SUBSYSTEM:WINDOWS /MANIFESTUAC:level='requireAdministrator'

if %errorlevel% equ 0 (
    echo.
    echo Build successful!
    echo Executable: %CD%\GameOptimizer.exe
) else (
    echo.
    echo Build failed with error code %errorlevel%
)

pause
