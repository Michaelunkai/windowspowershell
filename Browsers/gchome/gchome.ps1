<#
.SYNOPSIS
    gchome
#>
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$prefsPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"
$prefs = Get-Content -Path $prefsPath -Raw | ConvertFrom-Json
$prefs.homepage = "https://chatgpt.com/"
$prefs.homepage_is_newtabpage = $false
if ($prefs.session -eq $null) { $prefs | Add-Member -Type NoteProperty -Name "session" -Value @{} }
if ($prefs.session.startup_urls -eq $null) { $prefs.session | Add-Member -Type NoteProperty -Name "startup_urls" -Value @() }
$prefs.session.startup_urls = @("https://chatgpt.com/")
$prefs.session.restore_on_startup = 4
$prefs | ConvertTo-Json -Depth 100 | Set-Content -Path $prefsPath
Write-Output "Chrome homepage set to https://chatgpt.com/"
