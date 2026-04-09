<#
.SYNOPSIS
    rmram - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Invoke-WebRequest "https://download.sysinternals.com/files/RAMMap.zip" -OutFile "$env:TEMP\rm.zip"; Expand-Archive "$env:TEMP\rm.zip" "$env:TEMP\rm" -Force; Start-Process "$env:TEMP\rm\RAMMap64.exe" -Verb RunAs
