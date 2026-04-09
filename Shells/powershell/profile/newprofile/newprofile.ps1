<#
.SYNOPSIS
    newprofile - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
New-Item -Path $profile -ItemType File -Force; notepad $profile
