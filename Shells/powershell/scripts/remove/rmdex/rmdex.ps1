<#
.SYNOPSIS
    rmdex - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
taskkill /f /im SearchIndexer.exe; taskkill /f /im SearchProtocolHost.exe; taskkill /f /im SearchFilterHost.exe; Stop-Service -Name "WSearch" -Force -NoWait; Remove-Item -Path "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.db" -Force; Start-Service -Name "WSearch"
