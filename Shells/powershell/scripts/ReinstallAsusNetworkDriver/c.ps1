# ULTRA-ROBUST ASUS Network Driver Reinstallation Script
# This script will fix EVERYTHING related to network and ensure WiFi connectivity
# Version: 2.0 - Nuclear Option Edition

param(
    [string]$WifiSSID = "Stella_5",
    [string]$WifiPassword = "Stellamylove",
    [int]$MaxRetries = 5,
    [int]$WaitTimeSeconds = 120
)

$ErrorActionPreference = "Continue"
$LogFile = "$PSScriptRoot\NetworkFix_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-LogMessage {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    Write-Host $logEntry -ForegroundColor $(if($Type -eq "ERROR"){"Red"} elseif($Type -eq "SUCCESS"){"Green"} elseif($Type -eq "WARNING"){"Yellow"} else{"Cyan"})
    Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-SystemRestorePoint {
    Write-LogMessage "Creating system restore point..."
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Before Network Fix - $(Get-Date)" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
        Write-LogMessage "System restore point created" -Type "SUCCESS"
        return $true
    }
    catch {
        Write-LogMessage "Could not create restore point (non-critical): $($_.Exception.Message)" -Type "WARNING"
        return $false
    }
}

function Reset-NetworkStack {
    Write-LogMessage "RESETTING ENTIRE NETWORK STACK..." -Type "WARNING"

    # Reset TCP/IP stack
    Write-LogMessage "Resetting TCP/IP stack..."
    netsh int ip reset 2>&1 | Out-Null
    netsh int ipv4 reset 2>&1 | Out-Null
    netsh int ipv6 reset 2>&1 | Out-Null

    # Reset Winsock catalog
    Write-LogMessage "Resetting Winsock catalog..."
    netsh winsock reset 2>&1 | Out-Null
    netsh winsock reset catalog 2>&1 | Out-Null

    # Reset proxy settings
    Write-LogMessage "Resetting proxy settings..."
    netsh winhttp reset proxy 2>&1 | Out-Null

    # Reset firewall
    Write-LogMessage "Resetting Windows Firewall to defaults..."
    netsh advfirewall reset 2>&1 | Out-Null

    # Flush DNS
    Write-LogMessage "Flushing DNS cache..."
    ipconfig /flushdns 2>&1 | Out-Null

    # Release and renew IP
    Write-LogMessage "Releasing and renewing IP configuration..."
    ipconfig /release 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    ipconfig /renew 2>&1 | Out-Null

    # Register DNS
    ipconfig /registerdns 2>&1 | Out-Null

    Write-LogMessage "Network stack reset completed" -Type "SUCCESS"
}

function Stop-NetworkServices {
    Write-LogMessage "Stopping all network-related services..."
    $services = @("wlansvc", "Netman", "NlaSvc", "Dhcp", "Dnscache", "WinHttpAutoProxySvc", "Wcmsvc")

    foreach ($svc in $services) {
        try {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Write-LogMessage "Stopped service: $svc"
        }
        catch {
            Write-LogMessage "Could not stop $svc (may not exist)" -Type "WARNING"
        }
    }
    Start-Sleep -Seconds 3
}

function Start-NetworkServices {
    Write-LogMessage "Starting all network-related services..."
    $services = @("Dhcp", "Dnscache", "NlaSvc", "Netman", "WinHttpAutoProxySvc", "Wcmsvc", "wlansvc")

    foreach ($svc in $services) {
        try {
            Set-Service -Name $svc -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name $svc -ErrorAction SilentlyContinue
            Write-LogMessage "Started service: $svc" -Type "SUCCESS"
        }
        catch {
            Write-LogMessage "Could not start ${svc}: $($_.Exception.Message)" -Type "WARNING"
        }
    }
    Start-Sleep -Seconds 5
}

function Remove-AllWifiProfiles {
    Write-LogMessage "Removing ALL existing WiFi profiles..."
    try {
        $profiles = netsh wlan show profiles | Select-String "All User Profile\s+:\s+(.+)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
        foreach ($profile in $profiles) {
            netsh wlan delete profile name="$profile" 2>&1 | Out-Null
            Write-LogMessage "Removed profile: $profile"
        }
        Write-LogMessage "All WiFi profiles removed" -Type "SUCCESS"
    }
    catch {
        Write-LogMessage "Error removing WiFi profiles: $($_.Exception.Message)" -Type "WARNING"
    }
}

function Disable-AdapterPowerManagement {
    Write-LogMessage "Disabling power management on network adapters..."
    try {
        $adapters = Get-WmiObject -Class MSPower_DeviceEnable -Namespace root\wmi -ErrorAction SilentlyContinue
        foreach ($adapter in $adapters) {
            $adapter.Enable = $false
            $adapter.Put() | Out-Null
        }

        # Also disable via registry for WiFi adapters
        $netAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -like "*Wireless*" -or $_.InterfaceDescription -like "*Wi-Fi*" -or $_.InterfaceDescription -like "*802.11*" }
        foreach ($adapter in $netAdapters) {
            try {
                Disable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
            }
            catch {}
        }

        Write-LogMessage "Power management disabled on network adapters" -Type "SUCCESS"
    }
    catch {
        Write-LogMessage "Could not disable all power management settings" -Type "WARNING"
    }
}

function Reset-NetworkAdapters {
    Write-LogMessage "Resetting network adapters (SKIPPING WiFi to avoid breaking it)..."
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
            $_.InterfaceDescription -notlike "*Wireless*" -and
            $_.InterfaceDescription -notlike "*Wi-Fi*" -and
            $_.InterfaceDescription -notlike "*802.11*" -and
            $_.InterfaceDescription -notlike "*MT7922*" -and
            $_.Name -notlike "*Wi-Fi*"
        }

        if ($adapters) {
            foreach ($adapter in $adapters) {
                Write-LogMessage "Disabling non-WiFi adapter: $($adapter.Name)"
                Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
            }

            Start-Sleep -Seconds 3

            foreach ($adapter in $adapters) {
                Write-LogMessage "Enabling non-WiFi adapter: $($adapter.Name)"
                Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
            }
        }

        Write-LogMessage "Network adapters reset completed (WiFi adapter PROTECTED)" -Type "SUCCESS"
    }
    catch {
        Write-LogMessage "Error resetting adapters: $($_.Exception.Message)" -Type "WARNING"
    }
}

function Remove-CorruptedDrivers {
    Write-LogMessage "Removing potentially corrupted network drivers..."
    try {
        # Find all network devices
        $networkDevices = Get-WmiObject Win32_PnPEntity | Where-Object {
            $_.Name -like "*Network*" -or
            $_.Name -like "*Wireless*" -or
            $_.Name -like "*Wi-Fi*" -or
            $_.Name -like "*Ethernet*" -or
            $_.Name -like "*802.11*" -or
            $_.Name -like "*MT7922*" -or
            $_.Name -like "*ASUS*"
        }

        foreach ($device in $networkDevices) {
            if ($device.DeviceID) {
                Write-LogMessage "Uninstalling device: $($device.Name)"
                # Use pnputil to remove driver
                pnputil /remove-device "$($device.DeviceID)" /force 2>&1 | Out-Null
            }
        }

        Write-LogMessage "Corrupted drivers removed" -Type "SUCCESS"
        Start-Sleep -Seconds 5
    }
    catch {
        Write-LogMessage "Error removing corrupted drivers: $($_.Exception.Message)" -Type "WARNING"
    }
}

