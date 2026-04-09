@echo off
echo ╔════════════════════════════════════════════╗
echo ║   Compiling C++ Memory Cleaner...         ║
echo ╚════════════════════════════════════════════╝
echo.

REM Try multiple compiler options
set COMPILED=0

REM Option 1: Try cl.exe (Visual Studio)
where cl.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Found: Microsoft Visual C++ Compiler ^(cl.exe^)
    echo Compiling with MSVC...
    cl.exe /O2 /EHsc /Fe:MemoryCleaner.exe MemoryCleaner.cpp psapi.lib pdh.lib ntdll.lib /link /SUBSYSTEM:CONSOLE
    if %ERRORLEVEL% EQU 0 set COMPILED=1
    goto check
)

REM Option 2: Try g++ (MinGW)
where g++.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Found: GNU C++ Compiler ^(g++^)
    echo Compiling with g++...
    g++ -o MemoryCleaner.exe MemoryCleaner.cpp -lpsapi -lpdh -lntdll -static -O2 -std=c++11
    if %ERRORLEVEL% EQU 0 set COMPILED=1
    goto check
)

REM Option 3: Try clang++
where clang++.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Found: Clang C++ Compiler ^(clang++^)
    echo Compiling with clang++...
    clang++ -o MemoryCleaner.exe MemoryCleaner.cpp -lpsapi -lpdh -lntdll -O2 -std=c++11
    if %ERRORLEVEL% EQU 0 set COMPILED=1
    goto check
)

:check
if %COMPILED% EQU 1 (
    echo.
    echo ╔════════════════════════════════════════════╗
    echo ║   SUCCESS: MemoryCleaner.exe compiled!    ║
    echo ╚════════════════════════════════════════════╝
    echo.
    echo File location: %CD%\MemoryCleaner.exe
    echo.
    goto end
) else (
    echo.
    echo ╔════════════════════════════════════════════╗
    echo ║   ERROR: No C++ compiler found!           ║
    echo ╚════════════════════════════════════════════╝
    echo.
    echo Please install one of:
    echo   - Visual Studio ^(with C++ workload^)
    echo   - MinGW-w64 ^(g++^)
    echo   - LLVM Clang
    echo.
    echo Quick install options:
    echo   1. Visual Studio: https://visualstudio.microsoft.com/downloads/
    echo   2. MinGW: https://www.msys2.org/ ^(then: pacman -S mingw-w64-x86_64-gcc^)
    echo   3. Scoop: scoop install mingw
    echo.
)

:end
pause
