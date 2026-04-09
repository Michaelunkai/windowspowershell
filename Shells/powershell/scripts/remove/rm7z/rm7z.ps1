<#
.SYNOPSIS
    rm7z - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Get-ChildItem -Path "F:\DOWNLOADS" -Include *.zip,*.rar,*.7z,*.tar,*.gz -Recurse | Remove-Item -Force
