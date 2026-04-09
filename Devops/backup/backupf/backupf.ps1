<#
.SYNOPSIS
    backupf - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
if (!(Test-Path "C:\fdrive")) { New-Item -ItemType Directory -Path "C:\fdrive" -Force }; robocopy "F:\" "C:\fdrive" /E /MT:32 /R:1 /W:1 /NFL /NDL /NP /J
