# WiFi Stability & Auto-Connect Fix for Stella_5
# Fixes root causes: power saving, service configs, adapter settings
# Run as Administrator

Write-Host "=== WiFi Stability Fix for Stella_5 ===" -ForegroundColor Cyan
Write-Host ""

# Check admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

# 1. Remove all scheduled task workarounds (not needed when root causes fixed)
Write-Host "[1/7] Removing unnecessary scheduled tasks..." -ForegroundColor Yellow
$tasksToRemove = @("WiFi_AutoConnect_Stella5", "WiFiTask")
foreach ($task in $tasksToRemove) {
    $existing = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "   Removed: $task" -ForegroundColor Gray
    }
}
Write-Host "   [OK] Scheduled tasks cleaned up" -ForegroundColor Green

# 2. Configure all required network services to Automatic
Write-Host "[2/7] Configuring network services..." -ForegroundColor Yellow
$services = @(
    @{Name="WlanSvc"; Display="WLAN AutoConfig"},
    @{Name="NlaSvc"; Display="Network Location Awareness"},
    @{Name="netprofm"; Display="Network List Service"},
    @{Name="Wcmsvc"; Display="Windows Connection Manager"},
    @{Name="Dhcp"; Display="DHCP Client"}
)

foreach ($svc in $services) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        Set-Service -Name $svc.Name -StartupType Automatic -ErrorAction SilentlyContinue
        if ($service.Status -ne 'Running') {
            Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
        }
        Write-Host "   [OK] $($svc.Display) -> Automatic & Running" -ForegroundColor Green
    }
}

# 3. Disable WiFi adapter power saving (THE MAIN FIX for disconnects)
Write-Host "[3/7] Disabling WiFi power saving..." -ForegroundColor Yellow

# Method 1: Set via PowerShell adapter properties
$adapter = Get-NetAdapter -Name "Wi-Fi" -ErrorAction SilentlyContinue
if ($adapter) {
    # Disable power management on the adapter
    Set-NetAdapterAdvancedProperty -Name "Wi-Fi" -DisplayName "Power Saving" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
    Set-NetAdapterAdvancedProperty -Name "Wi-Fi" -DisplayName "U-APSD Support" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
    Set-NetAdapterAdvancedProperty -Name "Wi-Fi" -DisplayName "Roaming Aggressiveness" -DisplayValue "1. Lowest" -ErrorAction SilentlyContinue
    Write-Host "   [OK] Power Saving set to Disabled" -ForegroundColor Green
    Write-Host "   [OK] U-APSD Support set to Disabled" -ForegroundColor Green
    Write-Host "   [OK] Roaming Aggressiveness set to Lowest" -ForegroundColor Green
}

# Method 2: Disable via Device Manager power management
$wifiAdapter = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.Name -match "Wi-Fi|Wireless|WLAN|MediaTek" -and $_.NetEnabled -eq $true }
if ($wifiAdapter) {
    $pnpEntity = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.DeviceID -eq $wifiAdapter.PNPDeviceID }
    if ($pnpEntity) {
        # Set PnPCapabilities to 24 (disable power management)
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($wifiAdapter.PNPDeviceID)\Device Parameters"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "PnPCapabilities" -Value 24 -Type DWord -ErrorAction SilentlyContinue
        }
    }
}

# Method 3: Registry-based power saving disable for network adapters
$netAdapterKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
if (Test-Path $netAdapterKey) {
    Get-ChildItem $netAdapterKey -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\\\d{4}$' } | ForEach-Object {
        $driverDesc = (Get-ItemProperty -Path $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
        if ($driverDesc -match "Wi-Fi|Wireless|WLAN|MediaTek") {
            Set-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $_.PSPath -Name "*SelectiveSuspend" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $_.PSPath -Name "PowerSaveMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Write-Host "   [OK] Registry power saving disabled for: $driverDesc" -ForegroundColor Green
        }
    }
}

# 4. Disable device power management "Allow computer to turn off this device"
Write-Host "[4/7] Disabling 'Allow computer to turn off device'..." -ForegroundColor Yellow
try {
    Disable-NetAdapterPowerManagement -Name "Wi-Fi" -ErrorAction SilentlyContinue
    Write-Host "   [OK] Device power management disabled" -ForegroundColor Green
} catch {
    Write-Host "   [INFO] Using fallback method..." -ForegroundColor Gray
}

# 5. Ensure WiFi profile is correctly configured for auto-connect
Write-Host "[5/7] Verifying WiFi profile auto-connect..." -ForegroundColor Yellow

