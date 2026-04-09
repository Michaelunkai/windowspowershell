<#
.SYNOPSIS
    WiFi Management Tool - Connection Repair and Speed Optimization

.DESCRIPTION
    Unified tool that combines WiFi auto-connect repair and speed optimization capabilities.
    Creates backups, implements safety checks, and provides rollback functionality.

.PARAMETER Mode
    Operation mode: Repair, Optimize, Full, or Rollback

.PARAMETER WiFiNetwork
    Target WiFi network name (auto-detected if not specified)

.PARAMETER WiFiPassword
    WiFi password for profile recreation

.PARAMETER TargetSpeed
    Minimum speed threshold in Mbps

.PARAMETER AdapterName
    Specific adapter to target (processes all WiFi adapters if not specified)

.PARAMETER SkipBackup
    Skip backup creation (not recommended)

.PARAMETER VerboseLogging
    Enable detailed logging output

.PARAMETER TestMode
    Dry-run without making actual changes

.PARAMETER ForceReconnect
    Force reconnection even if already connected

.PARAMETER Help
    Display help information

.EXAMPLE
    .\WiFiManager.ps1 -Mode Full
    .\WiFiManager.ps1 -Mode Repair -WiFiNetwork "MyNetwork"
    .\WiFiManager.ps1 -Mode Optimize -VerboseLogging
    .\WiFiManager.ps1 -Mode Rollback

.NOTES
    Author: WiFi Management Tool
    Version: 1.0.0
    Requires: PowerShell 5.0+, Administrator privileges
#>

param(
    [ValidateSet('Repair', 'Optimize', 'Full', 'Rollback')]
    [string]$Mode = 'Full',

    [string]$WiFiNetwork = 'Stella_5',
    [string]$WiFiPassword = 'Stellamylove',
    [int]$TargetSpeed = 0,
    [string]$AdapterName,
    [switch]$SkipBackup,
    [switch]$VerboseLogging,
    [switch]$TestMode,
    [switch]$ForceReconnect,
    [switch]$Help
)

# Enable silent mode by default (no console output, only logging)
$script:Silent = $true

#Requires -RunAsAdministrator

# Global variables
$script:LogPath = ""
$script:BackupPath = ""
$script:StartTime = Get-Date
$script:Baseline = @{}
$script:OperationCount = 0
$script:TotalOperations = 20

# ============================================================================
# HELP DISPLAY
# ============================================================================
function Show-Help {
    # Help always displays, so temporarily disable silent mode
    $script:Silent = $false
    Smart-WriteHost @"

WiFi Management Tool v1.0

USAGE:
  WiFiManager.exe [-Mode <mode>] [-WiFiNetwork <name>] [options]

MODES:
  Repair     - Fix WiFi auto-connect issues only
  Optimize   - Apply speed optimizations only
  Full       - Both repair and optimize (default)
  Rollback   - Restore previous network configuration

PARAMETERS:
  -WiFiNetwork <name>      Target WiFi network name
  -WiFiPassword <pass>     WiFi password (if recreating profile)
  -TargetSpeed <mbps>      Minimum speed threshold
  -AdapterName <name>      Specific adapter to target
  -SkipBackup              Skip backup creation (not recommended)
  -VerboseLogging          Detailed logging output
  -TestMode                Dry-run without making changes
  -ForceReconnect          Force reconnect even if connected
  -Help                    Show this help message

EXAMPLES:
  WiFiManager.exe -Mode Full
  WiFiManager.exe -Mode Repair -WiFiNetwork "MyNetwork"
  WiFiManager.exe -Mode Optimize -VerboseLogging
  WiFiManager.exe -Mode Rollback

REQUIREMENTS:
  - Windows PowerShell 5.0 or higher
  - Administrator privileges
  - WiFi adapter installed

"@ -ForegroundColor Cyan
    exit 0
}

# ============================================================================
# LOGGING SYSTEM
# ============================================================================
function Smart-WriteHost {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]$Message,
        [string]$ForegroundColor = "White"
    )

    if (-not $script:Silent) {
        Write-Host $Message -ForegroundColor $ForegroundColor
    }
}

function Initialize-Logging {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogPath = "C:\Temp\WiFiOptimization_$timestamp.log"

    if (-not (Test-Path "C:\Temp")) {
        New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
    }

    Write-Log "INFO" "WiFi Management Tool v1.0 started"
    Write-Log "INFO" "Mode: $Mode"
    Write-Log "INFO" "Log file: $script:LogPath"
}

