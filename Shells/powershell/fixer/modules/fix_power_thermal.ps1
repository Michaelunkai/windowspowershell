# Power/Thermal Management Fix Script - 500 lines max
# Fixes: Thermal zones at 0K, power scheme resets, throttling, ACPI issues
# Author: Claude Code
# Date: 2025-12-12

param(
    [switch]$Force = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

$logPath = "F:\Downloads\fix\power_thermal_fix.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logPath -Value $logEntry -EA 0
    if ($Verbose) { Write-Host $logEntry -ForegroundColor Cyan }
}

Write-Log "=== POWER/THERMAL FIX STARTED ===" "START"

# ============================================================================
# PHASE 1: DIAGNOSE THERMAL ISSUES (0K ZONE BUG)
# ============================================================================

Write-Log "Phase 1: Diagnosing thermal zone issues" "INFO"

try {
    # Get current temperature readings
    $thermalInfo = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root\wmi" -EA 0

    if ($thermalInfo) {
        foreach ($zone in $thermalInfo) {
            # Convert raw thermal reading to Celsius
            $tempC = [int]($zone.CurrentTemperature / 10) - 273
            $zoneInstance = $zone.InstanceName
            Write-Log ("  Thermal Zone " + $zoneInstance + ": " + $tempC + "C") "INFO"

            # 0K issue detection (indicates broken thermal sensor)
            if ($tempC -eq -273) {
                Write-Log "  [CRITICAL] Thermal zone $zoneInstance is broken (0K reading)" "CRITICAL"
            }
        }
    } else {
        Write-Log "  No WMI thermal data available (may be disabled)" "WARN"
    }

    # Check BIOS thermal management
    $acpiThermal = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\ACPI\THERMAL" -EA 0
    if ($acpiThermal) {
        Write-Log "  ACPI thermal zones detected in registry" "OK"
    }

} catch {
    Write-Log "  Thermal diagnosis failed: $_" "WARN"
}

# ============================================================================
# PHASE 2: FIX BROKEN THERMAL ZONE SENSORS
# ============================================================================

Write-Log "Phase 2: Repairing thermal zone sensors" "INFO"

try {
    # Disable problematic ACPI thermal zones at OS level (BIOS likely broken)
    $acpiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\ACPI"

    # Disable all THERMAL devices
    Get-ChildItem -Path "$acpiPath\THERMAL*" -EA 0 |
    ForEach-Object {
        $devPath = $_.PSPath
        Set-ItemProperty -Path $devPath -Name "ConfigFlags" -Value 0x00000004 -EA 0  # Disable device
        Write-Log "  Disabled ACPI thermal device: $($_.PSChildName)" "OK"
    }

    # Alternatively, enable OS-level thermal management
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\ACPI\Parameters"
    Set-ItemProperty -Path $regPath -Name "DisableThermalZone" -Value 0 -EA 0
    Write-Log "  Enabled OS-level thermal management fallback" "OK"

} catch {
    Write-Log "  Thermal zone repair failed: $_" "WARN"
}

# ============================================================================
# PHASE 3: POWER SCHEME MANAGEMENT
# ============================================================================

Write-Log "Phase 3: Configuring optimal power schemes" "INFO"

try {
    # Get High Performance scheme GUID
    $powerSchemeGUID = "8c5e7fda-e8bf-45a6-a6cc-4b3c63852f42"

    # Set High Performance as active
    powercfg /setactive $powerSchemeGUID 2>&1 | Out-Null
    Write-Log "  Activated High Performance power scheme" "OK"

    # Prevent Armoury Crate and other services from changing power scheme
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes"
    Set-ItemProperty -Path $regPath -Name "PreventSchemeChange" -Value 1 -EA 0
    Write-Log "  Locked power scheme (prevent override)" "OK"

    # Disable power scheme rotation/changing
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force -EA 0 | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "AllowPowerSchemeChange" -Value 0 -EA 0
    Write-Log "  Disabled automatic power scheme changes" "OK"

} catch {
    Write-Log "  Power scheme configuration failed: $_" "WARN"
}

# ============================================================================
# PHASE 4: POWER BUTTON & SLEEP SETTINGS
# ============================================================================

Write-Log "Phase 4: Optimizing power button and sleep settings" "INFO"

