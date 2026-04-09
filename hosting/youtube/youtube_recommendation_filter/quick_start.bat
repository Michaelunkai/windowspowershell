@echo off
title YouTube Recommendation Filter - Quick Start
color 0A

:menu
cls
echo ========================================
echo  YouTube Recommendation Filter
echo ========================================
echo.
echo  1. Install Browser Extension (Instructions)
echo  2. Run Android Filter
echo  3. Run Sync Service
echo  4. Open Extension Folder
echo  5. View Statistics
echo  6. Exit
echo.
set /p choice="Select option (1-6): "

if "%choice%"=="1" goto browser
if "%choice%"=="2" goto android
if "%choice%"=="3" goto sync
if "%choice%"=="4" goto folder
if "%choice%"=="5" goto stats
if "%choice%"=="6" goto end
goto menu

:browser
cls
echo ========================================
echo  Browser Extension Installation
echo ========================================
echo.
echo  1. Open Chrome or Edge
echo  2. Navigate to: chrome://extensions
echo  3. Enable "Developer mode" (top-right)
echo  4. Click "Load unpacked"
echo  5. Select this folder:
echo     %~dp0
echo.
echo  6. Pin the extension to toolbar
echo  7. Click icon to configure settings
echo  8. Click "Sync Watch History Now"
echo.
pause
goto menu

:android
cls
echo ========================================
echo  Android Filter
echo ========================================
echo.
python android_filter.py
pause
goto menu

:sync
cls
echo ========================================
echo  Sync Service
echo ========================================
echo.
python sync_service.py
pause
goto menu

:folder
cls
echo Opening extension folder...
explorer "%~dp0"
goto menu

:stats
cls
echo ========================================
echo  Statistics
echo ========================================
echo.
python sync_service.py <<EOF
5
6
EOF
pause
goto menu

:end
exit
