<#
.SYNOPSIS
    mmsr
#>
$f="$env:TEMP\MSERT.exe"; iwr 'https://go.microsoft.com/fwlink/?LinkId=212732' -OutFile $f; Start-Process $f -Wait; Remove-Item $f -Force
