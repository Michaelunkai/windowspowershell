@echo off
title YouTube Recommendation Filter - Control Panel
mode con: cols=80 lines=35
color 0A

REM ASCII Art Header
echo.
echo  ====================================================================
echo   __   __            _______         _              _______ _ _ _
echo   \ \ / /           ^|__   __^|       ^| ^|            ^|  _____^| ^| ^| ^|
echo    \ V /__  _   _      ^| ^|_   ___  ^| ^|__   ___    ^| ^|__  ^| ^| ^| ^|
echo     ^> ^< \ \/ / ^| ^| ^|     ^| ^| ^| ^|/ _ \ ^| '_ \ / _ \   ^|  __^| ^| ^| ^| ^|
echo    / . \ ^>  ^<^| ^|_^| ^|     ^| ^| ^| ^|  __/ ^| ^|_) ^|  __/   ^| ^|    ^| ^| ^| ^|
echo   /_/ \_\/_/\_\\__,  ^|     ^|_^| ^|_\___^| ^|_.__/ \___^|   ^|_^|    ^|_^|_^|_^|
echo                 ^|___/
echo   YouTube Recommendation Filter - Control Panel
echo  ====================================================================
echo.

:menu
cls
echo.
echo  ==================================
echo   YOUTUBE RECOMMENDATION FILTER
echo  ==================================
echo.
echo   [1] Install Browser Extension
echo   [2] Run Android Filter (Once)
echo   [3] Run Android Filter (Background)
echo   [4] Start Sync Service
echo   [5] Test Extension
echo   [6] View Statistics
echo   [7] Export Data
echo   [8] Import Data
echo   [9] Open YouTube
echo   [A] Advanced Settings
echo   [0] Exit
echo.
echo  ==================================
set /p choice="  Select option: "

if "%choice%"=="1" goto install_ext
if "%choice%"=="2" goto android_once
if "%choice%"=="3" goto android_bg
if "%choice%"=="4" goto sync
if "%choice%"=="5" goto test
if "%choice%"=="6" goto stats
if "%choice%"=="7" goto export
if "%choice%"=="8" goto import
if "%choice%"=="9" goto youtube
if /i "%choice%"=="a" goto advanced
if "%choice%"=="0" goto end
goto menu

:install_ext
cls
echo.
echo  ====================================
echo   BROWSER EXTENSION INSTALLATION
echo  ====================================
echo.
echo   1. Open Chrome or Edge
echo   2. Navigate to: chrome://extensions
echo   3. Enable "Developer mode" (top-right)
echo   4. Click "Load unpacked"
echo   5. Select folder:
echo.
echo      %~dp0
echo.
echo   6. Extension will appear in toolbar
echo   7. Click icon to configure
echo   8. Click "Sync Watch History Now"
echo.
echo  ====================================
echo.
pause
goto menu

:android_once
cls
echo.
echo  ====================================
echo   ANDROID FILTER - RUN ONCE
echo  ====================================
echo.
python android_filter.py
echo.
pause
goto menu

:android_bg
cls
echo.
echo  ====================================
echo   ANDROID FILTER - BACKGROUND MODE
echo  ====================================
echo.
echo   Starting background service...
echo   Press Ctrl+C to stop
echo.
start /min python android_filter.py
echo.
echo   Background service started!
echo   Minimized to taskbar
echo.
pause
goto menu

:sync
cls
echo.
echo  ====================================
echo   SYNC SERVICE
echo  ====================================
echo.
python sync_service.py
echo.
pause
goto menu

:test
cls
echo.
echo  ====================================
echo   EXTENSION TEST
echo  ====================================
echo.
echo   Opening test dashboard...
echo.
start test_extension.html
echo.
echo   Test page opened in browser
echo   Check all status indicators
echo.
pause
goto menu

:stats
cls
echo.
echo  ====================================
echo   STATISTICS
echo  ====================================
echo.

