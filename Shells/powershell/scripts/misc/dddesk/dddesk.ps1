<#
.SYNOPSIS
    dddesk
#>
Get-ChildItem "$env:USERPROFILE\Desktop","$env:PUBLIC\Desktop" -Force -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue; & F:\study\shells\powershell\scripts\DesktopOrganizer\a.ps1
