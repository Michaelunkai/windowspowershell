<#
.SYNOPSIS
    cpit - PowerShell utility script
.NOTES
    Original function: cpit
    Extracted: 2026-02-19 20:20
#>
Remove-Item "F:\study" -Recurse -Force -ErrorAction SilentlyContinue ;
Remove-Item "F:\backup" -Recurse -Force -ErrorAction SilentlyContinue ;
Robocopy "F:\\study" "F:\study" /MIR /MT:32 /R:1 /W:1 ;
Robocopy "F:\\backup" "F:\backup" /MIR /MT:32 /R:1 /W:1
