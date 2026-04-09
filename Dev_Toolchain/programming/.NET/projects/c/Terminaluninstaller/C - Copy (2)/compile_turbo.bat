@echo off
echo ========================================
echo Compiling TURBO MODE (Multi-threaded)
echo ========================================
gcc -o ultimate_uninstaller_TURBO.exe ultimate_uninstaller_TURBO.c -lshlwapi -ladvapi32 -lkernel32 -lrstrtmgr -mconsole -static-libgcc -O3 -march=native -mtune=native -flto -ffast-math -Wall
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✓ Compilation successful!
    echo ✓ Output: ultimate_uninstaller_TURBO.exe
    dir ultimate_uninstaller_TURBO.exe | findstr "ultimate_uninstaller_TURBO.exe"
    echo.
) else (
    echo.
    echo ✗ Compilation failed!
    echo.
)
pause
