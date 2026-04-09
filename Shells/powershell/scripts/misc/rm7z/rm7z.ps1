<#
.SYNOPSIS
    rm7z
#>
Get-ChildItem -Path "F:\DOWNLOADS" -Include *.zip,*.rar,*.7z,*.tar,*.gz -Recurse | Remove-Item -Force