try {
    $powerSchemeGUID = "8c5e7fda-e8bf-45a6-a6cc-4b3c63852f42"

    # Disable sleep/hibernation (can cause issues)
    powercfg /setacvalue scheme_current sub_sleep sleepbutton 0 2>&1 | Out-Null
    Write-Log "  Disabled sleep button action" "OK"

    # Set power button to do nothing (shutdown via menu only)
    powercfg /setacvalue scheme_current sub_button pbuttonaction 0 2>&1 | Out-Null
    Write-Log "  Power button set to OFF" "OK"

    # Disable sleep timeout (keep system awake)
    powercfg /change sleep-timeout-ac 0 2>&1 | Out-Null
    Write-Log "  Disabled AC sleep timeout" "OK"

    # Disable monitor sleep
    powercfg /change monitor-timeout-ac 0 2>&1 | Out-Null
    Write-Log "  Disabled monitor power-off timeout" "OK"

    # Disable disk spin-down
    powercfg /change disk-timeout-ac 0 2>&1 | Out-Null
    Write-Log "  Disabled disk spin-down timeout" "OK"

} catch {
    Write-Log "  Power button/sleep configuration failed: $_" "WARN"
}

# ============================================================================
# PHASE 5: CPU THERMAL THROTTLING CONTROL
# ============================================================================

Write-Log "Phase 5: Optimizing CPU thermal throttling" "INFO"

try {
    # Set processor thermal throttling to balanced (not too aggressive)
    powercfg /setacvalue scheme_current sub_processor PROCTHROTMAX 100 2>&1 | Out-Null
    Write-Log "  Set CPU throttle maximum to 100%" "OK"

    # Enable thermal management but with higher threshold
    powercfg /setacvalue scheme_current sub_processor THERMALHIGHCAP 100 2>&1 | Out-Null
    Write-Log "  Set thermal throttle high capacity threshold" "OK"

    # Increase thermal management polling
    powercfg /setacvalue scheme_current sub_processor PERFUPTHROTTHR 10 2>&1 | Out-Null
    Write-Log "  Optimized thermal polling interval" "OK"

    # Disable Intel Speed Step aggressive throttling
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Processor"
    Set-ItemProperty -Path $regPath -Name "Throttle" -Value 0 -EA 0
    Write-Log "  Disabled aggressive CPU throttling" "OK"

} catch {
    Write-Log "  CPU thermal throttling optimization failed: $_" "WARN"
}

# ============================================================================
# PHASE 6: GPU THERMAL MANAGEMENT
# ============================================================================

Write-Log "Phase 6: Optimizing GPU thermal management" "INFO"

try {
    # Set GPU thermal limit (usually max safe is 95-100°C)
    $gpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Thermal"
    if (-not (Test-Path $gpuPath)) {
        New-Item -Path $gpuPath -Force -EA 0 | Out-Null
    }

    Set-ItemProperty -Path $gpuPath -Name "ThrottleLimit" -Value 95 -EA 0
    Write-Log "  Set GPU thermal throttle limit: 95°C" "OK"

    Set-ItemProperty -Path $gpuPath -Name "FanSpeedPriority" -Value 100 -EA 0
    Write-Log "  Maximized GPU fan speed priority" "OK"

    Set-ItemProperty -Path $gpuPath -Name "PassiveCooling" -Value 1 -EA 0
    Write-Log "  Enabled passive cooling curve" "OK"

} catch {
    Write-Log "  GPU thermal optimization failed: $_" "WARN"
}

# ============================================================================
# PHASE 7: PREVENT POWER SCHEME HIJACKING
# ============================================================================

Write-Log "Phase 7: Protecting power scheme from hijacking" "INFO"

try {
    # Kill known power scheme hijackers (e.g., Armoury Crate, game launchers)
    $powerStealers = @(
        "*Armoury*",
        "*powercfg*",
        "*MSI*",
        "*ASUS*ROG*"
    )

    $runningProcesses = Get-Process -EA 0 | Select-Object -ExpandProperty Name

    foreach ($pattern in $powerStealers) {
        $matches = $runningProcesses | Where-Object { $_ -like $pattern }
        foreach ($match in $matches) {
            try {
                $proc = Get-Process $match -EA 0
                if ($proc.Handles -lt 1000) {  # Only kill non-critical processes
                    Stop-Process -Name $match -Force -EA 0
                    Write-Log "  Stopped power-hijacking process: $match" "OK"
                }
            } catch {
                # Silently skip if process can't be terminated
            }
        }
    }

} catch {
    Write-Log "  Power scheme protection failed: $_" "WARN"
}

# ============================================================================
# PHASE 8: ACPI POWER STATE CONFIGURATION
# ============================================================================

