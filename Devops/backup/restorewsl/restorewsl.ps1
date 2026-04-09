<#
.SYNOPSIS
    restorewsl - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
cd F:\backup\linux\wsl; Invoke-WebRequest "https://codeberg.org/mishaelovsky5/wsl/raw/branch/main/ubuntu.tar" -OutFile "ubuntu.tar"