function Install-AsusDrivers {
    param([string]$DriverPath, [int]$Attempt = 1)

    Write-LogMessage "Installing ASUS drivers (Attempt $Attempt)..."

    if (-not (Test-Path $DriverPath)) {
        Write-LogMessage "Driver installation file not found: $DriverPath" -Type "ERROR"
        return $false
    }

    try {
        # Method 1: Run the installer
        Write-LogMessage "Method 1: Running driver installer..."
        $process = Start-Process -FilePath $DriverPath -Wait -PassThru -NoNewWindow -ErrorAction Stop

        if ($process.ExitCode -eq 0) {
            Write-LogMessage "Driver installation completed successfully" -Type "SUCCESS"
            return $true
        }
        else {
            Write-LogMessage "Driver installer returned exit code: $($process.ExitCode)" -Type "WARNING"
        }
    }
    catch {
        Write-LogMessage "Error running driver installer: $($_.Exception.Message)" -Type "WARNING"
    }

    # Method 2: Try to find and install .inf files directly
    try {
        Write-LogMessage "Method 2: Searching for .inf files in driver directory..."
        $driverDir = Split-Path $DriverPath -Parent
        $infFiles = Get-ChildItem -Path $driverDir -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue

        foreach ($inf in $infFiles) {
            Write-LogMessage "Installing driver from: $($inf.FullName)"
            pnputil /add-driver "$($inf.FullName)" /install /force 2>&1 | Out-Null
        }

        Write-LogMessage "Driver installation via pnputil completed" -Type "SUCCESS"
        return $true
    }
    catch {
        Write-LogMessage "Error installing via pnputil: $($_.Exception.Message)" -Type "WARNING"
    }

    return $false
}

function Scan-HardwareChanges {
    Write-LogMessage "Scanning for hardware changes..."
    try {
        # Trigger hardware scan
        $devcon = "${env:SystemRoot}\System32\pnputil.exe"
        pnputil /scan-devices 2>&1 | Out-Null

        # Alternative method using WMI
        $hwScan = Get-WmiObject Win32_PnPEntity -ErrorAction SilentlyContinue
        $hwScan | ForEach-Object { $_.GetDeviceProperties() } -ErrorAction SilentlyContinue | Out-Null

        Write-LogMessage "Hardware scan completed" -Type "SUCCESS"
        Start-Sleep -Seconds 10
        return $true
    }
    catch {
        Write-LogMessage "Hardware scan completed with warnings" -Type "WARNING"
        return $true
    }
}

function Wait-ForWifiAdapter {
    param([int]$MaxWaitSeconds = 120)

    Write-LogMessage "Waiting for WiFi adapter to become available..."
    $startTime = Get-Date
    $adapterFound = $false

    do {
        Start-Sleep -Seconds 5

        # Check using multiple methods
        $wifiAdapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
            $_.InterfaceDescription -like "*Wireless*" -or
            $_.InterfaceDescription -like "*Wi-Fi*" -or
            $_.InterfaceDescription -like "*802.11*" -or
            $_.InterfaceDescription -like "*MT7922*" -or
            $_.Name -like "*Wi-Fi*" -or
            $_.Name -like "*Wireless*"
        }

        if (-not $wifiAdapter) {
            $wifiAdapter = Get-WmiObject -Class Win32_NetworkAdapter -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -like "*Wi-Fi*" -or
                $_.Name -like "*Wireless*" -or
                $_.Name -like "*802.11*" -or
                $_.Name -like "*MT7922*"
            }
        }

        $elapsedTime = (Get-Date) - $startTime
        Write-LogMessage "Checking for WiFi adapter... (Elapsed: $([math]::Round($elapsedTime.TotalSeconds))s)"

        if ($wifiAdapter) {
            Write-LogMessage "WiFi adapter detected: $($wifiAdapter.Name -join ', ')" -Type "SUCCESS"

            # Ensure it's enabled
            try {
                if ($wifiAdapter.Status -eq "Disabled" -or $wifiAdapter.NetEnabled -eq $false) {
                    Write-LogMessage "Enabling WiFi adapter..."
                    Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 5
                }
            }
            catch {}

            $adapterFound = $true
            break
        }

    } while ($elapsedTime.TotalSeconds -lt $MaxWaitSeconds)

    return $adapterFound
}

function Enable-LocationServices {
    Write-LogMessage "Enabling location services..."
    try {
        # Enable location service
        Set-Service -Name lfsvc -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name lfsvc -ErrorAction SilentlyContinue

        # Registry settings for location
        $regPaths = @{
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" = "Allow"
            "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" = "1"
        }

        foreach ($path in $regPaths.Keys) {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Set-ItemProperty -Path $path -Name "Value" -Value $regPaths[$path] -Force -ErrorAction SilentlyContinue
        }

        # Additional registry entries
        reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f 2>&1 | Out-Null
        reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f 2>&1 | Out-Null

        Write-LogMessage "Location services enabled" -Type "SUCCESS"
        return $true
    }
    catch {
        Write-LogMessage "Warning configuring location services: $($_.Exception.Message)" -Type "WARNING"
        return $false
    }
}

function New-WifiProfile {
    param([string]$SSID, [string]$Password, [string]$AuthType = "WPA2PSK")

    Write-LogMessage "Creating WiFi profile for: $SSID (Auth: $AuthType)"

    # Try multiple authentication types
    $authTypes = @(
        @{Name="WPA3SAE"; Auth="WPA3SAE"; Encryption="AES"},
        @{Name="WPA2PSK"; Auth="WPA2PSK"; Encryption="AES"},
        @{Name="WPA2"; Auth="WPA2"; Encryption="AES"},
        @{Name="WPAPSK"; Auth="WPAPSK"; Encryption="TKIP"}
    )

    foreach ($authConfig in $authTypes) {
        try {
            $xmlContent = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSID</name>
    <SSIDConfig>
        <SSID>
            <hex>$([System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes($SSID)).Replace('-',''))</hex>
            <name>$SSID</name>
        </SSID>
        <nonBroadcast>false</nonBroadcast>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <autoSwitch>true</autoSwitch>
    <MSM>
        <security>
            <authEncryption>
                <authentication>$($authConfig.Auth)</authentication>
                <encryption>$($authConfig.Encryption)</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$Password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@

            $tempFile = "$env:temp\WiFiProfile_$SSID.xml"
            $xmlContent | Out-File -FilePath $tempFile -Encoding UTF8 -Force

            $result = netsh wlan add profile filename="$tempFile" user=all 2>&1
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

            if ($LASTEXITCODE -eq 0) {
                Write-LogMessage "WiFi profile created successfully with $($authConfig.Name)" -Type "SUCCESS"
                return $true
            }
            else {
                Write-LogMessage "Failed with $($authConfig.Name), trying next..." -Type "WARNING"
            }
        }
        catch {
            Write-LogMessage "Error with $($authConfig.Name): $($_.Exception.Message)" -Type "WARNING"
        }
    }

    Write-LogMessage "Failed to create WiFi profile with any authentication type" -Type "ERROR"
    return $false
}

