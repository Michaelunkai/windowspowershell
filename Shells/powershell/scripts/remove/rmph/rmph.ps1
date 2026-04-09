<#
.SYNOPSIS
    rmph - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
powercfg -h off; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name "PagingFiles" -Value " "
