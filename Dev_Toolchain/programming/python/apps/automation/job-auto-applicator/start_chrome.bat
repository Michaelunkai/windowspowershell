@echo off
echo Killing existing Chrome...
taskkill /F /IM chrome.exe >nul 2>&1
timeout /t 2 >nul
echo Starting Chrome with remote debugging on port 9222...
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --user-data-dir="%LOCALAPPDATA%\Google\Chrome\User Data" --profile-directory=Default --no-first-run --no-default-browser-check --start-maximized
echo Chrome started! You can now run: python job_apply.py 5
pause
