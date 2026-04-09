@echo off
echo Switching to simple version (v1.0 compatibility mode)...

REM Update manifest to use simple files
powershell -Command "(Get-Content manifest.json) -replace 'enhanced_background.js', 'background.js' | Set-Content manifest.json"
powershell -Command "(Get-Content manifest.json) -replace 'enhanced_content.js', 'content.js' | Set-Content manifest.json"
powershell -Command "(Get-Content manifest.json) -replace 'enhanced_popup.html', 'popup.html' | Set-Content manifest.json"
powershell -Command "(Get-Content manifest.json) -replace 'performance_optimizer.js, ', '' | Set-Content manifest.json"
powershell -Command "(Get-Content manifest.json) -replace '\"version\": \"1.1.0\"', '\"version\": \"1.0.1\"' | Set-Content manifest.json"

echo.
echo Switched to simple version!
echo Reload extension in Chrome to apply changes.
echo.
pause
