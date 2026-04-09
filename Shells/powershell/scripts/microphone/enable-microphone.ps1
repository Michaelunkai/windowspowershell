# Enable Microphone Access Script
# Removes organization policy restrictions and enables mic access
# Run as Administrator!

#Requires -RunAsAdministrator

Write-Host "=== Microphone Access Enabler ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/5] Removing Group Policy restrictions..." -ForegroundColor Yellow

# Remove GPO restrictions for microphone
$gpoPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy",
    "HKCU:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
)

foreach ($path in $gpoPaths) {
    if (Test-Path $path) {
        # Remove microphone-related policy values
        $micPolicies = @(
            "LetAppsAccessMicrophone",
            "LetAppsAccessMicrophone_UserInControlOfTheseApps",
            "LetAppsAccessMicrophone_ForceAllowTheseApps",
            "LetAppsAccessMicrophone_ForceDenyTheseApps"
        )
        foreach ($policy in $micPolicies) {
            try {
                Remove-ItemProperty -Path $path -Name $policy -ErrorAction SilentlyContinue
                Write-Host "  Removed: $path\$policy" -ForegroundColor Green
            } catch {
                # Policy doesn't exist, that's fine
            }
        }
    }
}

Write-Host ""
Write-Host "[2/5] Enabling global microphone access..." -ForegroundColor Yellow

# Main microphone capability settings
$capabilityPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"

if (-not (Test-Path $capabilityPath)) {
    New-Item -Path $capabilityPath -Force | Out-Null
}

# Enable global microphone access
Set-ItemProperty -Path $capabilityPath -Name "Value" -Value "Allow" -Type String -Force
Write-Host "  Set global microphone access to ALLOW" -ForegroundColor Green

Write-Host ""
Write-Host "[3/5] Enabling microphone for desktop apps..." -ForegroundColor Yellow

# Enable for non-packaged (desktop) apps
$desktopPath = "$capabilityPath\NonPackaged"
if (-not (Test-Path $desktopPath)) {
    New-Item -Path $desktopPath -Force | Out-Null
}
Set-ItemProperty -Path $desktopPath -Name "Value" -Value "Allow" -Type String -Force
Write-Host "  Desktop apps microphone access ENABLED" -ForegroundColor Green

Write-Host ""
Write-Host "[4/5] Enabling microphone for UWP/Store apps..." -ForegroundColor Yellow

# Enable for all packaged apps in the consent store
$packagesPath = $capabilityPath
Get-ChildItem -Path $packagesPath -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.PSIsContainer -and $_.Name -ne "NonPackaged") {
        $appPath = $_.PSPath
        Set-ItemProperty -Path $appPath -Name "Value" -Value "Allow" -Type String -Force -ErrorAction SilentlyContinue
        Write-Host "  Enabled for: $($_.Name)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "[5/5] Updating current user settings..." -ForegroundColor Yellow

# Current user consent store
$userCapPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"

if (-not (Test-Path $userCapPath)) {
    New-Item -Path $userCapPath -Force | Out-Null
}
Set-ItemProperty -Path $userCapPath -Name "Value" -Value "Allow" -Type String -Force
Write-Host "  User-level microphone access ENABLED" -ForegroundColor Green

# Also set the legacy privacy settings
$privacyPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"
if (-not (Test-Path $privacyPath)) {
    New-Item -Path $privacyPath -Force | Out-Null
}

# Remove any device census restrictions
$deviceCensusPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata"
if (Test-Path $deviceCensusPath) {
    Set-ItemProperty -Path $deviceCensusPath -Name "PreventDeviceMetadataFromNetwork" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Microphone access has been enabled!" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: If settings are still grayed out, your organization may be" -ForegroundColor Yellow
Write-Host "enforcing policies via MDM (Intune/Azure AD). In that case:" -ForegroundColor Yellow
Write-Host "  1. Contact your IT administrator, OR" -ForegroundColor White
Write-Host "  2. Disconnect from organization management (if personal device)" -ForegroundColor White
Write-Host ""
Write-Host "Restart your computer for all changes to take effect." -ForegroundColor Cyan
Write-Host ""

# Optionally refresh group policy
Write-Host "Refreshing Group Policy..." -ForegroundColor Yellow
gpupdate /force 2>$null

Write-Host ""
Write-Host "Done! Please restart your PC." -ForegroundColor Green
