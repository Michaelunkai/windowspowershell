# tv-control.ps1 - Samsung TV UE50CU7100UXSQ Main Entry Script
# PS v5 compatible - semicolons not &&
# Usage: powershell -File tv-control.ps1 -Action <action> [-Value <val>] [-Steps <n>]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('volup','voldown','input','app','off','wake','key','info')]
    [string]$Action,

    [string]$Value = '',

    [int]$Steps = 1
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$functionsPath = Join-Path $scriptDir 'tv-functions.ps1'
if (-not (Test-Path $functionsPath)) {
    Write-Error "tv-functions.ps1 not found at $functionsPath"
    exit 1
}
. $functionsPath

switch ($Action) {
    'volup'   { Set-TVVolume -Direction Up   -Steps $Steps }
    'voldown' { Set-TVVolume -Direction Down -Steps $Steps }
    'input'   { Set-TVInput  -InputSource $Value }
    'app'     { Start-TVApp  -AppId $Value }
    'off'     { Stop-TV }
    'wake'    { Start-TV }
    'key'     { Send-TVKey   -KeyName $Value }
    'info'    { Get-TVInfo }
}