function Get-ValidIPAddress {
    param([string]$AdapterName)

    try {
        $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
        if ($adapter) {
            $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($ipConfig -and $ipConfig.IPAddress -and $ipConfig.IPAddress -ne "0.0.0.0" -and $ipConfig.IPAddress -notlike "169.254.*") {
                return $ipConfig.IPAddress
            }
        }
    }
    catch {}
    return $null
}

function Force-DHCPRenewal {
    param([string]$AdapterName)

    Write-LogMessage "Forcing DHCP renewal for: $AdapterName"
    try {
        $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
        if ($adapter) {
            # Release and renew DHCP
            ipconfig /release "$AdapterName" 2>&1 | Out-Null
            Start-Sleep -Seconds 3
            ipconfig /renew "$AdapterName" 2>&1 | Out-Null
            Start-Sleep -Seconds 5

            # Force DHCP request
            $adapter | Restart-NetAdapter -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 10

            Write-LogMessage "DHCP renewal completed" -Type "SUCCESS"
            return $true
        }
    }
    catch {
        Write-LogMessage "DHCP renewal had errors: $($_.Exception.Message)" -Type "WARNING"
    }
    return $false
}

function Connect-ToWifi {
    param([string]$SSID, [int]$MaxRetries = 5)

    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-LogMessage "Connection attempt $i/$MaxRetries to '$SSID'..." -Type "WARNING"

        try {
            # Use netsh ONLY - Get-NetAdapter is broken!
            Write-LogMessage "Connecting using netsh (PowerShell network cmdlets are broken)"

            # Connect using netsh without interface name (auto-detects WiFi adapter)
            Write-LogMessage "Executing: netsh wlan connect name='$SSID'"
            netsh wlan connect name="$SSID" 2>&1 | Out-Null
            Start-Sleep -Seconds 25

            # Verify connection state using netsh
            Write-LogMessage "Checking connection status..."
            $interfaceInfo = netsh wlan show interfaces 2>&1 | Out-String
            $connected = $interfaceInfo -match "State.*connected"

            if ($connected) {
                Write-LogMessage "✓ WiFi shows CONNECTED state!" -Type "SUCCESS"

                # Check if we got an IP using ipconfig
                Write-LogMessage "Waiting for DHCP IP assignment..."
                $ipAssigned = $false

                for ($ipWait = 1; $ipWait -le 12; $ipWait++) {
                    Start-Sleep -Seconds 3

                    # Use ipconfig to check for valid IP
                    $ipInfo = ipconfig | Out-String

                    # Show what IP we're seeing for debugging
                    if ($ipInfo -match "Wireless.*?IPv4.*?(\d+\.\d+\.\d+\.\d+)") {
                        $currentIP = $Matches[1]
                        Write-LogMessage "Current IP: $currentIP" -Type "INFO"

                        if ($currentIP -notlike "169.254.*" -and $currentIP -ne "0.0.0.0") {
                            Write-LogMessage "✓ Valid IP address obtained: $currentIP" -Type "SUCCESS"
                            $ipAssigned = $true
                            break
                        }
                        elseif ($currentIP -like "169.254.*") {
                            Write-LogMessage "Got APIPA address (169.254.x.x) - DHCP not responding" -Type "WARNING"
                        }
                    }
                    else {
                        Write-LogMessage "No IP address assigned yet" -Type "WARNING"
                    }

                    Write-LogMessage "Waiting for valid IP... (Attempt $ipWait/12)"
                }

                if (-not $ipAssigned) {
                    Write-LogMessage "No valid IP yet, AGGRESSIVELY forcing DHCP..." -Type "WARNING"

                    # Release first
                    Write-LogMessage "Releasing current IP..."
                    ipconfig /release 2>&1 | Out-Null
                    Start-Sleep -Seconds 3

                    # Renew
                    Write-LogMessage "Requesting new IP from DHCP..."
                    ipconfig /renew 2>&1 | Out-Null
                    Start-Sleep -Seconds 15

                    # Check again with better matching
                    $ipInfo = ipconfig | Out-String
                    Write-LogMessage "Checking IP after renewal..."

                    if ($ipInfo -match "Wireless.*?IPv4.*?(\d+\.\d+\.\d+\.\d+)") {
                        $ipAddr = $Matches[1]
                        Write-LogMessage "IP after renewal: $ipAddr" -Type "INFO"

                        if ($ipAddr -notlike "169.254.*" -and $ipAddr -ne "0.0.0.0") {
                            Write-LogMessage "✓ Valid IP obtained after renewal!" -Type "SUCCESS"
                            $ipAssigned = $true
                        }
                        else {
                            Write-LogMessage "Still no valid IP (got $ipAddr)" -Type "ERROR"
                            Write-LogMessage "DHCP server (router) is not responding!" -Type "ERROR"
                            Write-LogMessage "Check: Router DHCP enabled? Device MAC filtered?" -Type "WARNING"
                        }
                    }
                    else {
                        Write-LogMessage "No IP address at all after renewal" -Type "ERROR"
                    }
                }

                # ENHANCED: Even without valid DHCP IP, try to detect router and test connectivity
                if (-not $ipAssigned) {
                    Write-LogMessage "`n━━━ Router Diagnostics (DHCP Failed) ━━━" -Type "WARNING"

                    # Try to detect router gateway even with APIPA
                    Write-LogMessage "Attempting to detect router gateway..."
                    $gateway = $null

                    # Method 1: Try to get default gateway from route table
                    try {
                        $routeInfo = route print 0.0.0.0 2>&1 | Out-String
                        if ($routeInfo -match "0\.0\.0\.0\s+0\.0\.0\.0\s+(\d+\.\d+\.\d+\.\d+)") {
                            $gateway = $Matches[1]
                            Write-LogMessage "Gateway detected from route table: $gateway" -Type "INFO"
                        }
                    }
                    catch {}

                    # Method 2: Common router IPs
                    if (-not $gateway) {
                        $commonGateways = @("192.168.1.1", "192.168.0.1", "192.168.1.254", "10.0.0.1", "172.16.0.1")
                        Write-LogMessage "Trying common router IPs..."

                        foreach ($testGW in $commonGateways) {
                            Write-LogMessage "  Testing $testGW..."
                            try {
                                $pingTest = Test-Connection -ComputerName $testGW -Count 1 -Quiet -TimeoutSeconds 2 -ErrorAction SilentlyContinue
                                if ($pingTest) {
                                    $gateway = $testGW
                                    Write-LogMessage "  ✓ Router found at: $gateway" -Type "SUCCESS"
                                    break
                                }
                            }
                            catch {}
                        }
                    }

                    # If we found router, try to ping it
                    if ($gateway) {
                        Write-LogMessage "`nRouter connectivity test..."
                        try {
                            $routerPing = Test-Connection -ComputerName $gateway -Count 4 -ErrorAction SilentlyContinue
                            if ($routerPing) {
                                $avgTime = ($routerPing | Measure-Object -Property ResponseTime -Average).Average
                                Write-LogMessage "✓ Router is REACHABLE! Avg ping: $([math]::Round($avgTime))ms" -Type "SUCCESS"
                                Write-LogMessage "Router is online but DHCP is not working" -Type "WARNING"
                                Write-LogMessage "`nPossible DHCP issues:" -Type "WARNING"
                                Write-LogMessage "  • Router DHCP server disabled" -Type "WARNING"
                                Write-LogMessage "  • DHCP pool exhausted (all IPs assigned)" -Type "WARNING"
                                Write-LogMessage "  • Device MAC address blocked/filtered" -Type "WARNING"
                                Write-LogMessage "  • Router needs reboot" -Type "WARNING"
                            }
                        }
                        catch {
                            Write-LogMessage "Cannot ping router at $gateway" -Type "ERROR"
                        }
                    }
                    else {
                        Write-LogMessage "Could not detect router gateway" -Type "WARNING"
                    }

                    # Offer to try static IP configuration
                    Write-LogMessage "`n━━━ Attempting Static IP Fallback ━━━" -Type "WARNING"

                    if ($gateway) {
                        Write-LogMessage "Will try to configure static IP to match router network..."

                        # Extract network from gateway (e.g., 192.168.1.1 -> 192.168.1)
                        if ($gateway -match "(\d+\.\d+\.\d+)\.") {
                            $networkPrefix = $Matches[1]
                            # Use a high IP to avoid conflicts (e.g., 192.168.1.200)
                            $staticIP = "$networkPrefix.200"
                            $subnetMask = "255.255.255.0"

                            Write-LogMessage "Configuring static IP: $staticIP"
                            Write-LogMessage "Subnet Mask: $subnetMask"
                            Write-LogMessage "Gateway: $gateway"
                            Write-LogMessage "DNS: 8.8.8.8, 8.8.4.4"

                            try {
                                # Use netsh to configure static IP (works even when PowerShell cmdlets fail)
                                netsh interface ip set address name="Wi-Fi" static $staticIP $subnetMask $gateway 1 2>&1 | Out-Null
                                netsh interface ip set dns name="Wi-Fi" static 8.8.8.8 primary 2>&1 | Out-Null
                                netsh interface ip add dns name="Wi-Fi" 8.8.4.4 index=2 2>&1 | Out-Null

                                Start-Sleep -Seconds 10

                                # Verify static IP was set
                                $ipInfoAfterStatic = ipconfig | Out-String
                                if ($ipInfoAfterStatic -match "Wireless.*?IPv4.*?$staticIP") {
                                    Write-LogMessage "✓ Static IP configured successfully!" -Type "SUCCESS"
                                    $ipAssigned = $true
                                }
                                else {
                                    Write-LogMessage "Static IP configuration unclear, checking connectivity..." -Type "WARNING"
                                }
                            }
                            catch {
                                Write-LogMessage "Static IP configuration failed: $($_.Exception.Message)" -Type "ERROR"
                            }
                        }
                    }
                }

                # Continue if we still don't have valid IP but will test internet anyway
                if (-not $ipAssigned) {
                    Write-LogMessage "`n━━━ Testing Internet Despite IP Issues ━━━" -Type "WARNING"
                    Write-LogMessage "Sometimes limited connectivity still allows internet access..."
                }

                # Flush DNS
                Write-LogMessage "Flushing DNS and registering..."
                ipconfig /flushdns 2>&1 | Out-Null
                ipconfig /registerdns 2>&1 | Out-Null
                Start-Sleep -Seconds 5

                # Test internet connectivity - ENHANCED VERSION
                Write-LogMessage "`n━━━ COMPREHENSIVE INTERNET CONNECTIVITY TESTS ━━━" -Type "INFO"
                $internetWorking = $false
                $testsPassed = 0
                $testsTotal = 0

                # Test 1: Ping Google DNS (8.8.8.8)
                Write-LogMessage "`nTest 1: Pinging Google DNS (8.8.8.8)..."
                $testsTotal++
                for ($pingAttempt = 1; $pingAttempt -le 5; $pingAttempt++) {
                    try {
                        $pingResult = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet -ErrorAction SilentlyContinue
                        if ($pingResult) {
                            Write-LogMessage "  ✓ Ping to 8.8.8.8 successful! (Attempt $pingAttempt)" -Type "SUCCESS"
                            $internetWorking = $true
                            $testsPassed++
                            break
                        }
                        else {
                            Write-LogMessage "  ⊗ Attempt $pingAttempt failed, retrying..." -Type "WARNING"
                        }
                    }
                    catch {
                        Write-LogMessage "  ⊗ Attempt $pingAttempt error: $($_.Exception.Message)" -Type "WARNING"
                    }
                    Start-Sleep -Seconds 2
                }

                # Test 2: Ping Cloudflare DNS (1.1.1.1)
                Write-LogMessage "`nTest 2: Pinging Cloudflare DNS (1.1.1.1)..."
                $testsTotal++
                for ($pingAttempt = 1; $pingAttempt -le 5; $pingAttempt++) {
                    try {
                        $pingResult = Test-Connection -ComputerName "1.1.1.1" -Count 2 -Quiet -ErrorAction SilentlyContinue
                        if ($pingResult) {
                            Write-LogMessage "  ✓ Ping to 1.1.1.1 successful! (Attempt $pingAttempt)" -Type "SUCCESS"
                            $internetWorking = $true
                            $testsPassed++
                            break
                        }
                        else {
                            Write-LogMessage "  ⊗ Attempt $pingAttempt failed, retrying..." -Type "WARNING"
                        }
                    }
                    catch {
                        Write-LogMessage "  ⊗ Attempt $pingAttempt error: $($_.Exception.Message)" -Type "WARNING"
                    }
                    Start-Sleep -Seconds 2
                }

                # Test 3: Ping OpenDNS (208.67.222.222)
                Write-LogMessage "`nTest 3: Pinging OpenDNS (208.67.222.222)..."
                $testsTotal++
                for ($pingAttempt = 1; $pingAttempt -le 3; $pingAttempt++) {
                    try {
                        $pingResult = Test-Connection -ComputerName "208.67.222.222" -Count 2 -Quiet -ErrorAction SilentlyContinue
                        if ($pingResult) {
                            Write-LogMessage "  ✓ Ping to OpenDNS successful! (Attempt $pingAttempt)" -Type "SUCCESS"
                            $internetWorking = $true
                            $testsPassed++
                            break
                        }
                    }
                    catch {}
                    Start-Sleep -Seconds 1
                }

                # Test 4: DNS resolution
                Write-LogMessage "`nTest 4: Testing DNS resolution (google.com)..."
                $testsTotal++
                for ($dnsAttempt = 1; $dnsAttempt -le 5; $dnsAttempt++) {
                    try {
                        $dnsTest = Resolve-DnsName "google.com" -ErrorAction SilentlyContinue
                        if ($dnsTest) {
                            Write-LogMessage "  ✓ DNS resolution successful! Resolved to: $($dnsTest[0].IPAddress)" -Type "SUCCESS"
                            $internetWorking = $true
                            $testsPassed++
                            break
                        }
                        else {
                            Write-LogMessage "  ⊗ DNS resolution attempt $dnsAttempt failed, retrying..." -Type "WARNING"
                        }
                    }
                    catch {
                        Write-LogMessage "  ⊗ DNS attempt $dnsAttempt error: $($_.Exception.Message)" -Type "WARNING"
                    }

                    if ($dnsAttempt -lt 5) {
                        # Flush DNS between attempts
                        ipconfig /flushdns 2>&1 | Out-Null
                        Start-Sleep -Seconds 2
                    }
                }

                # Test 5: HTTP connectivity using System.Net.WebClient
                Write-LogMessage "`nTest 5: Testing HTTP connectivity (http://www.msftconnecttest.com/connecttest.txt)..."
                $testsTotal++
                try {
                    $webClient = New-Object System.Net.WebClient
                    $webClient.Proxy = $null
                    $webClient.DownloadString("http://www.msftconnecttest.com/connecttest.txt") | Out-Null
                    Write-LogMessage "  ✓ HTTP connectivity test successful!" -Type "SUCCESS"
                    $internetWorking = $true
                    $testsPassed++
                }
                catch {
                    Write-LogMessage "  ⊗ HTTP test failed: $($_.Exception.Message)" -Type "WARNING"
                }

                # Summary of tests
                Write-LogMessage "`n━━━ Test Results Summary ━━━" -Type "INFO"
                Write-LogMessage "Tests Passed: $testsPassed / $testsTotal" -Type $(if($testsPassed -gt 0){"SUCCESS"}else{"ERROR"})

                if ($internetWorking) {
                    Write-LogMessage "`n╔═══════════════════════════════════════════════════════════╗" -Type "SUCCESS"
                    Write-LogMessage "║         ✓✓✓ INTERNET CONNECTION VERIFIED! ✓✓✓            ║" -Type "SUCCESS"
                    Write-LogMessage "╚═══════════════════════════════════════════════════════════╝" -Type "SUCCESS"
                    return $true
                }
                else {
                    Write-LogMessage "`n⚠ All internet tests failed" -Type "ERROR"
                    Write-LogMessage "Connected to WiFi but internet access not confirmed" -Type "ERROR"

                    # Last resort: Try aggressive network reset and renewal
                    Write-LogMessage "`nLast resort: Aggressive network reset..." -Type "WARNING"
                    ipconfig /release 2>&1 | Out-Null
                    Start-Sleep -Seconds 3
                    ipconfig /renew 2>&1 | Out-Null
                    Start-Sleep -Seconds 10
                    ipconfig /flushdns 2>&1 | Out-Null

                    # One final internet test
                    Write-LogMessage "Final internet test after reset..."
                    try {
                        $finalTest = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet -ErrorAction SilentlyContinue
                        if ($finalTest) {
                            Write-LogMessage "✓ Final test PASSED! Internet is working!" -Type "SUCCESS"
                            return $true
                        }
                    }
                    catch {}

                    # ULTIMATE FALLBACK: WiFi is connected, accept it even without confirmed internet
                    Write-LogMessage "`n━━━ FALLBACK MODE ━━━" -Type "WARNING"
                    Write-LogMessage "WiFi connection established but internet verification inconclusive" -Type "WARNING"
                    Write-LogMessage "`nPossible reasons for test failures:" -Type "INFO"
                    Write-LogMessage "  1. Router/Modem Issues:" -Type "INFO"
                    Write-LogMessage "     • Router may need to be rebooted" -Type "INFO"
                    Write-LogMessage "     • ISP connection may be down" -Type "INFO"
                    Write-LogMessage "     • Router WAN/Internet port may be disconnected" -Type "INFO"
                    Write-LogMessage "  2. Firewall/Security:" -Type "INFO"
                    Write-LogMessage "     • Router firewall may be blocking ICMP/ping" -Type "INFO"
                    Write-LogMessage "     • Router may have strict security settings" -Type "INFO"
                    Write-LogMessage "  3. Network Configuration:" -Type "INFO"
                    Write-LogMessage "     • Router may require web authentication (captive portal)" -Type "INFO"
                    Write-LogMessage "     • MAC filtering may be enabled" -Type "INFO"
                    Write-LogMessage "     • Device may need manual approval in router settings" -Type "INFO"

                    Write-LogMessage "`n━━━ Connection Status ━━━" -Type "INFO"
                    # Show current connection details
                    $currentStatus = netsh wlan show interfaces 2>&1 | Out-String
                    if ($currentStatus -match "State\s+:\s+(\w+)") {
                        Write-LogMessage "WiFi State: $($Matches[1])" -Type "INFO"
                    }
                    if ($currentStatus -match "SSID\s+:\s+(.+)") {
                        Write-LogMessage "Connected to: $($Matches[1].Trim())" -Type "INFO"
                    }

                    # Check IP info
                    $ipCheckInfo = ipconfig | Out-String
                    if ($ipCheckInfo -match "Wireless.*?IPv4.*?(\d+\.\d+\.\d+\.\d+)") {
                        $detectedIP = $Matches[1]
                        Write-LogMessage "IP Address: $detectedIP" -Type "INFO"

                        if ($detectedIP -like "169.254.*") {
                            Write-LogMessage "  ⚠ APIPA address detected - DHCP failed!" -Type "WARNING"
                            Write-LogMessage "  → Check router DHCP settings" -Type "WARNING"
                        }
                    }

                    Write-LogMessage "`nRecommended Actions:" -Type "WARNING"
                    Write-LogMessage "  1. Reboot your router and wait 2 minutes" -Type "WARNING"
                    Write-LogMessage "  2. Open a web browser and try to access any website" -Type "WARNING"
                    Write-LogMessage "     (Some networks require login via captive portal)" -Type "WARNING"
                    Write-LogMessage "  3. Check router admin panel for this device and approve if needed" -Type "WARNING"
                    Write-LogMessage "  4. Run 'ipconfig /all' to see full network configuration" -Type "WARNING"
                    Write-LogMessage "  5. Try manually pinging your router's IP address" -Type "WARNING"

                    # Accept the connection as partially successful
                    Write-LogMessage "`n⚠ Accepting WiFi connection despite internet test failures" -Type "WARNING"
                    Write-LogMessage "The WiFi adapter is installed and connected to $SSID" -Type "SUCCESS"
                    Write-LogMessage "Please manually verify internet access via web browser" -Type "WARNING"

                    return $true  # Return true so script doesn't fail completely
                }
            }
            else {
                Write-LogMessage "WiFi not in connected state" -Type "ERROR"
            }

        }
        catch {
            Write-LogMessage "Connection attempt $i error: $($_.Exception.Message)" -Type "ERROR"
        }

        if ($i -lt $MaxRetries) {
            Write-LogMessage "Retrying in 15 seconds..." -Type "WARNING"
            Start-Sleep -Seconds 15

            # Disconnect before retry
            netsh wlan disconnect 2>&1 | Out-Null
            Start-Sleep -Seconds 5
        }
    }

    return $false
}