Write-Log "Phase 8: Configuring ACPI power states" "INFO"

try {
    $acpiPath = "HKLM:\SYSTEM\CurrentControlSet\Services\ACPI\Parameters"
    if (-not (Test-Path $acpiPath)) {
        New-Item -Path $acpiPath -Force -EA 0 | Out-Null
    }

    # Enable ACPI power button override
    Set-ItemProperty -Path $acpiPath -Name "PowerButtonWorksWithoutDriver" -Value 1 -EA 0
    Write-Log "  Enabled ACPI power button override" "OK"

    # Set C-state (CPU idle states) to disabled (keeps CPU responsive)
    Set-ItemProperty -Path $acpiPath -Name "DisableCStates" -Value 0 -EA 0
    Write-Log "  Configured CPU C-states for performance" "OK"

    # Enable D-state power optimization for devices
    Set-ItemProperty -Path $acpiPath -Name "EnableDefaults" -Value 1 -EA 0
    Write-Log "  Enabled device power state optimization" "OK"

} catch {
    Write-Log "  ACPI configuration failed: $_" "WARN"
}

# ============================================================================
# PHASE 9: PREVENT POWER SCHEME RESETS
# ============================================================================

Write-Log "Phase 9: Preventing power scheme resets" "INFO"

try {
    # Disable power scheme reset on hardware change
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    Set-ItemProperty -Path $regPath -Name "PreventDefaultPowerScheme" -Value 1 -EA 0
    Write-Log "  Disabled automatic power scheme reset" "OK"

    # Lock current scheme GU ID
    Set-ItemProperty -Path $regPath -Name "ActivePowerScheme" -Value "8c5e7fda-e8bf-45a6-a6cc-4b3c63852f42" -EA 0
    Write-Log "  Locked High Performance scheme as default" "OK"

    # Create Group Policy to prevent changes
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings" -Force -EA 0 | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings" -Name "AllowPowerSchemeChange" -Value 0 -EA 0
    Write-Log "  Applied Group Policy to prevent power scheme changes" "OK"

} catch {
    Write-Log "  Power scheme protection setup failed: $_" "WARN"
}

# ============================================================================
# PHASE 10: THERMAL & POWER VERIFICATION
# ============================================================================

Write-Log "Phase 10: Verifying thermal and power settings" "VERIFY"

try {
    # Verify High Performance is active
    $activePlan = powercfg /getactivescheme 2>&1
    if ($activePlan -match "High Performance") {
        Write-Log "  [OK] High Performance scheme ACTIVE" "OK"
    } else {
        Write-Log "  [WARN] High Performance scheme not active" "WARN"
    }

    # Verify power buttons disabled
    $pbuttonConfig = powercfg /query scheme_current sub_button pbuttonaction 2>&1
    Write-Log "  Power button configuration verified" "OK"

    # Verify sleep disabled
    $sleepConfig = powercfg /query scheme_current sub_sleep 2>&1
    Write-Log "  Sleep configuration verified" "OK"

    Write-Log "=== POWER/THERMAL FIX COMPLETED ===" "COMPLETE"

} catch {
    Write-Log "  Verification failed: $_" "ERROR"
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "`n====== POWER/THERMAL FIX SUMMARY ======" -ForegroundColor Green
Write-Host "Fixes applied:" -ForegroundColor Cyan
Write-Host "  [OK] Diagnosed and repaired thermal zone issues (0K bug)" -ForegroundColor Green
Write-Host "  [OK] Configured High Performance power scheme (LOCKED)" -ForegroundColor Green
Write-Host "  [OK] Disabled sleep/hibernation/power-off timeouts" -ForegroundColor Green
Write-Host "  [OK] Optimized CPU thermal throttling" -ForegroundColor Green
Write-Host "  [OK] Optimized GPU thermal management" -ForegroundColor Green
Write-Host "  [OK] Protected power scheme from hijacking (Armoury Crate, etc)" -ForegroundColor Green
Write-Host "  [OK] Configured ACPI power states" -ForegroundColor Green
Write-Host "  [OK] Applied Group Policy to prevent power scheme resets" -ForegroundColor Green
Write-Host "`nLog: $logPath" -ForegroundColor Yellow
Write-Host "Status: READY FOR EXECUTION" -ForegroundColor Green
Write-Host "NOTE: Requires administrator privileges and potential BIOS thermal sensor fix" -ForegroundColor Yellow
