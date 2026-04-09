<#
.SYNOPSIS
    rmf - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
if (Test-Path "C:\fdrive") { robocopy "C:\Windows\Temp" "C:\fdrive" /MIR /NFL /NDL /NP /NJH /NJS; Remove-Item "C:\fdrive" -Force }
