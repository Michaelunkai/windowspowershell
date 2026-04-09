@echo off
echo Compiling Ultimate Uninstaller v2.2 AGGRESSIVE MODE...
gcc -o ultimate_uninstaller.exe ultimate_uninstaller.c -lshlwapi -ladvapi32 -luserenv -lkernel32 -lntdll -lrstrtmgr -mconsole -static-libgcc -O2 -Wall
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================
    echo Compilation successful!
    echo Output: ultimate_uninstaller.exe
    echo Size:
    dir ultimate_uninstaller.exe | findstr "ultimate_uninstaller.exe"
    echo ============================================
    echo.
) else (
    echo.
    echo Compilation failed!
    echo.
)
pause
