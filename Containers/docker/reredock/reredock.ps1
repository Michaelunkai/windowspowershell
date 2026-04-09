<#
.SYNOPSIS
    reredock - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Stop-Process -Name "*docker*" -Force -ErrorAction SilentlyContinue; Stop-Service -Name "com.docker.service" -Force -ErrorAction SilentlyContinue; Remove-Item "$env:APPDATA\Docker" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item "$env:LOCALAPPDATA\Docker" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item "$env:USERPROFILE\.docker" -Recurse -Force -ErrorAction SilentlyContinue; Start-Service -Name "com.docker.service"; Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
