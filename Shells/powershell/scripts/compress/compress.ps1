<#
.SYNOPSIS
    compress
#>
param(
        [string]$foldername
    )
    & "C:\Program Files\7-Zip\7z.exe" a -t7z -m0=lzma2 -mx=9 -mmt=on "$foldername.7z" "$foldername\"
