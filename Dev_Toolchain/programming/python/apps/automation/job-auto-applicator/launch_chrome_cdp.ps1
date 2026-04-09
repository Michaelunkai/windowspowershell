# Restart Chrome with CDP enabled on Profile 1 (michaelovsky55@gmail.com)

Write-Host "Closing Chrome..." -ForegroundColor Yellow
Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "Launching Chrome with CDP on Profile 1..." -ForegroundColor Green
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$userDataDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"

Start-Process $chromePath -ArgumentList @(
    "--remote-debugging-port=9222",
    "--user-data-dir=`"$userDataDir`"",
    "--profile-directory=Profile 1",
    "--start-maximized"
)

Write-Host "Chrome launched with CDP on port 9222"
Write-Host "Ready for automation"
