<#
.SYNOPSIS
    ffpop
#>
$profilePath = (Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles\" -Filter "*.default*" | Select-Object -First 1).FullName; if ($profilePath) { @('user_pref("dom.disable_open_during_load", true);', 'user_pref("dom.popup_allowed_events", "click dblclick mousedown pointerdown");', 'user_pref("privacy.popups.showBrowserMessage", false);', 'user_pref("network.protocol-handler.external.magnet", true);', 'user_pref("network.protocol-handler.expose.magnet", false);', 'user_pref("network.protocol-handler.warn-external.magnet", false);') | Out-File -FilePath "$profilePath\user.js" -Encoding ASCII; Write-Host "Magnet links enabled in Firefox: $profilePath\user.js" } else { Write-Host "Firefox profile not found. Please run Firefox at least once to create a profile." }
