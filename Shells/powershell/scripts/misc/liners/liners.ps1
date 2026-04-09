<#
.SYNOPSIS
    liners
#>
Get-Process | Where-Object { $_.Path -like "*.ahk" } | ForEach-Object { Stop-Process -Id $_.Id -Force }; Start-Process "F:\study\Platforms\windows\autohotkey\Liners3n4.ahk"; Start-Process "https://chatgpt.com/g/g-p-6760cb5963188191af3ea15a32ef4a22-continue/project"; wsl -d Ubuntu --cd ~