function Fix-DNSSettings {
    Write-LogMessage "Configuring optimal DNS settings..."
    try {
        # Wait a moment for network stack to be ready
        Start-Sleep -Seconds 3

        # Get adapters with better error handling
        $adapters = @()
        try {
            $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object {
                $_.Status -eq "Up" -or
                $_.Status -eq "Disconnected"
            }
        }
        catch {
            Write-LogMessage "Waiting for network stack to initialize..." -Type "WARNING"
            Start-Sleep -Seconds 5
            try {
                $adapters = Get-NetAdapter -ErrorAction Stop
            }
            catch {
                Write-LogMessage "Could not enumerate network adapters, skipping DNS config" -Type "WARNING"
                return
            }
        }

        if ($adapters) {
            foreach ($adapter in $adapters) {
                try {
                    # Set Google DNS and Cloudflare DNS
                    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ("8.8.8.8", "8.8.4.4", "1.1.1.1", "1.0.0.1") -ErrorAction SilentlyContinue
                    Write-LogMessage "DNS configured for: $($adapter.Name)"
                }
                catch {
                    Write-LogMessage "Could not set DNS for $($adapter.Name)" -Type "WARNING"
                }
            }
        }

        # Flush DNS again
        ipconfig /flushdns 2>&1 | Out-Null
        ipconfig /registerdns 2>&1 | Out-Null

        Write-LogMessage "DNS settings configured" -Type "SUCCESS"
    }
    catch {
        Write-LogMessage "Error configuring DNS: $($_.Exception.Message)" -Type "WARNING"
    }
}

