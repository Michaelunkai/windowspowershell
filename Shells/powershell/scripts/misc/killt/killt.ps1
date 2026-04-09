<#
.SYNOPSIS
    killt
#>
Get-Process | Where-Object { $_.MainWindowTitle -match 'Windows Terminal|PowerShell|Command Prompt|cmd|wsl' } | ForEach-Object { Stop-Process -Id $_.Id -Force }
