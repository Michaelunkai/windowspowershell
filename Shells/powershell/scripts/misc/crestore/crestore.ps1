<#
.SYNOPSIS
    crestore
#>
Checkpoint-Computer -Description "Manual Restore Point $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS" -Verbose
