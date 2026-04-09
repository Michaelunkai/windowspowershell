@echo off
echo Compiling MemoryCleaner.exe...
echo.

where csc >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: C# compiler ^(csc.exe^) not found in PATH!
    echo.
    echo Please install .NET Framework or .NET SDK first.
    echo Or use the PowerShell script instead: ClearMemoryCache.ps1
    echo.
    pause
    exit /b 1
)

csc.exe /out:MemoryCleaner.exe /platform:anycpu /optimize+ MemoryCleaner.cs

if %ERRORLEVEL% EQU 0 (
    echo.
    echo SUCCESS: MemoryCleaner.exe compiled successfully!
    echo.
    echo To run it, use: RunMemoryCleaner.bat
) else (
    echo.
    echo ERROR: Compilation failed!
)

echo.
pause
