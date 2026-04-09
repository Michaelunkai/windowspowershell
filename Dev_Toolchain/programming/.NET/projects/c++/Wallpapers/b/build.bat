@echo off
echo Building Wallpaper Changer...

REM Try to compile with g++ (MinGW)
where g++ >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Using g++ compiler...
    g++ -o wallpaper_changer.exe wallpaper_changer.cpp -lwinhttp -luser32 -lurlmon -lole32 -mwindows -static -O2
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo Build successful!
        echo Executable: wallpaper_changer.exe
        exit /b 0
    ) else (
        echo Build failed with g++
        exit /b 1
    )
)

REM Try to compile with Visual Studio
where cl >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Using MSVC compiler...
    cl /EHsc /O2 wallpaper_changer.cpp /link winhttp.lib user32.lib /SUBSYSTEM:WINDOWS /OUT:wallpaper_changer.exe
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo Build successful!
        echo Executable: wallpaper_changer.exe
        exit /b 0
    ) else (
        echo Build failed with MSVC
        exit /b 1
    )
)

echo ERROR: No C++ compiler found!
echo Please install either:
echo   - MinGW (g++)
echo   - Visual Studio (cl)
exit /b 1