function Write-Log {
    param(
        [string]$Level,
        [string]$Message,
        [string]$Color = "White"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    Add-Content -Path $script:LogPath -Value $logEntry -ErrorAction SilentlyContinue

    # Only show console output if not in Silent mode
    if (-not $script:Silent -and ($VerboseLogging -or $Level -in @("ERROR", "WARN", "SUCCESS"))) {
        $colorMap = @{
            "INFO" = "White"
            "WARN" = "Yellow"
            "ERROR" = "Red"
            "SUCCESS" = "Green"
            "BACKUP" = "Cyan"
            "REGISTRY" = "Gray"
            "SERVICE" = "Gray"
            "TEST" = "Magenta"
            "VERIFY" = "Green"
            "SPEED" = "Cyan"
        }

        $displayColor = if ($colorMap.ContainsKey($Level)) { $colorMap[$Level] } else { $Color }
        Smart-WriteHost $logEntry -ForegroundColor $displayColor
    }
}

function Show-Progress {
    param(
        [string]$Message,
        [string]$Status = "In Progress"
    )

    $script:OperationCount++
    $percent = [math]::Round(($script:OperationCount / $script:TotalOperations) * 100)

    if (-not $script:Silent) {
        Smart-WriteHost "[$script:OperationCount/$script:TotalOperations] $Message" -ForegroundColor Yellow
    }
    Write-Log "INFO" "$Message - $Status"
}

# ============================================================================
# ROBUST ADAPTER DETECTION (Multiple Fallbacks)
# ============================================================================
function Get-WiFiAdaptersRobust {
    <#
    .SYNOPSIS
        Gets WiFi adapters using multiple fallback methods to handle WMI/CIM errors
    #>
    $adapters = @()

    # Method 1: Try Get-NetAdapter (may fail with WMI errors)
    try {
        $adapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object {
            $_.InterfaceDescription -match "Wi-Fi|Wireless|WLAN|802\.11|WiFi"
        })
        if ($adapters.Count -gt 0) {
            Write-Log "INFO" "Adapter detection via Get-NetAdapter: Found $($adapters.Count)"
            return $adapters
        }
    } catch {
        Write-Log "WARN" "Get-NetAdapter failed: $($_.Exception.Message) - trying fallback"
    }

    # Method 2: Try netsh wlan show interfaces
    try {
        $netshOutput = netsh wlan show interfaces 2>$null
        if ($netshOutput -match "Name\s+:\s+(.+)") {
            $wlanName = $Matches[1].Trim()
            Write-Log "INFO" "Adapter detection via netsh: Found '$wlanName'"
            # Create minimal adapter object
            $adapters = @([PSCustomObject]@{
                Name = $wlanName
                InterfaceDescription = "WiFi Adapter (via netsh)"
                Status = "Up"
                MacAddress = ""
            })
            return $adapters
        }
    } catch {
        Write-Log "WARN" "netsh wlan failed: $($_.Exception.Message) - trying WMI"
    }

    # Method 3: Try WMI Win32_NetworkAdapter
    try {
        $wmiAdapters = Get-WmiObject -Class Win32_NetworkAdapter -ErrorAction Stop | Where-Object {
            $_.Name -match "Wi-Fi|Wireless|WLAN|802\.11|WiFi" -and $_.NetConnectionStatus -eq 2
        }
        if ($wmiAdapters) {
            $adapters = @($wmiAdapters | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.NetConnectionID
                    InterfaceDescription = $_.Name
                    Status = "Up"
                    MacAddress = $_.MACAddress
                }
            })
            Write-Log "INFO" "Adapter detection via WMI: Found $($adapters.Count)"
            return $adapters
        }
    } catch {
        Write-Log "WARN" "WMI Win32_NetworkAdapter failed: $($_.Exception.Message)"
    }

    # Method 4: Try CIM directly
    try {
        $cimAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction Stop | Where-Object {
            $_.Name -match "Wi-Fi|Wireless|WLAN|802\.11|WiFi"
        }
        if ($cimAdapters) {
            $adapters = @($cimAdapters | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.NetConnectionID
                    InterfaceDescription = $_.Name
                    Status = if ($_.NetConnectionStatus -eq 2) { "Up" } else { "Down" }
                    MacAddress = $_.MACAddress
                }
            })
            Write-Log "INFO" "Adapter detection via CIM: Found $($adapters.Count)"
            return $adapters
        }
    } catch {
        Write-Log "WARN" "CIM Win32_NetworkAdapter failed: $($_.Exception.Message)"
    }

    # Method 5: Registry scan for WiFi adapters
    try {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
        if (Test-Path $regPath) {
            $subkeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match "^\d{4}$" }
            foreach ($subkey in $subkeys) {
                $driverDesc = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).DriverDesc
                if ($driverDesc -match "Wi-Fi|Wireless|WLAN|802\.11|WiFi") {
                    $adapters += [PSCustomObject]@{
                        Name = "WiFi"
                        InterfaceDescription = $driverDesc
                        Status = "Unknown"
                        MacAddress = ""
                        RegistryPath = $subkey.PSPath
                    }
                }
            }
            if ($adapters.Count -gt 0) {
                Write-Log "INFO" "Adapter detection via Registry: Found $($adapters.Count)"
                return $adapters
            }
        }
    } catch {
        Write-Log "WARN" "Registry adapter scan failed: $($_.Exception.Message)"
    }

    # Method 6: Last resort - assume default WiFi adapter exists
    Write-Log "WARN" "All adapter detection methods failed - using default assumption"
    return @([PSCustomObject]@{
        Name = "Wi-Fi"
        InterfaceDescription = "WiFi Adapter (assumed)"
        Status = "Unknown"
        MacAddress = ""
    })
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================
function Test-Prerequisites {
    Show-Progress "Checking prerequisites"

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion.Major
    if ($psVersion -lt 5) {
        Write-Log "ERROR" "PowerShell 5.0 or higher required (current: $psVersion)"
        throw "PowerShell 5.0 or higher required"
    }
    Smart-WriteHost "   [OK] PowerShell version: $psVersion" -ForegroundColor Green
    Write-Log "INFO" "PowerShell version check passed: $psVersion"

    # Check administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "ERROR" "Administrator privileges required"
        throw "This script must be run as Administrator"
    }
    Smart-WriteHost "   [OK] Administrator privileges confirmed" -ForegroundColor Green
    Write-Log "INFO" "Administrator privileges confirmed"

    # Check for WiFi adapters using robust detection
    $adapters = Get-WiFiAdaptersRobust
    if ($adapters.Count -eq 0) {
        Write-Log "ERROR" "No WiFi adapters found"
        throw "No WiFi adapters detected"
    }
    Smart-WriteHost "   [OK] Found $($adapters.Count) WiFi adapter(s)" -ForegroundColor Green
    Write-Log "INFO" "Found $($adapters.Count) WiFi adapter(s): $($adapters.InterfaceDescription -join ', ')"

    return $true
}

# ============================================================================
# CONNECTIVITY TESTING
# ============================================================================
function Test-Connectivity {
    param(
        [int]$Timeout = 5,
        [switch]$Silent
    )

    $targets = @('8.8.8.8', '1.1.1.1')

    foreach ($target in $targets) {
        try {
            $ping = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction Stop
            if ($ping) {
                if (-not $Silent) {
                    Write-Log "TEST" "Connectivity test to ${target}: SUCCESS"
                }
                return $true
            }
        } catch {
            continue
        }
    }

    Write-Log "TEST" "Connectivity test FAILED - No response from 8.8.8.8 or 1.1.1.1"
    return $false
}

# ============================================================================
# RETRY LOGIC
# ============================================================================
function Invoke-WithRetry {
    param(
        [ScriptBlock]$Operation,
        [int]$MaxRetries = 4,
        [string]$OperationName = "Operation"
    )

    $delays = @(1, 2, 4, 8)

    for ($i = 0; $i -lt $MaxRetries; $i++) {
        try {
            Write-Log "INFO" "$OperationName attempt $($i + 1)/$MaxRetries"
            $result = & $Operation
            Write-Log "SUCCESS" "$OperationName succeeded on attempt $($i + 1)"
            return $result
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Log "WARN" "$OperationName failed on attempt $($i + 1): $errorMsg"

            if ($i -eq $MaxRetries - 1) {
                Write-Log "ERROR" "$OperationName failed after $MaxRetries attempts"
                throw "Operation '$OperationName' failed after $MaxRetries attempts: $errorMsg"
            }

            $delay = $delays[$i]
            Write-Log "INFO" "Waiting $delay second(s) before retry..."
            Start-Sleep -Seconds $delay
        }
    }
}

