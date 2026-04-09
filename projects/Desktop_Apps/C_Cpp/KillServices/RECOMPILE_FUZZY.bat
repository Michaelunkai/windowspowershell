@echo off
echo ========================================
echo RECOMPILING NUCLEAR.EXE WITH FUZZY MATCHING
echo ========================================
echo.
echo This adds support for:
echo   - Quoted process names: 'samsung notes'
echo   - Spaces in names: "quick share"
echo   - Partial matching: vscode finds Code.exe
echo   - Case insensitive
echo.

F:\DevKit\compilers\mingw64\bin\g++.exe -O3 -std=c++11 -o nuclear.exe nuclear.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo SUCCESS! nuclear.exe compiled!
    echo ========================================
    echo.
    echo Now test it:
    echo   skill 'samsung notes' 'quick share' vscode firefox
    echo.
) else (
    echo.
    echo ========================================
    echo COMPILATION FAILED!
    echo ========================================
    echo Check for errors above.
    echo.
)

pause