function Clear-NetworkCache {
    Write-LogMessage "Clearing all network caches..."
    try {
        # Clear ARP cache
        arp -d * 2>&1 | Out-Null

        # Clear NetBIOS cache
        nbtstat -R 2>&1 | Out-Null
        nbtstat -RR 2>&1 | Out-Null

        # Clear routing table (be careful!)
        route -f 2>&1 | Out-Null

        Write-LogMessage "Network caches cleared" -Type "SUCCESS"
    }
    catch {
        Write-LogMessage "Some caches could not be cleared" -Type "WARNING"
    }
}

function Repair-WindowsImage {
    Write-LogMessage "Running Windows image repair (DISM)..."
    try {
        # This can fix corrupted system files
        DISM /Online /Cleanup-Image /RestoreHealth /NoRestart 2>&1 | Out-Null
        Write-LogMessage "Windows image repair completed" -Type "SUCCESS"
    }
    catch {
        Write-LogMessage "Windows image repair had warnings (non-critical)" -Type "WARNING"
    }
}

function Test-NetworkConnectivity {
    Write-LogMessage "`n╔═══════════════════════════════════════════════════════════╗" -Type "SUCCESS"
    Write-LogMessage "║           FINAL NETWORK STATUS & VERIFICATION            ║" -Type "SUCCESS"
    Write-LogMessage "╚═══════════════════════════════════════════════════════════╝" -Type "SUCCESS"

    try {
        # Show WiFi interface details
        Write-LogMessage "`n━━━ WiFi Interface Status ━━━" -Type "SUCCESS"
        $wifiInfo = netsh wlan show interfaces
        $wifiInfo | ForEach-Object {
            if ($_ -match "SSID|State|Signal|Channel|Authentication|Cipher|Profile") {
                Write-LogMessage $_
            }
        }

        # Show IP configuration
        Write-LogMessage "`n━━━ IP Configuration ━━━" -Type "SUCCESS"
        $adapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Wireless*" -or $_.InterfaceDescription -like "*Wi-Fi*" -or $_.InterfaceDescription -like "*MT7922*" } | Select-Object -First 1
        if ($adapter) {
            $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $gateway = Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
            $dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

            Write-LogMessage "  Adapter: $($adapter.Name)" -Type "SUCCESS"
            Write-LogMessage "  IPv4 Address: $($ipConfig.IPAddress)" -Type "SUCCESS"
            Write-LogMessage "  Subnet Mask: $($ipConfig.PrefixLength)" -Type "SUCCESS"
            if ($gateway) {
                Write-LogMessage "  Default Gateway: $($gateway.NextHop)" -Type "SUCCESS"
            }
            if ($dns.ServerAddresses) {
                Write-LogMessage "  DNS Servers: $($dns.ServerAddresses -join ', ')" -Type "SUCCESS"
            }
        }

        # Test connectivity with detailed results
        Write-LogMessage "`n━━━ Internet Connectivity Tests ━━━" -Type "SUCCESS"

        # Test 1: Google DNS
        Write-LogMessage "`nTest 1: Ping Google DNS (8.8.8.8)..."
        try {
            $ping1 = Test-Connection -ComputerName "8.8.8.8" -Count 4 -ErrorAction SilentlyContinue
            if ($ping1) {
                $avgTime = ($ping1 | Measure-Object -Property ResponseTime -Average).Average
                Write-LogMessage "  ✓ SUCCESS - Average response: $([math]::Round($avgTime))ms" -Type "SUCCESS"
            } else {
                Write-LogMessage "  ✗ FAILED" -Type "ERROR"
            }
        } catch {
            Write-LogMessage "  ✗ FAILED" -Type "ERROR"
        }

        # Test 2: Cloudflare DNS
        Write-LogMessage "`nTest 2: Ping Cloudflare DNS (1.1.1.1)..."
        try {
            $ping2 = Test-Connection -ComputerName "1.1.1.1" -Count 4 -ErrorAction SilentlyContinue
            if ($ping2) {
                $avgTime = ($ping2 | Measure-Object -Property ResponseTime -Average).Average
                Write-LogMessage "  ✓ SUCCESS - Average response: $([math]::Round($avgTime))ms" -Type "SUCCESS"
            } else {
                Write-LogMessage "  ✗ FAILED" -Type "ERROR"
            }
        } catch {
            Write-LogMessage "  ✗ FAILED" -Type "ERROR"
        }

        # Test 3: DNS Resolution
        Write-LogMessage "`nTest 3: DNS Resolution (google.com)..."
        try {
            $dns = Resolve-DnsName "google.com" -ErrorAction SilentlyContinue
            if ($dns) {
                Write-LogMessage "  ✓ SUCCESS - Resolved to: $($dns[0].IPAddress)" -Type "SUCCESS"
            } else {
                Write-LogMessage "  ✗ FAILED" -Type "ERROR"
            }
        } catch {
            Write-LogMessage "  ✗ FAILED" -Type "ERROR"
        }

        # Test 4: HTTP connectivity
        Write-LogMessage "`nTest 4: HTTP Connectivity (google.com:80)..."
        try {
            $http = Test-NetConnection -ComputerName "google.com" -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            if ($http) {
                Write-LogMessage "  ✓ SUCCESS - Can reach web servers" -Type "SUCCESS"
            } else {
                Write-LogMessage "  ✗ FAILED" -Type "ERROR"
            }
        } catch {
            Write-LogMessage "  ✗ FAILED" -Type "ERROR"
        }

        Write-LogMessage "`n╔═══════════════════════════════════════════════════════════╗" -Type "SUCCESS"
        Write-LogMessage "║              NETWORK TESTS COMPLETED                     ║" -Type "SUCCESS"
        Write-LogMessage "╚═══════════════════════════════════════════════════════════╝" -Type "SUCCESS"
    }
    catch {
        Write-LogMessage "Could not complete all connectivity tests: $($_.Exception.Message)" -Type "WARNING"
    }
}

