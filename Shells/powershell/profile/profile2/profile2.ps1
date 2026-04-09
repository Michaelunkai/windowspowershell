<#
.SYNOPSIS
    profile2 - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Get-Content "F:\backup\windowsapps\profile\profile.txt" | Set-Content "$PROFILE" -Force; . $PROFILE
