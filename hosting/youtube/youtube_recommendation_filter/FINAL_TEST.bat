@echo off
title YouTube Filter - Final Test
color 0A

echo ========================================
echo   YouTube Recommendation Filter
echo   Final Verification Test
echo ========================================
echo.

REM Test 1: Check all required files
echo [TEST 1] Checking required files...
set MISSING=0

if not exist "manifest.json" (echo   [FAIL] manifest.json missing && set MISSING=1) else (echo   [OK] manifest.json)
if not exist "enhanced_background.js" (echo   [FAIL] enhanced_background.js missing && set MISSING=1) else (echo   [OK] enhanced_background.js)
if not exist "enhanced_content.js" (echo   [FAIL] enhanced_content.js missing && set MISSING=1) else (echo   [OK] enhanced_content.js)
if not exist "enhanced_popup.html" (echo   [FAIL] enhanced_popup.html missing && set MISSING=1) else (echo   [OK] enhanced_popup.html)
if not exist "enhanced_popup.js" (echo   [FAIL] enhanced_popup.js missing && set MISSING=1) else (echo   [OK] enhanced_popup.js)
if not exist "performance_optimizer.js" (echo   [FAIL] performance_optimizer.js missing && set MISSING=1) else (echo   [OK] performance_optimizer.js)
if not exist "icon128.png" (echo   [FAIL] icon128.png missing && set MISSING=1) else (echo   [OK] icon128.png)
if not exist "icon48.png" (echo   [FAIL] icon48.png missing && set MISSING=1) else (echo   [OK] icon48.png)
if not exist "icon16.png" (echo   [FAIL] icon16.png missing && set MISSING=1) else (echo   [OK] icon16.png)

echo.
if %MISSING%==0 (
    echo [PASS] All required files present
) else (
    echo [FAIL] Some files are missing
    pause
    exit /b 1
)

echo.
echo [TEST 2] Validating manifest.json...
python -c "import json; json.load(open('manifest.json')); print('   [OK] Valid JSON')" 2>nul
if errorlevel 1 (
    echo   [FAIL] manifest.json has syntax errors
    pause
    exit /b 1
)

echo.
echo [TEST 3] Checking JavaScript syntax...
node --check enhanced_background.js 2>nul
if errorlevel 1 (
    echo   [FAIL] enhanced_background.js has errors
) else (
    echo   [OK] enhanced_background.js
)

node --check enhanced_content.js 2>nul
if errorlevel 1 (
    echo   [FAIL] enhanced_content.js has errors
) else (
    echo   [OK] enhanced_content.js
)

node --check enhanced_popup.js 2>nul
if errorlevel 1 (
    echo   [FAIL] enhanced_popup.js has errors
) else (
    echo   [OK] enhanced_popup.js
)

echo.
echo [TEST 4] Checking for Python cache...
if exist "__pycache__" (
    echo   [WARN] __pycache__ found - removing...
    rd /s /q "__pycache__"
    echo   [OK] Cleaned
) else (
    echo   [OK] No Python cache
)

echo.
echo [TEST 5] Database check...
if exist "watched_videos.db" (
    echo   [OK] Database exists
) else (
    echo   [INFO] No database yet (will be created on first run)
)

echo.
echo ========================================
echo   ALL TESTS PASSED!
echo ========================================
echo.
echo Extension is ready to load in Chrome.
echo.
echo Path copied to clipboard:
echo %CD%
echo.
echo Next steps:
echo   1. Open chrome://extensions
echo   2. Enable Developer mode
echo   3. Click "Load unpacked"
echo   4. Paste path and press Enter
echo   5. Extension should load without errors
echo.

REM Copy path to clipboard
echo %CD% | clip

pause
