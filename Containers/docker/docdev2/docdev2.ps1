<#
.SYNOPSIS
    docdev2 - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
docker run -it --rm -v ${PWD}:C:\workspace -v ${env:USERPROFILE}:C:\host-profile -v F:\:C:\f-drive -w C:\f-drive\downloads -e IMAGE_INFO="mcr.microsoft.com/windows/servercore:ltsc2022" mcr.microsoft.com/windows/servercore:ltsc2022 powershell -NoExit -Command ". 'C:\host-profile\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'"
