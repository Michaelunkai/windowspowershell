# Fix Microphone & Voice Typing - Fresh Windows 11 Install
# Run as Administrator

#Requires -RunAsAdministrator

Write-Host "=== Microphone Fix for Fresh Win11 ===" -ForegroundColor Cyan

# 1. Remove ALL policy restrictions
Write-Host "[1/6] Removing all policy restrictions..." -ForegroundColor Yellow
$policyPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy",
    "HKCU:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy",
    "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Privacy\LetAppsAccessMicrophone",
    "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Privacy"
)
foreach ($p in $policyPaths) {
    if (Test-Path $p) {
        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Removed: $p" -ForegroundColor Green
    }
}

# 2. Enable system microphone (critical for "managed by org" fix)
Write-Host "[2/6] Enabling system microphone..." -ForegroundColor Yellow
$paths = @{
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" = "Allow"
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" = "Allow"
}
foreach ($path in $paths.Keys) {
    if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name "Value" -Value $paths[$path] -Force
    # Also enable NonPackaged for desktop apps
    $np = "$path\NonPackaged"
    if (!(Test-Path $np)) { New-Item -Path $np -Force | Out-Null }
    Set-ItemProperty -Path $np -Name "Value" -Value "Allow" -Force
}
Write-Host "  Microphone access: ENABLED" -ForegroundColor Green

# 3. Legacy device access
Write-Host "[3/6] Setting legacy device access..." -ForegroundColor Yellow
$legacyPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{2EEF81BE-33FA-4800-9670-1CD474972C3F}"
if (!(Test-Path $legacyPath)) { New-Item -Path $legacyPath -Force | Out-Null }
Set-ItemProperty -Path $legacyPath -Name "Value" -Value "Allow" -Force
Write-Host "  Legacy access: ENABLED" -ForegroundColor Green

# 4. Voice typing / speech settings
Write-Host "[4/6] Enabling voice typing (Win+H)..." -ForegroundColor Yellow
$voicePaths = @{
    "HKCU:\Software\Microsoft\InputPersonalization" = @{
        "RestrictImplicitTextCollection" = 0
        "RestrictImplicitInkCollection" = 0
    }
    "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" = @{
        "HarvestContacts" = 1
    }
    "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" = @{
        "HasAccepted" = 1
    }
}
foreach ($path in $voicePaths.Keys) {
    if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    foreach ($name in $voicePaths[$path].Keys) {
        Set-ItemProperty -Path $path -Name $name -Value $voicePaths[$path][$name] -Type DWord -Force
    }
}
Write-Host "  Voice typing: ENABLED" -ForegroundColor Green

# 5. Restart services
Write-Host "[5/6] Restarting audio services..." -ForegroundColor Yellow
Restart-Service Audiosrv -Force -ErrorAction SilentlyContinue
Restart-Service AudioEndpointBuilder -Force -ErrorAction SilentlyContinue
Stop-Process -Name "SystemSettings","SearchApp","TextInputHost" -Force -ErrorAction SilentlyContinue
Write-Host "  Services restarted" -ForegroundColor Green

# 6. Force policy update
Write-Host "[6/6] Applying policy update..." -ForegroundColor Yellow
gpupdate /force 2>$null | Out-Null
Write-Host "  Policy updated" -ForegroundColor Green

# Verify
Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan
$sysMic = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -Name Value -EA SilentlyContinue).Value
$usrMic = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -Name Value -EA SilentlyContinue).Value
$voice = (Get-ItemProperty "HKCU:\Software\Microsoft\InputPersonalization" -Name RestrictImplicitTextCollection -EA SilentlyContinue).RestrictImplicitTextCollection
Write-Host "System Mic: $(if($sysMic -eq 'Allow'){'ON'}else{'OFF'})" -ForegroundColor $(if($sysMic -eq 'Allow'){'Green'}else{'Red'})
Write-Host "User Mic:   $(if($usrMic -eq 'Allow'){'ON'}else{'OFF'})" -ForegroundColor $(if($usrMic -eq 'Allow'){'Green'}else{'Red'})
Write-Host "Voice Type: $(if($voice -eq 0){'ON'}else{'OFF'})" -ForegroundColor $(if($voice -eq 0){'Green'}else{'Red'})

Write-Host "`nDONE! Reopen Settings or reboot if needed." -ForegroundColor Green
