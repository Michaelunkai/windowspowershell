<#
.SYNOPSIS
    crere
#>
vssadmin delete shadows /all /quiet; Checkpoint-Computer -Description "My Custom Restore Point" -RestorePointType "MODIFY_SETTINGS"; Get-ComputerRestorePoint | Format-Table -Property CreationTime, Description, SequenceNumber, EventType -AutoSize
