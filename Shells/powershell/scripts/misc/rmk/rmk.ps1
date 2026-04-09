<#
.SYNOPSIS
    rmk
#>
wsl --unregister kali-linux; wsl --import kali-linux C:\wsl2 F:\\backup\linux\wsl\kalifull.tar; wsl --unregister ubuntu; wsl --import ubuntu C:\wsl2\ubuntu\ F:\\backup\linux\wsl\ubuntu.tar; kali
