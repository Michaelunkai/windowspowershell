@echo off
echo Testing TovPlay API Endpoints...
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    pause
    exit /b 1
)

REM Run the API endpoint tests
python scripts\test_api_endpoints.py --url http://localhost:5001 --save-report

echo.
echo Test completed. Check the generated report file.
pause