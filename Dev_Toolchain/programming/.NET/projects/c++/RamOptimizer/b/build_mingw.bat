@echo off
echo Compiling RAM Optimizer with MinGW...
echo.

REM Compile resource file
windres ram_optimizer.rc -O coff -o ram_optimizer.res
if %ERRORLEVEL% NEQ 0 (
    echo Failed to compile resource file
    pause
    exit /b 1
)

REM Compile the C++ code with the resource file
g++ -O3 -mwindows -static-libgcc -static-libstdc++ ^
    ram_optimizer.cpp ram_optimizer.res ^
    -o ram_optimizer.exe ^
    -lpsapi -lshell32 -luser32

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
del *.res 2>nul
del *.o 2>nul

pause
