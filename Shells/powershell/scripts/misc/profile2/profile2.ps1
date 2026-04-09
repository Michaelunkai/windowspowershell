<#
.SYNOPSIS
    profile2
#>
Get-Content "F:\backup\windowsapps\profile\profile.txt" | Set-Content "$PROFILE" -Force; . $PROFILE
