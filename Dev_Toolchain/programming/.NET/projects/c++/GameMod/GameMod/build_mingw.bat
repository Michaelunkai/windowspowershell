@echo off
echo Building Game Optimizer with MinGW g++...

:: Check for g++
where g++.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo g++ compiler not found in PATH.
    echo Please install MinGW-w64 or add g++ to your PATH.
    pause
    exit /b 1
)

:: Compile with g++
g++ -std=c++17 -O2 -static -static-libgcc -static-libstdc++ ^
    -mwindows -municode ^
    GameOptimizer.cpp ^
    -o GameOptimizer.exe ^
    -luser32 -lshell32 -ladvapi32 -lpowrprof -lntdll

if %errorlevel% equ 0 (
    echo.
    echo Build successful!
    echo Executable: %CD%\GameOptimizer.exe
    echo.
    echo Note: This application requires Administrator privileges to run.
    echo Right-click the executable and select "Run as administrator"
) else (
    echo.
    echo Build failed with error code %errorlevel%
)

pause
