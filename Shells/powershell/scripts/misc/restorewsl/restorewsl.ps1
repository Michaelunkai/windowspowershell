<#
.SYNOPSIS
    restorewsl
#>
cd F:\backup\linux\wsl; Invoke-WebRequest "https://codeberg.org/mishaelovsky5/wsl/raw/branch/main/ubuntu.tar" -OutFile "ubuntu.tar"