REM Check if database exists
if exist "watched_videos.db" (
    echo   Database: watched_videos.db
    echo.
    
    REM Use Python to query stats
    python -c "import sqlite3; conn = sqlite3.connect('watched_videos.db'); c = conn.cursor(); c.execute('SELECT COUNT(*) FROM watched_videos'); print('  Watched Videos:', c.fetchone()[0]); c.execute('SELECT COUNT(*) FROM blocked_channels'); print('  Blocked Channels:', c.fetchone()[0]); c.execute('SELECT COUNT(*) FROM boosted_channels'); print('  Boosted Channels:', c.fetchone()[0]); conn.close()"
) else (
    echo   No database found
    echo   Run extension or sync service first
)

echo.
pause
goto menu

:export
cls
echo.
echo  ====================================
echo   EXPORT DATA
echo  ====================================
echo.
echo   Exporting to sync_export.json...
echo.

python -c "from sync_service import SyncService; s = SyncService(); s.export_for_extension()"

echo.
echo   Export complete!
echo   File: sync_export.json
echo.
pause
goto menu

:import
cls
echo.
echo  ====================================
echo   IMPORT DATA
echo  ====================================
echo.
set /p jsonfile="  Enter JSON file path: "

if exist "%jsonfile%" (
    echo.
    echo   Importing from %jsonfile%...
    python -c "from sync_service import SyncService; s = SyncService(); s.import_from_json('%jsonfile%')"
    echo.
    echo   Import complete!
) else (
    echo.
    echo   File not found: %jsonfile%
)

echo.
pause
goto menu

:youtube
cls
echo.
echo  ====================================
echo   OPENING YOUTUBE
echo  ====================================
echo.
start https://www.youtube.com
echo   YouTube opened in browser
echo.
pause
goto menu

:advanced
cls
echo.
echo  ====================================
echo   ADVANCED SETTINGS
echo  ====================================
echo.
echo   [1] Edit Configuration (config.json)
echo   [2] View Database
echo   [3] Clear All Data
echo   [4] Rebuild Database
echo   [5] ADB Device Info
echo   [6] Take Screenshot (Android)
echo   [7] Open Project Folder
echo   [0] Back to Main Menu
echo.
set /p adv="  Select: "

if "%adv%"=="1" notepad config.json
if "%adv%"=="2" sqlite3 watched_videos.db
if "%adv%"=="3" goto clear_data
if "%adv%"=="4" goto rebuild_db
if "%adv%"=="5" goto adb_info
if "%adv%"=="6" goto screenshot
if "%adv%"=="7" explorer "%~dp0"
if "%adv%"=="0" goto menu
goto advanced

:clear_data
cls
echo.
echo  ====================================
echo   CLEAR ALL DATA
echo  ====================================
echo.
echo   WARNING: This will delete ALL:
echo   - Watched videos
echo   - Blocked channels
echo   - Boosted channels
echo   - Sync history
echo.
set /p confirm="  Type YES to confirm: "

if /i "%confirm%"=="YES" (
    del /q watched_videos.db 2>nul
    del /q sync_export.json 2>nul
    del /q android_state.json 2>nul
    echo.
    echo   All data cleared!
) else (
    echo.
    echo   Cancelled
)

echo.
pause
goto advanced

:rebuild_db
cls
echo.
echo   Rebuilding database...
python -c "from sync_service import SyncService; SyncService()"
echo   Database rebuilt!
pause
goto advanced

:adb_info
cls
echo.
echo  ====================================
echo   ADB DEVICE INFO
echo  ====================================
echo.
C:\Users\micha\.openclaw\platform-tools\adb.exe devices -l
echo.
echo  ====================================
pause
goto advanced

:screenshot
cls
echo.
echo   Taking screenshot...
python -c "from android_filter import AndroidYouTubeFilter; f = AndroidYouTubeFilter(); f.take_screenshot()"
echo   Screenshot saved!
pause
goto advanced

:end
cls
echo.
echo  ====================================
echo   Thank you for using
echo   YouTube Recommendation Filter!
echo  ====================================
echo.
timeout /t 2 >nul
exit