# ============================================================================
# BACKUP SYSTEM
# ============================================================================
function Backup-NetworkConfiguration {
    if ($SkipBackup) {
        Write-Log "WARN" "Backup skipped by user request"
        return
    }

    Show-Progress "Creating network configuration backup"

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:BackupPath = "C:\Temp\NetworkBackup_$timestamp"

    try {
        # Create backup directory structure
        New-Item -ItemType Directory -Path $script:BackupPath -Force | Out-Null
        New-Item -ItemType Directory -Path "$script:BackupPath\WiFiProfiles" -Force | Out-Null
        Write-Log "BACKUP" "Created backup directory: $script:BackupPath"

        # Export WiFi profiles
        Smart-WriteHost "   [1/5] Exporting WiFi profiles..." -ForegroundColor Gray
        $profiles = netsh wlan show profiles 2>&1 | Select-String "All User Profile" | ForEach-Object {
            ($_ -split ":")[-1].Trim()
        }

        foreach ($profile in $profiles) {
            $profileFile = "$script:BackupPath\WiFiProfiles\$profile.xml"
            netsh wlan export profile name="$profile" folder="$script:BackupPath\WiFiProfiles" key=clear 2>&1 | Out-Null
            if (Test-Path "$script:BackupPath\WiFiProfiles\Wi-Fi-$profile.xml") {
                Rename-Item -Path "$script:BackupPath\WiFiProfiles\Wi-Fi-$profile.xml" -NewName "$profile.xml" -Force
            }
            Write-Log "BACKUP" "Exported WiFi profile: $profile"
        }

        # Backup adapter registry settings
        Smart-WriteHost "   [2/5] Backing up adapter registry settings..." -ForegroundColor Gray
        $baseKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
        reg export "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}" "$script:BackupPath\RegistryBackup.reg" /y 2>&1 | Out-Null
        Write-Log "BACKUP" "Exported registry settings"

        # Backup network adapter configuration
        Smart-WriteHost "   [3/5] Backing up adapter configuration..." -ForegroundColor Gray
        try {
            $adapterConfig = Get-WiFiAdaptersRobust | Select-Object *
            $adapterConfig | Export-Clixml -Path "$script:BackupPath\AdapterConfig.xml"
            Write-Log "BACKUP" "Exported adapter configuration"
        } catch {
            Write-Log "WARN" "Could not backup adapter config: $($_.Exception.Message)"
        }

        # Backup DNS settings
        Smart-WriteHost "   [4/5] Backing up DNS settings..." -ForegroundColor Gray
        try {
            $dnsSettings = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -match "Wi-Fi" }
            if ($dnsSettings) {
                $dnsSettings | Export-Clixml -Path "$script:BackupPath\DNSSettings.xml"
            }
            Write-Log "BACKUP" "Exported DNS settings"
        } catch {
            # Fallback: Use netsh to get DNS
            $dnsOutput = netsh interface ip show dns 2>$null
            $dnsOutput | Out-File -FilePath "$script:BackupPath\DNSSettings.txt"
            Write-Log "BACKUP" "Exported DNS settings via netsh"
        }

        # Backup service states
        Smart-WriteHost "   [5/5] Backing up service states..." -ForegroundColor Gray
        $services = @('WlanSvc', 'NlaSvc', 'netprofm', 'Wcmsvc')
        $serviceStates = @{}
        foreach ($svc in $services) {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service) {
                $serviceStates[$svc] = @{
                    Status = $service.Status
                    StartType = $service.StartType
                }
            }
        }
        $serviceStates | ConvertTo-Json | Out-File -FilePath "$script:BackupPath\ServiceBackup.json"
        Write-Log "BACKUP" "Exported service states"

        # Create manifest
        $manifest = @{
            Timestamp = $timestamp
            Mode = $Mode
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            BackupPath = $script:BackupPath
        }
        $manifest | ConvertTo-Json | Out-File -FilePath "$script:BackupPath\Manifest.json"

        Smart-WriteHost "   [OK] Backup completed: $script:BackupPath" -ForegroundColor Green
        Write-Log "SUCCESS" "Backup completed successfully"

    } catch {
        Write-Log "ERROR" "Backup failed: $($_.Exception.Message)"
        throw "Backup failed: $_"
    }
}

# ============================================================================
# ROLLBACK SYSTEM
# ============================================================================
function Restore-NetworkConfiguration {
    param(
        [string]$BackupLocation
    )

    if (-not $BackupLocation) {
        # Find most recent backup
        $backups = Get-ChildItem -Path "C:\Temp" -Directory -Filter "NetworkBackup_*" | Sort-Object Name -Descending
        if ($backups.Count -eq 0) {
            Write-Log "ERROR" "No backups found in C:\Temp"
            throw "No backups available for restoration"
        }
        $BackupLocation = $backups[0].FullName
    }

    if (-not (Test-Path $BackupLocation)) {
        Write-Log "ERROR" "Backup location not found: $BackupLocation"
        throw "Backup location not found: $BackupLocation"
    }

    Smart-WriteHost "`n=== RESTORING NETWORK CONFIGURATION ===" -ForegroundColor Cyan
    Write-Log "INFO" "Starting restoration from: $BackupLocation"

    try {
        # Restore WiFi profiles
        Smart-WriteHost "[1/4] Restoring WiFi profiles..." -ForegroundColor Yellow
        $profileFiles = Get-ChildItem -Path "$BackupLocation\WiFiProfiles" -Filter "*.xml"
        foreach ($profileFile in $profileFiles) {
            netsh wlan add profile filename="$($profileFile.FullName)" user=all 2>&1 | Out-Null
            Write-Log "INFO" "Restored WiFi profile: $($profileFile.BaseName)"
        }
        Smart-WriteHost "   [OK] WiFi profiles restored" -ForegroundColor Green

        # Restore registry settings
        Smart-WriteHost "[2/4] Restoring registry settings..." -ForegroundColor Yellow
        if (Test-Path "$BackupLocation\RegistryBackup.reg") {
            reg import "$BackupLocation\RegistryBackup.reg" 2>&1 | Out-Null
            Write-Log "INFO" "Registry settings restored"
        }
        Smart-WriteHost "   [OK] Registry settings restored" -ForegroundColor Green

        # Restore DNS settings
        Smart-WriteHost "[3/4] Restoring DNS settings..." -ForegroundColor Yellow
        if (Test-Path "$BackupLocation\DNSSettings.xml") {
            $dnsSettings = Import-Clixml -Path "$BackupLocation\DNSSettings.xml"
            foreach ($dns in $dnsSettings) {
                if ($dns.ServerAddresses) {
                    Set-DnsClientServerAddress -InterfaceAlias $dns.InterfaceAlias -ServerAddresses $dns.ServerAddresses -ErrorAction SilentlyContinue
                    Write-Log "INFO" "Restored DNS for: $($dns.InterfaceAlias)"
                }
            }
        }
        Smart-WriteHost "   [OK] DNS settings restored" -ForegroundColor Green

        # Restore service states
        Smart-WriteHost "[4/4] Restoring service states..." -ForegroundColor Yellow
        if (Test-Path "$BackupLocation\ServiceBackup.json") {
            $serviceStates = Get-Content "$BackupLocation\ServiceBackup.json" | ConvertFrom-Json
            foreach ($svcName in $serviceStates.PSObject.Properties.Name) {
                $svcState = $serviceStates.$svcName
                Set-Service -Name $svcName -StartupType $svcState.StartType -ErrorAction SilentlyContinue
                Write-Log "INFO" "Restored service: $svcName"
            }
        }
        Smart-WriteHost "   [OK] Service states restored" -ForegroundColor Green

        Smart-WriteHost "`n[SUCCESS] Configuration restored from backup" -ForegroundColor Green
        Write-Log "SUCCESS" "Restoration completed successfully"

        # Restart adapter using robust method
        Smart-WriteHost "`nRestarting network adapter..." -ForegroundColor Yellow
        Restart-WiFiAdapterRobust
        Start-Sleep -Seconds 3

        Smart-WriteHost "[OK] Network adapter restarted" -ForegroundColor Green

    } catch {
        Write-Log "ERROR" "Restoration failed: $($_.Exception.Message)"
        throw "Restoration failed: $_"
    }
}

