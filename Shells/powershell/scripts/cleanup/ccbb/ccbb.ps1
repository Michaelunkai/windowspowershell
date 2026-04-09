<#
.SYNOPSIS
    ccbb - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Start-Process powershell -ArgumentList "-Command clean" -NoNewWindow; Start-Process powershell -ArgumentList "-Command ws backitup" -NoNewWindow