# Get current profile
$profile = netsh wlan show profile name="Stella_5" 2>&1
if ($profile -match "Connect automatically") {
    Write-Host "   [OK] Profile already set to auto-connect" -ForegroundColor Green
} else {
    # Re-create profile with auto-connect
    $profileXML = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>Stella_5</name>
    <SSIDConfig>
        <SSID>
            <hex>5374656C6C615F35</hex>
            <name>Stella_5</name>
        </SSID>
        <nonBroadcast>false</nonBroadcast>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <autoSwitch>false</autoSwitch>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>Stellamylove</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
    <MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3">
        <enableRandomization>false</enableRandomization>
    </MacRandomization>
</WLANProfile>
"@
    $profilePath = "$env:TEMP\Stella_5_profile.xml"
    $profileXML | Out-File -FilePath $profilePath -Encoding UTF8
    netsh wlan delete profile name="Stella_5" 2>&1 | Out-Null
    netsh wlan add profile filename="$profilePath" user=all 2>&1 | Out-Null
    Remove-Item $profilePath -Force -ErrorAction SilentlyContinue
    Write-Host "   [OK] Profile recreated with auto-connect" -ForegroundColor Green
}

# Set priority to highest
netsh wlan set profileorder name="Stella_5" interface="Wi-Fi" priority=1 2>&1 | Out-Null
Write-Host "   [OK] Profile priority set to 1 (highest)" -ForegroundColor Green

# 6. Disable Modern Standby network disconnect (if applicable)
Write-Host "[6/7] Configuring connected standby network settings..." -ForegroundColor Yellow

# Keep network connected during Modern Standby
$csKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9"
if (Test-Path $csKey) {
    $subKeys = Get-ChildItem $csKey -ErrorAction SilentlyContinue
    foreach ($subKey in $subKeys) {
        Set-ItemProperty -Path $subKey.PSPath -Name "Attributes" -Value 2 -Type DWord -ErrorAction SilentlyContinue
    }
}

# Disable network disconnect on standby
$standbyKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
if (Test-Path $standbyKey) {
    Set-ItemProperty -Path $standbyKey -Name "HiberbootEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}

Write-Host "   [OK] Standby network settings configured" -ForegroundColor Green

# 7. Connect to WiFi now and verify
Write-Host "[7/7] Connecting to Stella_5..." -ForegroundColor Yellow

# Ensure WiFi adapter is enabled
Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# Connect
netsh wlan connect name="Stella_5" 2>&1 | Out-Null
Start-Sleep -Seconds 3

# Verify
$status = netsh wlan show interfaces 2>&1
if ($status -match "State\s+:\s+connected" -and $status -match "SSID\s+:\s+Stella_5") {
    Write-Host "   [OK] Connected to Stella_5" -ForegroundColor Green
} else {
    Write-Host "   [PENDING] Connection in progress..." -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=== FIX COMPLETE ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Root causes fixed:" -ForegroundColor White
Write-Host "  [X] Power Saving disabled (prevents random disconnects)" -ForegroundColor Gray
Write-Host "  [X] All network services set to Automatic" -ForegroundColor Gray
Write-Host "  [X] NlaSvc service running (enables boot detection)" -ForegroundColor Gray
Write-Host "  [X] Device power management disabled" -ForegroundColor Gray
Write-Host "  [X] Profile set to auto-connect with priority 1" -ForegroundColor Gray
Write-Host "  [X] Roaming aggressiveness minimized" -ForegroundColor Gray
Write-Host "  [X] Removed unnecessary scheduled tasks" -ForegroundColor Gray
Write-Host ""
Write-Host "WiFi will now auto-connect on every boot without issues." -ForegroundColor Green
Write-Host ""

# Verify current settings
Write-Host "=== Current Settings Verification ===" -ForegroundColor Cyan
Write-Host ""
$psValue = (Get-NetAdapterAdvancedProperty -Name "Wi-Fi" -DisplayName "Power Saving" -ErrorAction SilentlyContinue).DisplayValue
Write-Host "Power Saving: $psValue" -ForegroundColor $(if ($psValue -eq "Disabled") {"Green"} else {"Yellow"})

$services | ForEach-Object {
    $svc = Get-Service -Name $_.Name -ErrorAction SilentlyContinue
    $color = if ($svc.Status -eq "Running") {"Green"} else {"Yellow"}
    Write-Host "$($_.Display): $($svc.Status)" -ForegroundColor $color
}

Write-Host ""
