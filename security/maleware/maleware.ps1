<#
.SYNOPSIS
    maleware
#>
Invoke-WebRequest -Uri "https://downloads.malwarebytes.com/file/mb3" -OutFile "$env:TEMP\mb3-setup.exe"; Start-Process "$env:TEMP\mb3-setup.exe" -ArgumentList "/quiet" -Wait
