<#
.SYNOPSIS
    rmod
#>
Get-Service -Name *WeMod* -ErrorAction SilentlyContinue | % {Stop-Service $_.Name -Force -ErrorAction SilentlyContinue; sc.exe delete $_.Name} ; Get-Process -Name *WeMod* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; & "C:\users\micha\AppData\Local\WeMod\WeMod.exe"
