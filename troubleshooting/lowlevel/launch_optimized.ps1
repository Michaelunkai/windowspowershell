# Gori Cuddly Carnage Optimized Launcher
# Run this before starting the game

# Set process priority to High
$env:GAME_PRIORITY = "High"

# Disable Windows Game Mode for this session
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 0 -Type DWord -Force 2>$null

# Clear temporary DirectX cache
Remove-Item "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force 2>$null

Write-Host "Environment optimized. You can now start Gori Cuddly Carnage." -ForegroundColor Green
Write-Host "If crashes persist, try:" -ForegroundColor Yellow
Write-Host "  1. Add -dx11 to game launch options to force DirectX 11" -ForegroundColor Yellow
Write-Host "  2. Lower graphics settings in-game" -ForegroundColor Yellow
Write-Host "  3. Update GPU drivers to latest version" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
