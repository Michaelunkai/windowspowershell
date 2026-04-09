<#
.SYNOPSIS
    restoref
#>
robocopy "C:\fdrive" "F:\" /MIR /MT:32 /R:1 /W:1 /NFL /NDL /NP /J
