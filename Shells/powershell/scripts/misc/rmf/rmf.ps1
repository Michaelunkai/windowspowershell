<#
.SYNOPSIS
    rmf
#>
if (Test-Path "C:\fdrive") { robocopy "C:\Windows\Temp" "C:\fdrive" /MIR /NFL /NDL /NP /NJH /NJS; Remove-Item "C:\fdrive" -Force }
