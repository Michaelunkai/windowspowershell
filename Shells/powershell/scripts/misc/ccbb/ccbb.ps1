<#
.SYNOPSIS
    ccbb
#>
Start-Process powershell -ArgumentList "-Command clean" -NoNewWindow; Start-Process powershell -ArgumentList "-Command ws backitup" -NoNewWindow
