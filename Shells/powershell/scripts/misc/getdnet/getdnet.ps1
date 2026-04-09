<#
.SYNOPSIS
    getdnet
#>
$temp = New-TemporaryFile; $temp = $temp.FullName + ".ps1"; iwr -useb https://dot.net/v1/dotnet-install.ps1 -OutFile $temp; & $temp -Channel "Current" -Verbose; Remove-Item $temp
