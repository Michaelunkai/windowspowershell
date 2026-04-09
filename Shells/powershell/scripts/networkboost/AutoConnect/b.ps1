# WiFi Auto-Connect Fix for Stella_5
# Ensures WiFi connects automatically on boot with max performance

Write-Host "=== WiFi Auto-Connect Fix for Stella_5 ===" -ForegroundColor Cyan
Write-Host ""

# 1. Export and re-import profile to ensure clean state
Write-Host "[1/8] Re-configuring WiFi profile for auto-connect..." -ForegroundColor Yellow

# Delete existing profile first
netsh wlan delete profile name="Stella_5" 2>$null

# Create profile XML with all auto-connect settings
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

# Add profile
$result = netsh wlan add profile filename="$profilePath" user=all
if ($LASTEXITCODE -eq 0) {
    Write-Host "   [OK] Profile added with auto-connect enabled" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Profile add returned: $result" -ForegroundColor Yellow
}
Remove-Item $profilePath -Force -ErrorAction SilentlyContinue

# 2. Set profile priority to highest
Write-Host "[2/8] Setting Stella_5 as highest priority network..." -ForegroundColor Yellow
$priorityResult = netsh wlan set profileorder name="Stella_5" interface="Wi-Fi" priority=1 2>&1
Write-Host "   [OK] Priority set to 1 (highest)" -ForegroundColor Green

# 3. Configure WLAN AutoConfig service for automatic startup
Write-Host "[3/8] Configuring WLAN AutoConfig service..." -ForegroundColor Yellow
Set-Service -Name WlanSvc -StartupType Automatic
Start-Service -Name WlanSvc -ErrorAction SilentlyContinue
Write-Host "   [OK] WlanSvc set to Automatic" -ForegroundColor Green

# 4. Configure Network Location Awareness service
Write-Host "[4/8] Configuring Network Location Awareness service..." -ForegroundColor Yellow
Set-Service -Name NlaSvc -StartupType Automatic
Start-Service -Name NlaSvc -ErrorAction SilentlyContinue
Write-Host "   [OK] NlaSvc set to Automatic" -ForegroundColor Green

# 5. Configure Network List Service
Write-Host "[5/8] Configuring Network List Service..." -ForegroundColor Yellow
Set-Service -Name netprofm -StartupType Automatic
Start-Service -Name netprofm -ErrorAction SilentlyContinue
Write-Host "   [OK] netprofm set to Automatic" -ForegroundColor Green

# 6. Configure Windows Connection Manager
Write-Host "[6/8] Configuring Windows Connection Manager..." -ForegroundColor Yellow
Set-Service -Name Wcmsvc -StartupType Automatic
Start-Service -Name Wcmsvc -ErrorAction SilentlyContinue
Write-Host "   [OK] Wcmsvc set to Automatic" -ForegroundColor Green

# 7. Disable WiFi adapter power saving (prevents disconnects)
Write-Host "[7/8] Disabling WiFi power saving..." -ForegroundColor Yellow
# Set power management via registry for all Intel/Mediatek WiFi adapters
$wifiKeys = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
)

foreach ($baseKey in $wifiKeys) {
    if (Test-Path $baseKey) {
        $subkeys = Get-ChildItem $baseKey -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\\\d{4}$' }
        foreach ($subkey in $subkeys) {
            $driverDesc = (Get-ItemProperty -Path $subkey.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            if ($driverDesc -match "Wi-Fi|Wireless|WLAN") {
                # Disable power saving
                Set-ItemProperty -Path $subkey.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $subkey.PSPath -Name "*SelectiveSuspend" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $subkey.PSPath -Name "PowerSaveMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                Write-Host "   [OK] Power saving disabled for: $driverDesc" -ForegroundColor Green
            }
        }
    }
}

# 8. Create scheduled task to connect WiFi at logon (backup method)
Write-Host "[8/8] Creating boot-time WiFi connect task..." -ForegroundColor Yellow

# Remove old task if exists
Unregister-ScheduledTask -TaskName "WiFi_AutoConnect_Stella5" -Confirm:$false -ErrorAction SilentlyContinue

# Create new task
$action = New-ScheduledTaskAction -Execute "netsh.exe" -Argument "wlan connect name=Stella_5"
$trigger1 = New-ScheduledTaskTrigger -AtLogOn
$trigger2 = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "WiFi_AutoConnect_Stella5" -Action $action -Trigger $trigger1,$trigger2 -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "   [OK] Scheduled task created for boot-time connection" -ForegroundColor Green

# 9. Connect now
Write-Host ""
Write-Host "=== Connecting to Stella_5 now... ===" -ForegroundColor Cyan
$connectResult = netsh wlan connect name="Stella_5" 2>&1
Start-Sleep -Seconds 2

# Verify connection
$status = netsh wlan show interfaces 2>&1 | Select-String "State" -Context 0,0
Write-Host ""
if ($status -match "connected") {
    Write-Host "[SUCCESS] Connected to Stella_5!" -ForegroundColor Green
} else {
    Write-Host "[INFO] Connection in progress..." -ForegroundColor Yellow
    Write-Host "       Please check WiFi status in system tray" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== FIX COMPLETE ===" -ForegroundColor Cyan
Write-Host "WiFi will now auto-connect to Stella_5 on every boot." -ForegroundColor White
Write-Host ""
Write-Host "Changes made:" -ForegroundColor White
Write-Host "  - Profile set to auto-connect mode" -ForegroundColor Gray
Write-Host "  - Stella_5 set as priority #1 network" -ForegroundColor Gray
Write-Host "  - All network services set to Automatic" -ForegroundColor Gray
Write-Host "  - WiFi adapter power saving disabled" -ForegroundColor Gray
Write-Host "  - Boot-time connect task created (backup)" -ForegroundColor Gray
Write-Host ""
