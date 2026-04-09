<#
.SYNOPSIS
    restoref - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
robocopy "C:\fdrive" "F:\" /MIR /MT:32 /R:1 /W:1 /NFL /NDL /NP /J
