<#
.SYNOPSIS
    waitit
#>
param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Command,
        [Parameter(Position=1, Mandatory=$false)]
        [int]$Seconds = 10
    )
    while($true) {
        Clear-Host
        Get-Date
        Invoke-Expression $Command
        Start-Sleep $Seconds
    }
