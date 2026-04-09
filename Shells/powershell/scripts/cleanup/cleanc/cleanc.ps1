<#
.SYNOPSIS
    cleanc - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Get-ChildItem -Path "C:\" -Force | Where-Object { $_.PSIsContainer -eq $false -or $_.Name -notin @('Program Files','Program Files (x86)','Users','Windows','wsl2','ProgramData','games') } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
