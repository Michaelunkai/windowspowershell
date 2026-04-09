<#
.SYNOPSIS
    newprofile
#>
New-Item -Path $profile -ItemType File -Force; notepad $profile
