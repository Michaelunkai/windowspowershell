@echo off
echo ========================================
echo CLEANING UP UNNECESSARY FILES
echo ========================================
echo.

REM Delete unnecessary documentation (keep only essential)
del /Q "CHANGELOG.md" 2>nul
del /Q "INDEX.md" 2>nul
del /Q "EXAMPLES.md" 2>nul
del /Q "COMPILE_INSTRUCTIONS.md" 2>nul
del /Q "quick_compile.ps1" 2>nul

REM Delete log files
del /Q "sitemap_server.log" 2>nul

REM Delete redundant batch files
del /Q "app_multi.bat" 2>nul

REM Delete PowerShell scripts (not needed after compilation)
del /Q "kill_protected.ps1" 2>nul
del /Q "disable_service.ps1" 2>nul

echo.
echo ========================================
echo CLEANUP COMPLETE!
echo ========================================
echo.
echo KEPT FILES:
echo   - service_killer.exe (MAIN TOOL)
echo   - ultimate_killer.exe
echo   - nuclear.exe
echo   - app.bat (simple launcher)
echo   - compile.bat (for recompiling)
echo   - Source files (.cpp)
echo   - Essential docs (README, QUICK_START, SAFE_TO_KILL)
echo.
echo REMOVED:
echo   - Redundant documentation
echo   - Log files
echo   - PowerShell scripts
echo   - Redundant batch files
echo.
pause
