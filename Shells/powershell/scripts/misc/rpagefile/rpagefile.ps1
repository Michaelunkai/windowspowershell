<#
.SYNOPSIS
    rpagefile
#>
& -Command "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name PagingFiles -Value ''; cmd /c 'del /f /q C:\pagefile.sys' 2>nul; shutdown /r /t 0"
