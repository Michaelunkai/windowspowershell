<#
.SYNOPSIS
    crestore - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Checkpoint-Computer -Description "Manual Restore Point $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS" -Verbose
