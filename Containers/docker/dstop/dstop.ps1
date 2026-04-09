<#
.SYNOPSIS
    dstop
#>
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue; Get-Process | Where-Object { $_.Name -match "docker" } | Stop-Process -Force -ErrorAction SilentlyContinue; Get-Service | Where-Object { $_.Name -match "docker" } | Stop-Service -Force -ErrorAction SilentlyContinue
