<#
.SYNOPSIS
    rmgamebar - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Get-AppxPackage *Microsoft.XboxGamingOverlay* | Remove-AppxPackage
