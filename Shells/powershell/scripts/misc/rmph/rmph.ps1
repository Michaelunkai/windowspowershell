<#
.SYNOPSIS
    rmph
#>
powercfg -h off; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name "PagingFiles" -Value " "
