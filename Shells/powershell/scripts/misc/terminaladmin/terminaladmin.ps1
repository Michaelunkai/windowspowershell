<#
.SYNOPSIS
    terminaladmin
#>
$settings = Get-Content "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" | ConvertFrom-Json; $settings.profiles.defaults | Add-Member -NotePropertyName "elevate" -NotePropertyValue $true -Force; $settings | ConvertTo-Json -Depth 10 | Set-Content "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
