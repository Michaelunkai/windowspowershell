<#
.SYNOPSIS
    rmod - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Get-Service -Name *WeMod* -ErrorAction SilentlyContinue | % {Stop-Service $_.Name -Force -ErrorAction SilentlyContinue; sc.exe delete $_.Name} ; Get-Process -Name *WeMod* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; & "C:\users\micha\AppData\Local\WeMod\WeMod.exe"
