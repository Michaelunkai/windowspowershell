@echo off
echo ================================================================
echo  COMPILING ULTIMATE UNINSTALLER NUCLEAR - C++ EDITION
echo ================================================================
echo.

REM Check for g++ compiler
where g++ >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: g++ compiler not found!
    echo Please install MinGW-w64 or TDM-GCC
    pause
    exit /b 1
)

echo Compiling with maximum optimization...
echo.

g++ -O3 -std=c++17 ^
    ultimate_uninstaller_NUCLEAR.cpp ^
    -o ultimate_uninstaller_NUCLEAR.exe ^
    -lshlwapi ^
    -ladvapi32 ^
    -lkernel32 ^
    -lrstrtmgr ^
    -lole32 ^
    -luuid ^
    -lshell32 ^
    -lpropsys ^
    -static ^
    -municode

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ================================================================
    echo  COMPILATION SUCCESSFUL!
    echo ================================================================
    echo.
    echo Executable: ultimate_uninstaller_NUCLEAR.exe
    echo Size:
    dir ultimate_uninstaller_NUCLEAR.exe | find "ultimate_uninstaller_NUCLEAR.exe"
    echo.
    echo USAGE EXAMPLE:
    echo   ultimate_uninstaller_NUCLEAR.exe "DRIVER BOOSTER" DRIVERBOOSTER IOBIT
    echo.
) else (
    echo.
    echo ================================================================
    echo  COMPILATION FAILED!
    echo ================================================================
    echo Check errors above
)

pause
