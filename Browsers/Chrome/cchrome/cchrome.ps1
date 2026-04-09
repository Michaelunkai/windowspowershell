<#
.SYNOPSIS
    cchrome - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies" -Force -ErrorAction SilentlyContinue; Start-Process "chrome.exe"
