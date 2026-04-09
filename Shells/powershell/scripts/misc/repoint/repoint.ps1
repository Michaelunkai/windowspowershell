<#
.SYNOPSIS
    repoint
#>
Get-ComputerRestorePoint | Remove-ComputerRestorePoint -Confirm:$false; Checkpoint-Computer -Description "Fresh Restore Point" -RestorePointType "MODIFY_SETTINGS"
