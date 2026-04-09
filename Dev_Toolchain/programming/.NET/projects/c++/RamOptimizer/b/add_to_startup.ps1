# PowerShell script to add RAM Optimizer to Windows startup
# Run this script as Administrator

Write-Host "Adding RAM Optimizer to Windows Startup..." -ForegroundColor Cyan
Write-Host ""

$exePath = "F:\study\Dev_Toolchain\programming\.NET\projects\c++\RamOptimizer\b\ram_optimizer.exe"
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = Join-Path $startupFolder "RAM Optimizer.lnk"

# Check if the executable exists
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: ram_optimizer.exe not found at: $exePath" -ForegroundColor Red
    Write-Host "Please make sure the executable exists before running this script." -ForegroundColor Red
    pause
    exit 1
}

# Create a shortcut in the Startup folder
try {
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = $exePath
    $Shortcut.WorkingDirectory = Split-Path $exePath
    $Shortcut.Description = "RAM Optimizer - Automatic memory optimization tool"
    $Shortcut.IconLocation = $exePath + ",0"
    $Shortcut.Save()

    Write-Host "SUCCESS: RAM Optimizer has been added to Windows Startup!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The application will now start automatically when you log in to Windows." -ForegroundColor Green
    Write-Host "Shortcut location: $shortcutPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The RAM optimizer will:" -ForegroundColor Cyan
    Write-Host "  - Start automatically on Windows login" -ForegroundColor White
    Write-Host "  - Run silently in the system tray (no popups)" -ForegroundColor White
    Write-Host "  - Optimize RAM every 1 second (aggressive mode)" -ForegroundColor White
    Write-Host "  - Begin optimization immediately on startup" -ForegroundColor White
    Write-Host ""
    Write-Host "Right-click the system tray icon to stop/start optimization or exit." -ForegroundColor Yellow

} catch {
    Write-Host "ERROR: Failed to create startup shortcut." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