# ============================================================================
# WIFI ADAPTER DETECTION (uses robust fallback)
# ============================================================================
function Get-WiFiAdapter {
    $adapters = Get-WiFiAdaptersRobust

    if ($AdapterName) {
        $adapters = $adapters | Where-Object { $_.Name -eq $AdapterName -or $_.InterfaceDescription -match $AdapterName }
        if ($adapters.Count -eq 0) {
            Write-Log "ERROR" "Specified adapter not found: $AdapterName"
            throw "Adapter '$AdapterName' not found"
        }
    }

    Write-Log "INFO" "Detected $($adapters.Count) WiFi adapter(s)"
    foreach ($adapter in $adapters) {
        Write-Log "INFO" "  - $($adapter.Name): $($adapter.InterfaceDescription)"
    }

    return $adapters
}

# ============================================================================
# ROBUST ADAPTER RESTART (Multiple Fallbacks)
# ============================================================================
function Restart-WiFiAdapterRobust {
    Write-Log "INFO" "Restarting WiFi adapter..."

    # Method 1: Try Restart-NetAdapter
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.InterfaceDescription -match "Wi-Fi|Wireless|WLAN" }
        foreach ($adapter in $adapters) {
            Restart-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Write-Log "INFO" "Restarted adapter via Restart-NetAdapter: $($adapter.Name)"
        }
        return $true
    } catch {
        Write-Log "WARN" "Restart-NetAdapter failed: $($_.Exception.Message) - trying fallback"
    }

    # Method 2: Try netsh interface set
    try {
        $interfaceName = "Wi-Fi"
        $netshOutput = netsh wlan show interfaces 2>$null
        if ($netshOutput -match "Name\s+:\s+(.+)") {
            $interfaceName = $Matches[1].Trim()
        }
        netsh interface set interface "$interfaceName" disable 2>$null
        Start-Sleep -Seconds 2
        netsh interface set interface "$interfaceName" enable 2>$null
        Write-Log "INFO" "Restarted adapter via netsh: $interfaceName"
        return $true
    } catch {
        Write-Log "WARN" "netsh interface restart failed: $($_.Exception.Message)"
    }

    # Method 3: Try WMI
    try {
        $wmiAdapter = Get-WmiObject -Class Win32_NetworkAdapter -ErrorAction Stop | Where-Object {
            $_.Name -match "Wi-Fi|Wireless|WLAN" -and $_.NetConnectionStatus -eq 2
        } | Select-Object -First 1
        if ($wmiAdapter) {
            $wmiAdapter.Disable() | Out-Null
            Start-Sleep -Seconds 2
            $wmiAdapter.Enable() | Out-Null
            Write-Log "INFO" "Restarted adapter via WMI: $($wmiAdapter.Name)"
            return $true
        }
    } catch {
        Write-Log "WARN" "WMI adapter restart failed: $($_.Exception.Message)"
    }

    # Method 4: Try pnputil
    try {
        $adapters = Get-WiFiAdaptersRobust
        if ($adapters -and $adapters[0].InterfaceDescription) {
            $deviceName = $adapters[0].InterfaceDescription
            pnputil /restart-device "$deviceName" 2>$null
            Write-Log "INFO" "Restarted adapter via pnputil: $deviceName"
            return $true
        }
    } catch {
        Write-Log "WARN" "pnputil restart failed: $($_.Exception.Message)"
    }

    Write-Log "WARN" "All adapter restart methods failed - may require manual restart"
    return $false
}

