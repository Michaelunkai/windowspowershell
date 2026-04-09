<#
.SYNOPSIS
    robs
#>
taskkill /F /IM obs64.exe; cd F:\backup\windowsapps\installed\obs-studio\bin\64bit; powershell Start-Process "obs64.exe" -Verb RunAs
