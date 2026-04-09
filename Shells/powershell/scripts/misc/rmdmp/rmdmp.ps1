<#
.SYNOPSIS
    rmdmp
#>
gci $env:TEMP,C:\Windows\Temp -Include *.tmp,*.dmp -Recurse -Force -EA 0 | ri -Force -EA 0