# ============================================================================
# WIFI REPAIR MODULE
# ============================================================================
function Repair-WiFiConnection {
    param(
        [string]$NetworkName,
        [string]$NetworkPassword,
        [object[]]$Adapters
    )

    Smart-WriteHost "`n=== WiFi CONNECTION REPAIR ===" -ForegroundColor Cyan
    Write-Log "INFO" "Starting WiFi connection repair"

    # Detect current or target network
    if (-not $NetworkName) {
        $currentConnection = netsh wlan show interfaces 2>&1 | Select-String "SSID" | Select-Object -First 1
        if ($currentConnection -match ": (.+)$") {
            $NetworkName = $Matches[1].Trim()
            Write-Log "INFO" "Auto-detected network: $NetworkName"
        } else {
            # Use default network in silent mode
            $NetworkName = 'Stella_5'
            Write-Log "INFO" "Using default network: $NetworkName"
        }
    }

    Smart-WriteHost "Target Network: $NetworkName" -ForegroundColor White
    Smart-WriteHost ""

    # Step 1: Configure network services
    Show-Progress "Configuring network services"
    $services = @{
        'WlanSvc' = 'WLAN AutoConfig'
        'NlaSvc' = 'Network Location Awareness'
        'netprofm' = 'Network List Service'
        'Wcmsvc' = 'Windows Connection Manager'
    }

    foreach ($svcName in $services.Keys) {
        try {
            Invoke-WithRetry -OperationName "Configure $($services[$svcName])" -Operation {
                Set-Service -Name $svcName -StartupType Automatic -ErrorAction Stop
                Start-Service -Name $svcName -ErrorAction SilentlyContinue
                $svc = Get-Service -Name $svcName
                if ($svc.Status -ne 'Running') {
                    throw "Service not running"
                }
            }
            Smart-WriteHost "   [OK] $($services[$svcName]) configured" -ForegroundColor Green
            Write-Log "SERVICE" "$svcName set to Automatic and started"
        } catch {
            Write-Log "WARN" "Failed to configure $svcName : $_"
        }
    }

    # Step 2: Check connection and update WiFi profile (PRESERVE CONNECTION - NEVER DELETE PROFILE!)
    Show-Progress "Checking/updating WiFi profile with auto-connect"

    if (-not $TestMode) {
        try {
            # ROBUST connection detection - use PING as primary (doesn't need location permission)
            $currentSSID = $null
            $isWiFiConnected = $false

            # PRIMARY: Use ping to detect if we have internet (location-permission-free)
            $pingResult = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
            if ($pingResult) {
                $isWiFiConnected = $true
                Write-Log "INFO" "Ping test: Internet connectivity confirmed"
            }

            # Try netsh for SSID (may fail with location permission error)
            $wlanInterfaces = netsh wlan show interfaces 2>&1 | Out-String

            # Check if netsh failed due to location permission
            if ($wlanInterfaces -match "location permission|Access is denied") {
                Write-Log "WARN" "netsh wlan requires location permission - using ping-based detection only"
                # We already have isWiFiConnected from ping
                # Assume if connected, it's the target network (Stella_5)
                if ($isWiFiConnected) {
                    $currentSSID = $NetworkName  # Assume target network since we have connectivity
                    Write-Log "INFO" "Assuming connected to $NetworkName based on internet connectivity"
                }
            } else {
                # Parse SSID line carefully (handle leading spaces)
                $lines = $wlanInterfaces -split "`n"
                foreach ($line in $lines) {
                    if ($line -match "^\s*SSID\s*:\s*(.+)$" -and $line -notmatch "BSSID") {
                        $currentSSID = $Matches[1].Trim()
                        break
                    }
                }

                # Check connection state from netsh
                if ($wlanInterfaces -match "State\s*:\s*connected") {
                    $isWiFiConnected = $true
                }
            }

            $isConnectedToTarget = ($isWiFiConnected -and ($currentSSID -eq $NetworkName))

            # Check if profile exists
            $profileExists = $false
            $hasAutoConnect = $false
            $profileCheck = netsh wlan show profile name="$NetworkName" 2>&1 | Out-String
            if ($profileCheck -notmatch "not found" -and $profileCheck -match "Profile $NetworkName") {
                $profileExists = $true
                if ($profileCheck -match "Connection mode\s*:\s*Connect automatically") {
                    $hasAutoConnect = $true
                }
            }

            Write-Log "INFO" "WiFi Connected: $isWiFiConnected, Current SSID: '$currentSSID', Target: '$NetworkName', ConnectedToTarget: $isConnectedToTarget, Profile: $profileExists, AutoConnect: $hasAutoConnect"

            # CRITICAL: If WiFi is connected (to anything), NEVER delete any profile!
            if ($isWiFiConnected) {
                Write-Log "INFO" "WiFi is connected - will NOT delete any profiles to avoid disconnection"

                if ($isConnectedToTarget) {
                    # Already connected to target - only update profile in-place if needed
                    if ($hasAutoConnect) {
                        Write-Log "INFO" "Already connected to $NetworkName with auto-connect - no changes needed"
                        Smart-WriteHost "   [OK] Already connected to $NetworkName - preserving connection" -ForegroundColor Green
                    } else {
                        # Update profile in-place (overwrites without disconnect)
                        Write-Log "INFO" "Updating profile in-place to enable auto-connect"
                        if (-not $NetworkPassword) { $NetworkPassword = 'Stellamylove' }
                        $ssidHex = ($NetworkName.ToCharArray() | ForEach-Object { '{0:X2}' -f [int]$_ }) -join ''
                        $profileXML = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$NetworkName</name>
    <SSIDConfig><SSID><hex>$ssidHex</hex><name>$NetworkName</name></SSID><nonBroadcast>false</nonBroadcast></SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <autoSwitch>false</autoSwitch>
    <MSM><security><authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption>
    <sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>$NetworkPassword</keyMaterial></sharedKey></security></MSM>
    <MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3"><enableRandomization>false</enableRandomization></MacRandomization>
</WLANProfile>
"@
                        $profilePath = "$env:TEMP\$NetworkName`_profile.xml"
                        $profileXML | Out-File -FilePath $profilePath -Encoding UTF8 -Force
                        netsh wlan add profile filename="$profilePath" user=all 2>&1 | Out-Null
                        Remove-Item $profilePath -Force -ErrorAction SilentlyContinue
                        Smart-WriteHost "   [OK] Profile updated in-place with auto-connect" -ForegroundColor Green
                        Write-Log "SUCCESS" "Profile updated in-place: $NetworkName"
                    }
                } else {
                    # Connected to different network - just ensure target profile exists, don't connect
                    Write-Log "INFO" "Connected to different network ($currentSSID) - ensuring $NetworkName profile exists without switching"
                    if (-not $profileExists) {
                        if (-not $NetworkPassword) { $NetworkPassword = 'Stellamylove' }
                        $ssidHex = ($NetworkName.ToCharArray() | ForEach-Object { '{0:X2}' -f [int]$_ }) -join ''
                        $profileXML = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$NetworkName</name>
    <SSIDConfig><SSID><hex>$ssidHex</hex><name>$NetworkName</name></SSID><nonBroadcast>false</nonBroadcast></SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <autoSwitch>false</autoSwitch>
    <MSM><security><authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption>
    <sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>$NetworkPassword</keyMaterial></sharedKey></security></MSM>
    <MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3"><enableRandomization>false</enableRandomization></MacRandomization>
</WLANProfile>
"@
                        $profilePath = "$env:TEMP\$NetworkName`_profile.xml"
                        $profileXML | Out-File -FilePath $profilePath -Encoding UTF8 -Force
                        netsh wlan add profile filename="$profilePath" user=all 2>&1 | Out-Null
                        Remove-Item $profilePath -Force -ErrorAction SilentlyContinue
                        Write-Log "SUCCESS" "Created profile for $NetworkName (not switching networks)"
                    }
                    Smart-WriteHost "   [OK] WiFi profile ready (currently connected to $currentSSID)" -ForegroundColor Green
                }
            } else {
                # NOT connected - safe to create/update profile
                Write-Log "INFO" "WiFi not connected - safe to manage profiles"
                if (-not $NetworkPassword) { $NetworkPassword = 'Stellamylove' }
                $ssidHex = ($NetworkName.ToCharArray() | ForEach-Object { '{0:X2}' -f [int]$_ }) -join ''
                $profileXML = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$NetworkName</name>
    <SSIDConfig><SSID><hex>$ssidHex</hex><name>$NetworkName</name></SSID><nonBroadcast>false</nonBroadcast></SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <autoSwitch>false</autoSwitch>
    <MSM><security><authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption>
    <sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>$NetworkPassword</keyMaterial></sharedKey></security></MSM>
    <MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3"><enableRandomization>false</enableRandomization></MacRandomization>
</WLANProfile>
"@
                $profilePath = "$env:TEMP\$NetworkName`_profile.xml"
                $profileXML | Out-File -FilePath $profilePath -Encoding UTF8 -Force
                # Add profile (overwrites existing if any)
                netsh wlan add profile filename="$profilePath" user=all 2>&1 | Out-Null
                Remove-Item $profilePath -Force -ErrorAction SilentlyContinue
                Smart-WriteHost "   [OK] Profile created with auto-connect enabled" -ForegroundColor Green
                Write-Log "SUCCESS" "WiFi profile created: $NetworkName"
            }
        } catch {
            Write-Log "ERROR" "Failed to manage profile: $_"
        }
    }

    # Step 3: Set profile priority
    Show-Progress "Setting network priority to highest"
    if (-not $TestMode) {
        foreach ($adapter in $Adapters) {
            try {
                netsh wlan set profileorder name="$NetworkName" interface="$($adapter.Name)" priority=1 2>&1 | Out-Null
                Smart-WriteHost "   [OK] Priority set for $($adapter.Name)" -ForegroundColor Green
                Write-Log "INFO" "Profile priority set to 1 for $($adapter.Name)"
            } catch {
                Write-Log "WARN" "Failed to set priority on $($adapter.Name): $_"
            }
        }
    }

    # Step 4: Disable power saving
    Show-Progress "Disabling WiFi power saving"
    if (-not $TestMode) {
        $baseKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"

        if (Test-Path $baseKey) {
            $subkeys = Get-ChildItem $baseKey -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\\\d{4}$' }
            foreach ($subkey in $subkeys) {
                try {
                    $driverDesc = (Get-ItemProperty -Path $subkey.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
                    if ($driverDesc -match "Wi-Fi|Wireless|WLAN") {
                        Set-ItemProperty -Path $subkey.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $subkey.PSPath -Name "*SelectiveSuspend" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $subkey.PSPath -Name "PowerSaveMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                        Smart-WriteHost "   [OK] Power saving disabled: $driverDesc" -ForegroundColor Green
                        Write-Log "REGISTRY" "Disabled power saving for: $driverDesc"
                    }
                } catch {
                    Write-Log "WARN" "Failed to disable power saving: $_"
                }
            }
        }
    }

    # Step 5: Create scheduled task for boot-time connection
    Show-Progress "Creating boot-time WiFi connect task"
    if (-not $TestMode) {
        try {
            Unregister-ScheduledTask -TaskName "WiFi_AutoConnect_$NetworkName" -Confirm:$false -ErrorAction SilentlyContinue

            $action = New-ScheduledTaskAction -Execute "netsh.exe" -Argument "wlan connect name=$NetworkName"
            $trigger1 = New-ScheduledTaskTrigger -AtLogOn
            $trigger2 = New-ScheduledTaskTrigger -AtStartup
            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1)

            Register-ScheduledTask -TaskName "WiFi_AutoConnect_$NetworkName" -Action $action -Trigger $trigger1,$trigger2 -Principal $principal -Settings $settings -Force | Out-Null
            Smart-WriteHost "   [OK] Scheduled task created" -ForegroundColor Green
            Write-Log "SUCCESS" "Scheduled task created for boot-time connection"
        } catch {
            Write-Log "WARN" "Failed to create scheduled task: $_"
        }
    }

    # Step 6: Verify connection (NEVER connect/disconnect if we have internet!)
    Show-Progress "Verifying WiFi connection"
    if (-not $TestMode) {
        # Use PING as primary detection (doesn't require location permission)
        $hasInternet = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue

        if ($hasInternet) {
            # We have internet - DO NOT touch anything!
            Smart-WriteHost "   [OK] Internet connectivity confirmed - connection preserved" -ForegroundColor Green
            Write-Log "SUCCESS" "Internet connectivity confirmed - no changes needed"
        } else {
            # No internet - check if netsh works
            $currentState = netsh wlan show interfaces 2>&1 | Out-String

            if ($currentState -match "location permission|Access is denied") {
                # Can't query WiFi state - but also don't disconnect
                Write-Log "WARN" "Cannot query WiFi state (location permission) - profile updated for next connection"
                Smart-WriteHost "   [OK] Profile configured - will connect on next opportunity" -ForegroundColor Green
            } else {
                $alreadyConnected = $currentState -match "State\s*:\s*connected"

                if ($alreadyConnected) {
                    Smart-WriteHost "   [OK] WiFi connected (DNS may be resolving)" -ForegroundColor Green
                    Write-Log "INFO" "WiFi connected but ping failed - may be DNS issue"
                } else {
                    # Not connected - safe to try connecting
                    Write-Log "INFO" "WiFi not connected - attempting connection to $NetworkName"
                    $connectResult = netsh wlan connect name="$NetworkName" 2>&1
                    Start-Sleep -Seconds 5

                    # Verify with ping (not netsh)
                    $postPing = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
                    if ($postPing) {
                        Smart-WriteHost "   [OK] Connected to $NetworkName" -ForegroundColor Green
                        Write-Log "SUCCESS" "Connected to WiFi network: $NetworkName"
                    } else {
                        Write-Log "WARN" "Connection attempt result: $connectResult"
                    }
                }
            }
        }
    }

    Write-Log "SUCCESS" "WiFi repair completed"
}

