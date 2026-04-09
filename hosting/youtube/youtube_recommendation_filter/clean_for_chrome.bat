@echo off
echo Cleaning directory for Chrome extension...

REM Remove Python cache
if exist "__pycache__\" (
    rd /s /q "__pycache__"
    echo [OK] Removed __pycache__
)

REM Remove any .pyc files
del /s /q *.pyc 2>nul

REM Remove temp files
del /q *.tmp 2>nul
del /q *.bak 2>nul

REM Remove DB temp files
del /q *.db-journal 2>nul
del /q *.db-wal 2>nul
del /q *.db-shm 2>nul

echo [OK] Directory cleaned for Chrome
echo.
echo Ready to load in chrome://extensions
pause
