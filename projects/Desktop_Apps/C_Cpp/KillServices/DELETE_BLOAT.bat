@echo off
echo Deleting unnecessary files...

del /Q service_killer.exe 2>nul
del /Q ultimate_killer.exe 2>nul
del /Q service_killer.cpp 2>nul
del /Q ultimate_killer.cpp 2>nul
del /Q app.bat 2>nul
del /Q app_multi.bat 2>nul
del /Q compile.bat 2>nul
del /Q cleanup_bloat.bat 2>nul
del /Q quick_compile.ps1 2>nul
del /Q kill_protected.ps1 2>nul
del /Q disable_service.ps1 2>nul
del /Q sitemap_server.log 2>nul
del /Q CHANGELOG.md 2>nul
del /Q INDEX.md 2>nul
del /Q EXAMPLES.md 2>nul
del /Q COMPILE_INSTRUCTIONS.md 2>nul
del /Q START_HERE.txt 2>nul
del /Q RECOMPILE_NOW.txt 2>nul
del /Q READ_ME_FIRST.txt 2>nul
del /Q SUMMARY.md 2>nul

echo.
echo ========================================
echo CLEANUP COMPLETE!
echo ========================================
echo.
echo KEPT FILES:
echo   - nuclear.exe (THE ONLY TOOL YOU NEED!)
echo   - nuclear.cpp (source code)
echo   - README.md (documentation)
echo   - QUICK_START.md (quick guide)
echo   - SAFE_TO_KILL.md (safe processes list)
echo.
echo DELETED:
echo   - service_killer.exe
echo   - ultimate_killer.exe
echo   - All batch files except this one
echo   - All PowerShell scripts
echo   - All extra documentation
echo   - Log files
echo.
echo Use: skill <process1> <process2> <process3> ...
echo Example: skill chrome firefox notepad
echo.
pause