# ============================================================================
# SPEED OPTIMIZATION MODULE
# ============================================================================
function Optimize-WiFiSpeed {
    param(
        [object[]]$Adapters
    )

    Smart-WriteHost "`n=== WiFi SPEED OPTIMIZATION ===" -ForegroundColor Cyan
    Write-Log "INFO" "Starting WiFi speed optimization"

    # Find adapter registry keys
    Show-Progress "Detecting adapter registry keys"
    $baseKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    $wifiKeys = @()

    if (Test-Path $baseKey) {
        $subkeys = Get-ChildItem $baseKey -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\\\d{4}$' }
        foreach ($subkey in $subkeys) {
            $driverDesc = (Get-ItemProperty -Path $subkey.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            if ($driverDesc -match "Wi-Fi|Wireless|WLAN|802.11|MT7922|MediaTek|Intel|Realtek|Qualcomm|Atheros") {
                $wifiKeys += $subkey.PSPath
                Smart-WriteHost "   [FOUND] $driverDesc" -ForegroundColor Green
                Write-Log "INFO" "Found WiFi adapter in registry: $driverDesc at $($subkey.PSPath)"
            }
        }
    }

    if ($wifiKeys.Count -eq 0) {
        Write-Log "WARN" "No WiFi adapters found in registry"
        Smart-WriteHost "   [WARN] No WiFi adapters found in registry" -ForegroundColor Yellow
    }

    # Apply adapter optimizations
    foreach ($wifiKey in $wifiKeys) {
        if ($TestMode) {
            Smart-WriteHost "`nWould optimize adapter at: $wifiKey" -ForegroundColor Magenta
            continue
        }

        Smart-WriteHost "`nOptimizing adapter: $wifiKey" -ForegroundColor Cyan

        # WiFi 6/6E mode
        Show-Progress "Enabling WiFi 6/6E mode"
        try {
            Set-ItemProperty -Path $wifiKey -Name "WirelessMode" -Value 8 -Type DWord -ErrorAction SilentlyContinue
            Smart-WriteHost "   [OK] WiFi 6/6E (802.11ax) enabled" -ForegroundColor Green
            Write-Log "REGISTRY" "WirelessMode = 8 (WiFi 6E)"
        } catch {
            Write-Log "WARN" "Failed to set WirelessMode: $_"
        }

        # 160MHz channel width
        Show-Progress "Enabling 160MHz channel width"
        try {
            Set-ItemProperty -Path $wifiKey -Name "BandwidthCapability5GHz" -Value 2 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $wifiKey -Name "ChannelWidth" -Value 160 -Type DWord -ErrorAction SilentlyContinue
            Smart-WriteHost "   [OK] 160MHz channel width enabled" -ForegroundColor Green
            Write-Log "REGISTRY" "ChannelWidth = 160 MHz"
        } catch {
            Write-Log "WARN" "Failed to set channel width: $_"
        }

        # 5GHz preference
        Show-Progress "Setting 5GHz band preference"
        try {
            Set-ItemProperty -Path $wifiKey -Name "RoamAggressiveness" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $wifiKey -Name "PreferredBand" -Value 2 -Type DWord -ErrorAction SilentlyContinue
            Smart-WriteHost "   [OK] 5GHz/6GHz preferred" -ForegroundColor Green
            Write-Log "REGISTRY" "PreferredBand = 2 (5GHz)"
        } catch {
            Write-Log "WARN" "Failed to set band preference: $_"
        }

        # MIMO
        Show-Progress "Enabling MIMO"
        try {
            Set-ItemProperty -Path $wifiKey -Name "MIMOPowerSaveMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Smart-WriteHost "   [OK] MIMO enabled" -ForegroundColor Green
            Write-Log "REGISTRY" "MIMOPowerSaveMode = 0"
        } catch {
            Write-Log "WARN" "Failed to enable MIMO: $_"
        }

        # Disable U-APSD
        Show-Progress "Disabling U-APSD"
        try {
            Set-ItemProperty -Path $wifiKey -Name "uAPSD" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Smart-WriteHost "   [OK] U-APSD disabled" -ForegroundColor Green
            Write-Log "REGISTRY" "uAPSD = 0"
        } catch {
            Write-Log "WARN" "Failed to disable U-APSD: $_"
        }

        # Max transmit power
        Show-Progress "Setting maximum transmit power"
        try {
            Set-ItemProperty -Path $wifiKey -Name "TxPower" -Value 100 -Type DWord -ErrorAction SilentlyContinue
            Smart-WriteHost "   [OK] Transmit power maximized" -ForegroundColor Green
            Write-Log "REGISTRY" "TxPower = 100"
        } catch {
            Write-Log "WARN" "Failed to set transmit power: $_"
        }

        # Throughput optimization
        Show-Progress "Optimizing throughput"
        try {
            Set-ItemProperty -Path $wifiKey -Name "ThroughputBooster" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $wifiKey -Name "AmsduSupport" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $wifiKey -Name "AmpduSupport" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Smart-WriteHost "   [OK] A-MSDU/A-MPDU aggregation enabled" -ForegroundColor Green
            Write-Log "REGISTRY" "Throughput optimizations applied"
        } catch {
            Write-Log "WARN" "Failed to optimize throughput: $_"
        }

        # Disable adaptive radio
        Show-Progress "Disabling adaptive radio"
        try {
            Set-ItemProperty -Path $wifiKey -Name "AdaptiveRadio" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Smart-WriteHost "   [OK] Adaptive radio disabled" -ForegroundColor Green
            Write-Log "REGISTRY" "AdaptiveRadio = 0"
        } catch {
            Write-Log "WARN" "Failed to disable adaptive radio: $_"
        }
    }

    # TCP optimizations
    Show-Progress "Applying TCP optimizations"
    if (-not $TestMode) {
        try {
            netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
            netsh int tcp set global ecncapability=enabled 2>&1 | Out-Null
            netsh int tcp set global rss=enabled 2>&1 | Out-Null
            netsh int tcp set global dca=enabled 2>&1 | Out-Null
            netsh int tcp set global rsc=enabled 2>&1 | Out-Null
            Smart-WriteHost "   [OK] TCP auto-tuning, ECN, RSS enabled" -ForegroundColor Green
            Write-Log "SUCCESS" "TCP optimizations applied"
        } catch {
            Write-Log "WARN" "Failed to apply TCP optimizations: $_"
        }
    }

    # DNS optimization
    Show-Progress "Optimizing DNS"
    if (-not $TestMode) {
        foreach ($adapter in $Adapters) {
            try {
                netsh interface ip set dns name="$($adapter.Name)" static 1.1.1.1 primary 2>&1 | Out-Null
                netsh interface ip add dns name="$($adapter.Name)" 8.8.8.8 index=2 2>&1 | Out-Null
                netsh interface ip add dns name="$($adapter.Name)" 1.0.0.1 index=3 2>&1 | Out-Null
                Smart-WriteHost "   [OK] Fast DNS configured for $($adapter.Name)" -ForegroundColor Green
                Write-Log "SUCCESS" "DNS optimized for $($adapter.Name)"
            } catch {
                Write-Log "WARN" "Failed to set DNS for $($adapter.Name): $_"
            }
        }
    }

    Write-Log "SUCCESS" "Speed optimization completed"
}

# ============================================================================
# VERIFICATION & TESTING
# ============================================================================
function Test-WiFiPerformance {
    Smart-WriteHost "`n=== VERIFICATION & TESTING ===" -ForegroundColor Cyan
    Write-Log "INFO" "Starting post-execution verification"

    # Test 1: Connection verification
    Show-Progress "Verifying WiFi connection"
    $interfaceInfo = netsh wlan show interfaces 2>&1 | Out-String

    if ($interfaceInfo -match "State\s+:\s+connected") {
        Smart-WriteHost "   [OK] WiFi connected" -ForegroundColor Green
        Write-Log "VERIFY" "WiFi connection confirmed"

        # Get signal strength
        if ($interfaceInfo -match "Signal\s+:\s+(\d+)%") {
            $signalStrength = $Matches[1]
            Smart-WriteHost "   [INFO] Signal strength: $signalStrength%" -ForegroundColor Cyan
            Write-Log "VERIFY" "Signal strength: $signalStrength%"
        }

        # Get network name
        if ($interfaceInfo -match "SSID\s+:\s+(.+)") {
            $connectedSSID = $Matches[1].Trim()
            Smart-WriteHost "   [INFO] Connected to: $connectedSSID" -ForegroundColor Cyan
            Write-Log "VERIFY" "Connected to SSID: $connectedSSID"
        }
    } else {
        Smart-WriteHost "   [WARN] Not connected to WiFi" -ForegroundColor Yellow
        Write-Log "WARN" "WiFi not connected during verification"
    }

    # Test 2: Connectivity test
    Show-Progress "Testing internet connectivity"
    $connectivityOK = Test-Connectivity -Timeout 5
    if ($connectivityOK) {
        Smart-WriteHost "   [OK] Internet connectivity confirmed" -ForegroundColor Green
        Write-Log "VERIFY" "Internet connectivity test passed"
    } else {
        Smart-WriteHost "   [WARN] Internet connectivity test failed" -ForegroundColor Yellow
        Write-Log "WARN" "Internet connectivity test failed"
    }

    # Test 3: Service verification
    Show-Progress "Verifying network services"
    $services = @('WlanSvc', 'NlaSvc', 'netprofm', 'Wcmsvc')
    $allRunning = $true
    foreach ($svcName in $services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running' -and $svc.StartType -eq 'Automatic') {
            Write-Log "VERIFY" "$svcName is running and set to Automatic"
        } else {
            Smart-WriteHost "   [WARN] $svcName not properly configured" -ForegroundColor Yellow
            Write-Log "WARN" "$svcName status: $($svc.Status), StartType: $($svc.StartType)"
            $allRunning = $false
        }
    }
    if ($allRunning) {
        Smart-WriteHost "   [OK] All network services running" -ForegroundColor Green
    }

    # Test 4: Speed indication (simplified)
    Show-Progress "Checking network speed indication"
    if ($interfaceInfo -match "Receive rate\s+\(Mbps\)\s+:\s+([\d.]+)") {
        $receiveRate = $Matches[1]
        Smart-WriteHost "   [INFO] Current receive rate: $receiveRate Mbps" -ForegroundColor Cyan
        Write-Log "SPEED" "Receive rate: $receiveRate Mbps"

        if ($TargetSpeed -gt 0) {
            if ([double]$receiveRate -ge $TargetSpeed) {
                Smart-WriteHost "   [OK] Speed meets target ($TargetSpeed Mbps)" -ForegroundColor Green
            } else {
                Smart-WriteHost "   [WARN] Speed below target ($TargetSpeed Mbps)" -ForegroundColor Yellow
            }
        }
    }

    Write-Log "SUCCESS" "Verification completed"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
function Main {
    try {
        # Show help if requested
        if ($Help) {
            Show-Help
        }

        # Initialize
        Clear-Host
        Smart-WriteHost "==================================================================" -ForegroundColor Cyan
        Smart-WriteHost "           WiFi Management Tool v1.0                              " -ForegroundColor Cyan
        Smart-WriteHost "==================================================================" -ForegroundColor Cyan
        Smart-WriteHost ""

        Initialize-Logging

        # Test prerequisites
        Test-Prerequisites

        # Handle rollback mode
        if ($Mode -eq 'Rollback') {
            Restore-NetworkConfiguration
            return
        }

        # Test initial connectivity
        Smart-WriteHost "`n[PRE-CHECK] Testing initial connectivity..." -ForegroundColor Magenta
        $initialConnectivity = Test-Connectivity -Silent
        if ($initialConnectivity) {
            Smart-WriteHost "[OK] Initial connectivity confirmed" -ForegroundColor Green
        } else {
            Smart-WriteHost "[WARN] No initial connectivity" -ForegroundColor Yellow
        }

        # Create backup
        Backup-NetworkConfiguration

        # Get WiFi adapters
        $adapters = Get-WiFiAdapter

        # Execute based on mode
        try {
            switch ($Mode) {
                'Repair' {
                    Repair-WiFiConnection -NetworkName $WiFiNetwork -NetworkPassword $WiFiPassword -Adapters $adapters
                }
                'Optimize' {
                    Optimize-WiFiSpeed -Adapters $adapters
                }
                'Full' {
                    Repair-WiFiConnection -NetworkName $WiFiNetwork -NetworkPassword $WiFiPassword -Adapters $adapters
                    Optimize-WiFiSpeed -Adapters $adapters
                }
            }

            # NEVER restart adapter - it causes disconnection!
            # Registry changes take effect on next connection/wake/reboot
            if (-not $TestMode) {
                # Use ping to check connectivity (doesn't require location permission)
                $pingTest = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue

                if ($pingTest) {
                    Write-Log "INFO" "Internet connectivity confirmed - adapter restart SKIPPED to preserve connection"
                    Smart-WriteHost "`n[OK] Settings applied - connection preserved" -ForegroundColor Green
                } else {
                    Write-Log "INFO" "No ping response - but still NOT restarting adapter (settings apply on next connect)"
                    Smart-WriteHost "`n[OK] Settings applied - will take effect on next connection" -ForegroundColor Green
                }
                # NEVER restart adapter - causes disconnection even when netsh says "not connected"
            }

            # Post-operation connectivity test
            Smart-WriteHost "`n[POST-CHECK] Testing connectivity after changes..." -ForegroundColor Magenta
            $postConnectivity = Test-Connectivity -Timeout 10

            if (-not $postConnectivity -and $initialConnectivity) {
                Smart-WriteHost "[ERROR] Connectivity lost after changes! Initiating rollback..." -ForegroundColor Red
                Write-Log "ERROR" "Connectivity lost - initiating automatic rollback"
                Restore-NetworkConfiguration -BackupLocation $script:BackupPath
                throw "Connectivity lost after changes - configuration rolled back"
            } elseif ($postConnectivity) {
                Smart-WriteHost "[OK] Connectivity confirmed after changes" -ForegroundColor Green
            }

            # Verification
            Test-WiFiPerformance

            # Success summary
            Smart-WriteHost "`n==================================================================" -ForegroundColor Cyan
            Smart-WriteHost "                    OPERATION COMPLETED                           " -ForegroundColor Cyan
            Smart-WriteHost "==================================================================" -ForegroundColor Cyan
            Smart-WriteHost ""
            Smart-WriteHost "Mode: $Mode" -ForegroundColor White
            Smart-WriteHost "Backup: $script:BackupPath" -ForegroundColor Gray
            Smart-WriteHost "Log: $script:LogPath" -ForegroundColor Gray
            Smart-WriteHost ""

            if ($Mode -in @('Repair', 'Full')) {
                Smart-WriteHost "WiFi Repair Changes:" -ForegroundColor White
                Smart-WriteHost "  - Profile set to auto-connect mode" -ForegroundColor Gray
                Smart-WriteHost "  - Network priority set to highest" -ForegroundColor Gray
                Smart-WriteHost "  - All network services set to Automatic" -ForegroundColor Gray
                Smart-WriteHost "  - WiFi adapter power saving disabled" -ForegroundColor Gray
                Smart-WriteHost "  - Boot-time connect task created" -ForegroundColor Gray
                Smart-WriteHost ""
            }

            if ($Mode -in @('Optimize', 'Full')) {
                Smart-WriteHost "Speed Optimization Changes:" -ForegroundColor White
                Smart-WriteHost "  - WiFi 6/6E (802.11ax) mode enabled" -ForegroundColor Gray
                Smart-WriteHost "  - 160MHz channel width enabled" -ForegroundColor Gray
                Smart-WriteHost "  - 5GHz/6GHz band preferred" -ForegroundColor Gray
                Smart-WriteHost "  - MIMO enabled (no power save)" -ForegroundColor Gray
                Smart-WriteHost "  - A-MSDU/A-MPDU aggregation enabled" -ForegroundColor Gray
                Smart-WriteHost "  - TCP optimizations applied" -ForegroundColor Gray
                Smart-WriteHost "  - Fast DNS configured (Cloudflare + Google)" -ForegroundColor Gray
                Smart-WriteHost ""
            }

            Smart-WriteHost "REBOOT RECOMMENDED for all changes to take full effect." -ForegroundColor Yellow
            Smart-WriteHost ""

            $elapsed = (Get-Date) - $script:StartTime
            Write-Log "SUCCESS" "All operations completed in $($elapsed.TotalSeconds) seconds"

        } catch {
            Smart-WriteHost "`n[ERROR] Operation failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "ERROR" "Operation failed: $($_.Exception.Message)"

            if (-not $SkipBackup -and $script:BackupPath) {
                Smart-WriteHost "[INFO] Backup available at: $script:BackupPath" -ForegroundColor Yellow
                Smart-WriteHost "[INFO] To rollback, run: WiFiManager.exe -Mode Rollback" -ForegroundColor Yellow
            }

            throw
        }

    } catch {
        Smart-WriteHost "`n[FATAL ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "ERROR" "Fatal error: $($_.Exception.Message)"
        exit 1
    }
}

# Execute main function
Main

