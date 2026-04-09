<#
.SYNOPSIS
    lrestore - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Get-ComputerRestorePoint | Sort-Object CreationTime -Descending | Select-Object CreationTime | Format-Table -HideTableHeaders
