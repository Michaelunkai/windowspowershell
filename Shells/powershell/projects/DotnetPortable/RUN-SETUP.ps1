#Requires -RunAsAdministrator
# RUN THIS SCRIPT AS ADMINISTRATOR TO SET UP EVERYTHING
# After running, all C++ compilers and .NET tools will be available IMMEDIATELY

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "STARTING ENHANCED SETUP..." -ForegroundColor Cyan  
Write-Host "========================================`n" -ForegroundColor Cyan

# Run the main setup script
& "$PSScriptRoot\SETUP-EVERYTHING.ps1"

# Test immediate availability
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TESTING IMMEDIATE AVAILABILITY..." -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

& "$PSScriptRoot\TEST-TOOLS.ps1"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nAll tools are now available in this session." -ForegroundColor White
Write-Host "For best experience, restart PowerShell after this." -ForegroundColor Yellow
Write-Host "`nSee USAGE-GUIDE.md for examples and commands." -ForegroundColor Cyan
Write-Host "`n" 

Read-Host "Press Enter to exit"
