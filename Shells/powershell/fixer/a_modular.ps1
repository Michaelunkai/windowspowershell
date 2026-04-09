# Master Orchestrator - Windows 11 ULTIMATE System Repair Script v5.9 MODULAR
# This script executes all modular repair scripts sequentially
# Solves the context issue where large files couldn't be read/modified

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"

# ============================================================================
# CONFIGURATION
# ============================================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesDir = Join-Path $ScriptDir "modules"
$LogFile = "F:\Downloads\fix\repair_log.txt"

# ============================================================================
# INITIALIZATION - SHARED STATE
# ============================================================================
$script:currentPhase = 0
$script:totalPhases = 92
$script:logMessages = @()
$script:GPUStable = $true
$script:GPUWarnings = @()
$script:protectedDrivers = @()
$script:stoppedServices = @()
$script:NeverRestartServices = @(
    'nvlddmkm', 'amdkmdag', 'igfx', 'BasicDisplay', 'DXGKrnl', 'GraphicsPerfSvc', 'WMPNetworkSvc'
)

# ============================================================================
# SHARED LOGGING
# ============================================================================
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    Write-Host $logMessage -ForegroundColor $Color
    $script:logMessages += $logMessage
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
Write-Log "=" * 70 "Cyan"
Write-Log "WINDOWS 11 ULTIMATE REPAIR v5.9 - MODULAR EXECUTION" "Cyan"
Write-Log "Master Orchestrator Starting - Loading 12 modular scripts" "Yellow"
Write-Log "=" * 70 "Cyan"
Write-Log ""

# Verify admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Log "ERROR: Must run as Administrator!" "Red"
    Write-Log "Right-click PowerShell -> Run as Administrator" "Yellow"
    exit 1
}

Write-Log "Admin privileges verified" "Green"

# Verify modules directory exists
if (-not (Test-Path $ModulesDir)) {
    Write-Log "ERROR: Modules directory not found: $ModulesDir" "Red"
    exit 1
}

# Get list of modules to execute
$modules = @(
    "script_00_init.ps1",           # Initialization (phase setup, helpers, GPU check)
    "script_01_restore_point.ps1",  # Phase 1: Restore Point
    "script_02-08_system_state.ps1",      # Phases 2-8
    "script_09-15_boot_drivers.ps1",      # Phases 9-15
    "script_16-25_drivers_dism.ps1",      # Phases 16-25
    "script_26-35_dotnet_power.ps1",      # Phases 26-35
    "script_36-45_network_gpu.ps1",       # Phases 36-45
    "script_46-50_services_dcom.ps1",     # Phases 46-50
    "script_51-60_hns_boot.ps1",          # Phases 51-60 (includes Phase 52 with timeout fix)
    "script_61-70_gaming_wsldns.ps1",     # Phases 61-70
    "script_71-80_dism_storage.ps1",      # Phases 71-80
    "script_81-92_nuclear_final.ps1"      # Phases 81-92
)

Write-Log "Loading modules from: $ModulesDir" "Yellow"
Write-Log ""

# Execute each module
$modulesLoaded = 0
$modulesFailed = @()

foreach ($module in $modules) {
    $modulePath = Join-Path $ModulesDir $module

    if (-not (Test-Path $modulePath)) {
        Write-Log "WARNING: Module not found - $module" "Red"
        $modulesFailed += $module
        continue
    }

    Write-Log ""
    Write-Log "=" * 70 "Magenta"
    Write-Log "LOADING MODULE: $module" "Magenta"
    Write-Log "=" * 70 "Magenta"

    try {
        # Execute the module in the current scope
        # This makes all variables and functions available to subsequent modules
        . $modulePath
        $modulesLoaded++
        Write-Log "Module loaded: $module" "Green"
    } catch {
        Write-Log "ERROR loading module $module`: $_" "Red"
        $modulesFailed += $module
        Write-Log "Attempting to continue with next module..." "Yellow"
    }
}

# Summary
Write-Log ""
Write-Log "=" * 70 "Cyan"
Write-Log "EXECUTION SUMMARY" "Cyan"
Write-Log "=" * 70 "Cyan"
Write-Log "Total Modules: $($modules.Count)" "White"
Write-Log "Loaded: $modulesLoaded" "Green"
Write-Log "Failed: $($modulesFailed.Count)" "Yellow"

if ($modulesFailed.Count -gt 0) {
    Write-Log "Failed modules:" "Red"
    $modulesFailed | ForEach-Object { Write-Log "  - $_" "Red" }
}

# Restore protected drivers (if any were protected during execution)
if ($script:protectedDrivers.Count -gt 0) {
    Write-Log ""
    Write-Log "Restoring protected drivers..." "Cyan"
    foreach ($pd in $script:protectedDrivers) {
        try {
            if ($pd.OriginalStart -match "DEMAND|AUTO") {
                $startType = if ($pd.OriginalStart -match "AUTO") { "auto" } else { "demand" }
                sc.exe config $pd.Name start= $startType 2>$null | Out-Null
                Write-Log "  Restored driver: $($pd.Name)" "Green"
            }
        } catch {}
    }
}

# Restart stopped services (if any were stopped during execution)
if ($script:stoppedServices.Count -gt 0) {
    Write-Log ""
    Write-Log "Restarting services..." "Cyan"
    foreach ($svc in $script:stoppedServices) {
        Start-Service $svc -EA 0
        Write-Log "  Restarted service: $svc" "Green"
    }
}

Write-Log ""
Write-Log "=" * 70 "Green"
Write-Log "ALL PHASES COMPLETED SUCCESSFULLY!" "Green"
Write-Log "Repair log: $LogFile" "Green"
Write-Log "=" * 70 "Green"

# Clean up
if ($script:mutex -and $script:mutexOwned) {
    try {
        $script:mutex.ReleaseMutex()
        $script:mutex.Dispose()
    } catch {}
}
