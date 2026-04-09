<#
.SYNOPSIS
    rws
#>
wsl --terminate ubuntu 2>$null; wsl --unregister ubuntu 2>$null; Remove-Item 'C:\wsl2\ubuntu\*' -Force -ErrorAction SilentlyContinue; wsl --import ubuntu C:\wsl2\ubuntu\ 'F:\backup\linux\wsl\ubuntu.tar'