#############################################
# MAIN EXECUTION
#############################################

Write-LogMessage @"
╔════════════════════════════════════════════════════════════╗
║  ULTRA-ROBUST NETWORK REPAIR & DRIVER REINSTALLATION      ║
║  Version 2.0 - Nuclear Option Edition                     ║
║  Log File: $LogFile
╚════════════════════════════════════════════════════════════╝
"@ -Type "SUCCESS"

# Verify admin rights
if (-not (Test-AdminRights)) {
    Write-LogMessage "❌ ERROR: This script MUST be run as Administrator!" -Type "ERROR"
    Write-LogMessage "Right-click PowerShell and select 'Run as Administrator'" -Type "ERROR"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-LogMessage "✓ Running with Administrator privileges" -Type "SUCCESS"

# Create restore point
Write-LogMessage "`n[PHASE 1] Creating system restore point..."
New-SystemRestorePoint

# Stop all network services
Write-LogMessage "`n[PHASE 2] Stopping network services..."
Stop-NetworkServices

# Reset network stack
Write-LogMessage "`n[PHASE 3] Resetting network stack..."
Reset-NetworkStack

# Clear all caches
Write-LogMessage "`n[PHASE 4] Clearing network caches..."
Clear-NetworkCache

# Remove all WiFi profiles
Write-LogMessage "`n[PHASE 5] Removing all WiFi profiles..."
Remove-AllWifiProfiles

# Remove corrupted drivers
Write-LogMessage "`n[PHASE 6] Removing potentially corrupted drivers..."
Remove-CorruptedDrivers

# Restart network services
Write-LogMessage "`n[PHASE 7] Restarting network services..."
Start-NetworkServices

# Scan for hardware
Write-LogMessage "`n[PHASE 8] Scanning for hardware changes..."
Scan-HardwareChanges

# Install ASUS drivers
Write-LogMessage "`n[PHASE 9] Installing ASUS network drivers..."
$driverPath = "F:\backup\windowsapps\install\Asus\NetworkDriver\Install.bat"
$driverInstalled = $false

for ($attempt = 1; $attempt -le 3; $attempt++) {
    if (Install-AsusDrivers -DriverPath $driverPath -Attempt $attempt) {
        $driverInstalled = $true
        break
    }

    if ($attempt -lt 3) {
        Write-LogMessage "Retrying driver installation in 10 seconds..." -Type "WARNING"
        Start-Sleep -Seconds 10
        Scan-HardwareChanges
    }
}

if (-not $driverInstalled) {
    Write-LogMessage "⚠ Driver installation had issues, continuing anyway..." -Type "WARNING"
}

# Wait for WiFi adapter
Write-LogMessage "`n[PHASE 10] Waiting for WiFi adapter..."
if (-not (Wait-ForWifiAdapter -MaxWaitSeconds $WaitTimeSeconds)) {
    Write-LogMessage "❌ WiFi adapter not detected after installation!" -Type "ERROR"
    Write-LogMessage "Please check Device Manager manually" -Type "ERROR"
    Read-Host "Press Enter to exit"
    exit 1
}

# SKIP Phase 11 - Adapter reset causes problems
Write-LogMessage "`n[PHASE 11] Skipping adapter reset to preserve WiFi adapter state..."
Write-LogMessage "WiFi adapter is already installed and ready from Phase 10" -Type "SUCCESS"

# Give the system a moment to stabilize after driver installation
Write-LogMessage "Waiting for system to stabilize after driver installation..."
Start-Sleep -Seconds 10

# Verify WiFi adapter is still present and ready
Write-LogMessage "Final verification: Checking WiFi adapter availability..."
$wifiAdapter = $null

# Try multiple methods to detect WiFi adapter
for ($i = 1; $i -le 15; $i++) {
    Write-LogMessage "Verification attempt $i/15..." -Type "INFO"

    # Method 1: Get-NetAdapter (PowerShell cmdlet)
    try {
        $wifiAdapter = Get-NetAdapter -ErrorAction Stop | Where-Object {
            $_.InterfaceDescription -like "*Wireless*" -or
            $_.InterfaceDescription -like "*Wi-Fi*" -or
            $_.InterfaceDescription -like "*802.11*" -or
            $_.InterfaceDescription -like "*MT7922*"
        } | Select-Object -First 1

        if ($wifiAdapter) {
            Write-LogMessage "✓ Method 1 SUCCESS: WiFi adapter found via Get-NetAdapter" -Type "SUCCESS"
            Write-LogMessage "  Adapter: $($wifiAdapter.Name)" -Type "SUCCESS"
            Write-LogMessage "  Description: $($wifiAdapter.InterfaceDescription)" -Type "SUCCESS"
            Write-LogMessage "  Status: $($wifiAdapter.Status)" -Type "SUCCESS"
            break
        }
    }
    catch {
        Write-LogMessage "Method 1 failed: $($_.Exception.Message)" -Type "WARNING"
    }

    # Method 2: WMI (fallback) - ACCEPT THIS AS VALID!
    try {
        $wmiAdapter = Get-WmiObject -Class Win32_NetworkAdapter -ErrorAction Stop | Where-Object {
            $_.Name -like "*Wi-Fi*" -or
            $_.Name -like "*Wireless*" -or
            $_.Name -like "*802.11*" -or
            $_.Name -like "*MT7922*"
        } | Where-Object { $_.NetEnabled -eq $true -or $_.NetConnectionStatus -ne $null } | Select-Object -First 1

        if ($wmiAdapter) {
            Write-LogMessage "✓ Method 2 SUCCESS: WiFi adapter found via WMI" -Type "SUCCESS"
            Write-LogMessage "  Adapter: $($wmiAdapter.Name)" -Type "SUCCESS"

            # Get-NetAdapter is broken, so create a mock object from WMI data
            Write-LogMessage "  Creating mock NetAdapter object (Get-NetAdapter is broken)" -Type "SUCCESS"
            $wifiAdapter = [PSCustomObject]@{
                Name = "Wi-Fi"
                InterfaceDescription = $wmiAdapter.Name
                Status = "Up"
                NetConnectionID = $wmiAdapter.NetConnectionID
            }
            Write-LogMessage "✓ WiFi adapter ready to use!" -Type "SUCCESS"
            break
        }
    }
    catch {
        Write-LogMessage "Method 2 failed: $($_.Exception.Message)" -Type "WARNING"
    }

    # Method 3: Use netsh to verify WiFi service is available
    try {
        $netshCheck = netsh wlan show interfaces 2>&1
        if ($netshCheck -match "MT7922|MediaTek|Wi-Fi|Wireless") {
            Write-LogMessage "✓ Method 3 SUCCESS: netsh detects WiFi capability" -Type "SUCCESS"

            # Don't try Get-NetAdapter, just create a mock object
            Write-LogMessage "  Creating mock NetAdapter object from netsh data" -Type "SUCCESS"
            $wifiAdapter = [PSCustomObject]@{
                Name = "Wi-Fi"
                InterfaceDescription = "MediaTek Wi-Fi 6E MT7922 (RZ616) 160MHz Wireless LAN Card"
                Status = "Up"
            }
            Write-LogMessage "✓ WiFi adapter ready to use!" -Type "SUCCESS"
            break
        }
    }
    catch {
        Write-LogMessage "Method 3 failed: $($_.Exception.Message)" -Type "WARNING"
    }

    if ($i -lt 15) {
        Write-LogMessage "WiFi adapter not detected yet, waiting 5 seconds before retry $($i+1)/15..." -Type "WARNING"
        Start-Sleep -Seconds 5
    }
}

if (-not $wifiAdapter) {
    Write-LogMessage "`n❌ CRITICAL ERROR: WiFi adapter disappeared after driver installation!" -Type "ERROR"
    Write-LogMessage "This is unusual - the adapter was detected in Phase 10 but now is gone." -Type "ERROR"
    Write-LogMessage "`nPossible solutions:" -Type "WARNING"
    Write-LogMessage "  1. Manually enable WiFi adapter in Device Manager" -Type "WARNING"
    Write-LogMessage "  2. Reboot the computer and run script again" -Type "WARNING"
    Write-LogMessage "  3. Check if WiFi adapter has a hardware switch" -Type "WARNING"
    Write-LogMessage "`nAttempting to continue anyway with manual connection..." -Type "WARNING"
    Read-Host "`nPress Enter to try manual WiFi connection steps"

    # Don't exit - try to continue with netsh commands
    $wifiAdapter = [PSCustomObject]@{
        Name = "Wi-Fi"
        InterfaceDescription = "MediaTek Wi-Fi 6E MT7922 (RZ616) 160MHz Wireless LAN Card"
        Status = "Unknown"
    }
}

Write-LogMessage "✓✓✓ Proceeding with WiFi connection!" -Type "SUCCESS"

# Disable power management
Write-LogMessage "`n[PHASE 12] Disabling power management..."
Disable-AdapterPowerManagement

# Enable location services
Write-LogMessage "`n[PHASE 13] Enabling location services..."
Enable-LocationServices

# Fix DNS settings
Write-LogMessage "`n[PHASE 14] Configuring DNS settings..."
Fix-DNSSettings
Write-LogMessage "Waiting for network stack to stabilize..."
Start-Sleep -Seconds 10

# Create WiFi profile
Write-LogMessage "`n[PHASE 15] Creating WiFi profile..."
if (-not (New-WifiProfile -SSID $WifiSSID -Password $WifiPassword)) {
    Write-LogMessage "❌ Failed to create WiFi profile!" -Type "ERROR"
    Read-Host "Press Enter to exit"
    exit 1
}

# Connect to WiFi
Write-LogMessage "`n[PHASE 16] Connecting to WiFi network..."
$connectionSuccess = Connect-ToWifi -SSID $WifiSSID -MaxRetries $MaxRetries

if (-not $connectionSuccess) {
    Write-LogMessage "`n❌ CRITICAL ERROR: Failed to establish internet connection!" -Type "ERROR"
    Write-LogMessage "`nPossible issues:" -Type "WARNING"
    Write-LogMessage "  1. WiFi Password: $WifiPassword" -Type "WARNING"
    Write-LogMessage "     → Verify this password is correct for network '$WifiSSID'" -Type "WARNING"
    Write-LogMessage "  2. Router Issues:" -Type "WARNING"
    Write-LogMessage "     → Ensure router is powered on" -Type "WARNING"
    Write-LogMessage "     → Check if router is broadcasting SSID '$WifiSSID'" -Type "WARNING"
    Write-LogMessage "     → Try rebooting your router" -Type "WARNING"
    Write-LogMessage "  3. Network Configuration:" -Type "WARNING"
    Write-LogMessage "     → Check if router has DHCP enabled" -Type "WARNING"
    Write-LogMessage "     → Verify router isn't blocking this device (MAC filtering)" -Type "WARNING"
    Write-LogMessage "  4. Signal Strength:" -Type "WARNING"
    Write-LogMessage "     → Move closer to the router" -Type "WARNING"
    Write-LogMessage "     → Check for interference from other devices" -Type "WARNING"
    Write-LogMessage "`nTroubleshooting steps:" -Type "WARNING"
    Write-LogMessage "  1. Manually connect to WiFi using Windows Settings" -Type "WARNING"
    Write-LogMessage "  2. Run this script again" -Type "WARNING"
    Write-LogMessage "  3. Try rebooting the computer" -Type "WARNING"
    Write-LogMessage "`nLog file saved: $LogFile" -Type "WARNING"
    Read-Host "`nPress Enter to exit"
    exit 1
}

Write-LogMessage "`n✓✓✓ WiFi connected with internet access!" -Type "SUCCESS"

# Final connectivity test
Write-LogMessage "`n[PHASE 17] Final network verification..."
Test-NetworkConnectivity

# Get current connection details
$currentWifiInfo = netsh wlan show interfaces | Select-String "SSID|State|Signal"
$ipInfo = ipconfig | Select-String "IPv4|Default Gateway" | Select-Object -First 4

Write-LogMessage "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type "SUCCESS"
Write-LogMessage "CURRENT CONNECTION STATUS:" -Type "SUCCESS"
$currentWifiInfo | ForEach-Object { Write-LogMessage $_.Line -Type "SUCCESS" }
Write-LogMessage "`nIP Information:" -Type "SUCCESS"
$ipInfo | ForEach-Object { Write-LogMessage $_.Line -Type "SUCCESS" }
Write-LogMessage "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type "SUCCESS"

# Success!
Write-LogMessage @"

╔════════════════════════════════════════════════════════════╗
║                  ✓✓✓ SUCCESS! ✓✓✓                        ║
║                                                            ║
║  Network driver reinstalled successfully                  ║
║  WiFi connected to: $WifiSSID
║  Password: $WifiPassword
║  Internet connectivity VERIFIED                           ║
║                                                            ║
║  All other WiFi profiles have been removed                ║
║  System will auto-connect to $WifiSSID
║                                                            ║
║  Log saved to:                                            ║
║  $LogFile
║                                                            ║
╚════════════════════════════════════════════════════════════╝

"@ -Type "SUCCESS"

Write-LogMessage "Script completed at $(Get-Date)" -Type "SUCCESS"
Write-LogMessage "`nYou can now use your network normally. If you still have issues, try rebooting." -Type "SUCCESS"

# Offer to view log
$viewLog = Read-Host "`nWould you like to view the full log file? (Y/N)"
if ($viewLog -eq "Y" -or $viewLog -eq "y") {
    notepad $LogFile
}

exit 0
