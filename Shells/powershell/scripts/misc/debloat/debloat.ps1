<#
.SYNOPSIS
    debloat
#>
pwsh -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://debloat.raphi.re/'))) -RunDefaults -Silent"
