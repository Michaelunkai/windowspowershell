@echo off
echo ========================================
echo YouTube Recommendation Filter - Installer
echo ========================================
echo.

REM Check Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found! Please install Python 3.7+
    pause
    exit /b 1
)

echo [OK] Python detected

REM Initialize database
echo.
echo Initializing database...
python sync_service.py <<EOF
5
6
EOF

echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo Next Steps:
echo.
echo 1. BROWSER EXTENSION:
echo    - Open Chrome/Edge
echo    - Go to chrome://extensions
echo    - Enable "Developer mode"
echo    - Click "Load unpacked"
echo    - Select this folder
echo.
echo 2. ANDROID (Optional):
echo    - Connect device via USB
echo    - Enable USB debugging
echo    - Run: python android_filter.py
echo.
echo 3. SYNC SERVICE (Optional):
echo    - Run: python sync_service.py
echo    - Select option 3 for auto-sync
echo.
echo Project Location:
echo %~dp0
echo.
pause
