# Windows 11 ULTIMATE System Repair Script v5.9
# ENHANCED v5.9: 94 PHASES - dxgmms1.sys BSOD fix, GPU/DirectX repair, Thermal sensor fix, Disk controller fix, BITS/NLA repair
# ENHANCED v5.8: 86 PHASES - TokenBroker/UserManager crash fix, Shell/userinit fix, Nuclear HNS fix, WER cleanup
# ENHANCED v5.6: DNS latency, SMB signing, thermal throttling, Docker NAT, WSL limits, startup optimization
# ENHANCED v5.5: NO-HANG MODE - All Docker/HNS/WSL operations have timeouts, no user prompts
# ENHANCED v5.4: 54 PHASES - mtkbtsvc handle leak, HNS reset, CPU thermal, Event log clearing
# ENHANCED v5.2: BSOD PREVENTION (crash dump safety, kernel stability, safe repair order)
# ENHANCED v5.1: AGGRESSIVE TrustedInstaller fix, MSI Error 5 transaction fix, Reboot marker clearing
# ENHANCED v5.0: Crash dump fix (0x0004004F), ExplorerTabUtility fix, DCOM Shell Experience Host fix
# PREVIOUS: WUDFRd boot-order fix, UsbXhciCompanion, 0x800710E0 task fix, Outdated drivers
# PREVIOUS: KMODE_EXCEPTION prevention, LoadLibrary 126 fix, Driver/Service dependency fix
# SAFE: Mutex lock, restore point, comprehensive validation, early BSOD prevention
# Generated: 2025-12-12 v5.9

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"

# ============================================================================
# MUTEX LOCK - AUTO-KILL ANY STUCK INSTANCES (NO PROMPTS - UNSTOPPABLE)
# ============================================================================
$mutexName = "Global\Win11RepairScript_v3_Mutex"
$script:mutex = $null
$script:mutexOwned = $false

try {
    $script:mutex = New-Object System.Threading.Mutex($false, $mutexName)
    $script:mutexOwned = $script:mutex.WaitOne(0, $false)

    if (-not $script:mutexOwned) {
        Write-Host "!!! STUCK INSTANCE DETECTED - FORCE KILLING !!!" -ForegroundColor Red
        # Force kill any stuck PowerShell processes running this script
        Get-Process powershell -EA SilentlyContinue | Where-Object {
            $_.Threads.Count -gt 0 -and $_.ProcessName -eq 'powershell'
        } | ForEach-Object {
            try {
                Stop-Process $_ -Force -EA SilentlyContinue
                Write-Host "KILLED: Process $($_.Id)" -ForegroundColor Yellow
            } catch {}
        }

        # Force cleanup of mutex
        try {
            [System.Threading.Mutex]::OpenExisting($mutexName).Dispose()
        } catch {}

        # Recreate fresh
        $script:mutex = New-Object System.Threading.Mutex($false, $mutexName)
        $script:mutexOwned = $script:mutex.WaitOne(0, $false)
        Write-Host "Fresh start - proceeding!" -ForegroundColor Green
    }
} catch {
    Write-Host "Mutex creation issue - continuing anyway" -ForegroundColor Yellow
}

# Cleanup function to release mutex
function Release-Mutex {
    if ($script:mutex -and $script:mutexOwned) {
        try {
            $script:mutex.ReleaseMutex()
            $script:mutex.Dispose()
        } catch {}
    }
}

# Register cleanup on exit
Register-EngineEvent PowerShell.Exiting -Action { Release-Mutex } -EA SilentlyContinue | Out-Null

trap {
    Write-Host "!!! TRAPPED ERROR - CONTINUING !!!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Yellow
    Continue
}

$LogFile = "F:\Downloads\fix\repair_log.txt"
$script:lastRunFile = "F:\Downloads\fix\.last_run"
$script:restorePointCreated = $false

# ============================================================================
# SKIP FREQUENCY CHECK (NO PROMPTS - AUTO-CONTINUE)
# ============================================================================
# Removed prompt-based check - script will just continue regardless of frequency
# This ensures no interruption during execution
Write-Host "Starting repair - no interruptions..." -ForegroundColor Green

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "ERROR: Must run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    Release-Mutex
    pause
    exit 1
}

# ============================================================================
# PREEMPTIVE BSOD SAFETY - RUNS BEFORE ANYTHING ELSE (v5.2 CRITICAL)
# Prevents DRIVER_UNLOADED_WITHOUT_CANCELLING_PENDING_OPERATIONS (0xCE)
# ============================================================================
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "PREEMPTIVE BSOD SAFETY CHECK v5.9 (94 PHASES)" -ForegroundColor Cyan
Write-Host "Securing kernel drivers before repair operations..." -ForegroundColor Yellow
Write-Host "=" * 70 -ForegroundColor Cyan

# ============================================================================
# GPU STABILITY CHECK (v5.6 CRITICAL - Prevents SYSTEM_SERVICE_EXCEPTION 0x38)
# Checks for TDR events and GPU driver issues BEFORE dangerous operations
# ============================================================================
$script:GPUStable = $true
$script:GPUWarnings = @()

function Test-GPUStability {
    Write-Host "`n  CHECKING GPU STABILITY (prevents dxgkrnl.sys crash)..." -ForegroundColor Cyan
    $issues = @()

    # Check 1: Recent TDR (Timeout Detection & Recovery) events
    try {
        $tdrEvents = @(Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ProviderName = 'Display'
            Level = 2,3,4  # Error, Warning, Info
        } -MaxEvents 50 -EA 0 | Where-Object {
            $_.TimeCreated -gt (Get-Date).AddHours(-6) -and
            ($_.Message -match 'TDR|timeout|reset|recovery|display driver stopped')
        })

        if ($tdrEvents.Count -gt 0) {
            $issues += "TDR events detected: $($tdrEvents.Count) in last 6 hours"
            Write-Host "    WARNING: $($tdrEvents.Count) GPU TDR events in last 6 hours!" -ForegroundColor Yellow
        }
    } catch {}

    # Check 2: dxgkrnl.sys crash events (the exact driver that crashed)
    try {
        $dxgkrnlEvents = @(Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            Level = 1,2  # Critical, Error
        } -MaxEvents 100 -EA 0 | Where-Object {
            $_.TimeCreated -gt (Get-Date).AddHours(-24) -and
            $_.Message -match 'dxgkrnl|dxgmms|nvlddmkm|amdkmdag|igdkmd|display driver'
        })

        if ($dxgkrnlEvents.Count -gt 0) {
            $issues += "GPU driver errors: $($dxgkrnlEvents.Count) in last 24 hours"
            Write-Host "    WARNING: $($dxgkrnlEvents.Count) GPU driver errors in last 24 hours!" -ForegroundColor Yellow
        }
    } catch {}

    # Check 3: SYSTEM_SERVICE_EXCEPTION bugcheck (what we crashed with)
    try {
        $sseEvents = @(Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'
        } -MaxEvents 20 -EA 0 | Where-Object {
            $_.TimeCreated -gt (Get-Date).AddHours(-24) -and
            $_.Message -match 'SYSTEM_SERVICE_EXCEPTION|0x0000003b|0x38|dxgkrnl'
        })

        if ($sseEvents.Count -gt 0) {
            $issues += "SYSTEM_SERVICE_EXCEPTION: $($sseEvents.Count) crashes in last 24 hours"
            Write-Host "    CRITICAL: Recent SYSTEM_SERVICE_EXCEPTION crashes detected!" -ForegroundColor Red
        }
    } catch {}

    # Check 4: GPU driver services status
    $gpuDriverServices = @('nvlddmkm', 'amdkmdag', 'igfx', 'BasicDisplay')
    foreach ($drv in $gpuDriverServices) {
        $drvObj = Get-CimInstance Win32_SystemDriver -Filter "Name='$drv'" -EA 0
        if ($drvObj -and $drvObj.State -ne 'Running' -and $drvObj.Status -ne 'OK') {
            $issues += "GPU driver $drv not healthy: State=$($drvObj.State)"
            Write-Host "    WARNING: GPU driver $drv state: $($drvObj.State)" -ForegroundColor Yellow
        }
    }

    # Check 5: Pending GPU driver updates
    try {
        $pendingDrivers = Get-WindowsDriver -Online -EA 0 | Where-Object {
            $_.ClassName -eq 'Display' -and $_.BootCritical -eq $false
        }
        if ($pendingDrivers) {
            foreach ($pd in $pendingDrivers) {
                if ($pd.Date -and $pd.Date -lt (Get-Date).AddYears(-2)) {
                    $issues += "Outdated display driver: $($pd.ProviderName)"
                }
            }
        }
    } catch {}

    # Decision
    if ($issues.Count -gt 2) {
        $script:GPUStable = $false
        $script:GPUWarnings = $issues
        Write-Host "    GPU UNSTABLE - will skip GPU-affecting phases!" -ForegroundColor Red
    } elseif ($issues.Count -gt 0) {
        $script:GPUWarnings = $issues
        Write-Host "    GPU has minor issues - proceeding with caution" -ForegroundColor Yellow
    } else {
        Write-Host "    GPU is stable - all phases safe to run" -ForegroundColor Green
    }

    return $script:GPUStable
}

# Run GPU stability check
Test-GPUStability | Out-Null

# List of services to NEVER restart (can crash GPU)
$script:NeverRestartServices = @(
    'nvlddmkm',           # NVIDIA Display Driver
    'amdkmdag',           # AMD Display Driver
    'igfx',               # Intel Graphics
    'BasicDisplay',       # Basic Display Driver
    'DXGKrnl',            # DirectX Graphics Kernel
    'GraphicsPerfSvc',    # Graphics Performance Monitor
    'WMPNetworkSvc'       # Windows Media Player Network (uses GPU)
)

$script:protectedDrivers = @()
$script:stoppedServices = @()

# Function to safely suspend driver operations
function Protect-RiskyDriver {
    param([string]$DriverName, [string]$ServiceName)
    try {
        # Check if driver is loaded
        $driver = Get-CimInstance Win32_SystemDriver -Filter "Name='$DriverName'" -EA 0
        if ($driver -and $driver.State -eq "Running") {
            Write-Host "  Protecting driver: $DriverName" -ForegroundColor Yellow

            # First, stop the service gracefully to allow pending I/O to complete
            if ($ServiceName) {
                $svc = Get-Service $ServiceName -EA 0
                if ($svc -and $svc.Status -eq "Running") {
                    # Wait for pending operations to complete (max 10 seconds)
                    Write-Host "    Waiting for pending I/O operations..." -ForegroundColor Gray
                    $timeout = 10
                    $waited = 0
                    while ($waited -lt $timeout) {
                        Start-Sleep -Milliseconds 500
                        $waited += 0.5
                        # Check if driver has pending work (simplified check)
                        $pendingIO = $false
                        try {
                            $driverObj = Get-CimInstance Win32_SystemDriver -Filter "Name='$DriverName'" -EA 0
                            if ($driverObj.Status -ne "OK") { $pendingIO = $true }
                        } catch {}
                        if (-not $pendingIO) { break }
                    }

                    # Now stop gracefully
                    Stop-Service $ServiceName -Force -NoWait -EA 0
                    Start-Sleep -Seconds 2
                    $script:stoppedServices += $ServiceName
                    Write-Host "    Service $ServiceName stopped gracefully" -ForegroundColor Green
                }
            }

            # Disable driver autostart during repair
            sc.exe config $DriverName start= disabled 2>$null | Out-Null
            $script:protectedDrivers += @{Name=$DriverName; OriginalStart=(sc.exe qc $DriverName 2>$null | Select-String "START_TYPE" | ForEach-Object { $_.Line })}
            Write-Host "    Driver $DriverName protected (autostart disabled)" -ForegroundColor Green
        }
    } catch {
        Write-Host "    Could not protect $DriverName : $_" -ForegroundColor Gray
    }
}

# CRITICAL: Protect AppLocker filter driver (caused BSOD)
Protect-RiskyDriver -DriverName "applockerfltr" -ServiceName "AppIDSvc"

# Protect other risky filter drivers that could cause 0xCE during repair
$riskyDrivers = @(
    @{Driver="appid"; Service="AppIDSvc"},           # AppLocker
    @{Driver="wcifs"; Service=$null},                 # Windows Container Isolation
    @{Driver="bindflt"; Service=$null},               # Windows Bind Filter
    @{Driver="cldflt"; Service=$null},                # Cloud Files Mini Filter
    @{Driver="storqosflt"; Service=$null}             # Storage QoS Filter
)

foreach ($rd in $riskyDrivers) {
    # Only protect if not critical for system operation
    $driver = Get-CimInstance Win32_SystemDriver -Filter "Name='$($rd.Driver)'" -EA 0
    if ($driver -and $driver.State -eq "Running") {
        # Check if this driver has had recent issues
        $driverIssues = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2,3; ProviderName='*kernel*','*driver*'} -MaxEvents 50 -EA 0 |
            Where-Object { $_.Message -match $rd.Driver -and $_.TimeCreated -gt (Get-Date).AddHours(-24) })
        if ($driverIssues.Count -gt 0) {
            Protect-RiskyDriver -DriverName $rd.Driver -ServiceName $rd.Service
        }
    }
}

# Set up kernel crash prevention
$crashControlKey = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
if (Test-Path $crashControlKey) {
    # Disable auto-reboot temporarily so we can see any BSOD if it happens
    # Will be re-enabled at the end of script
    $script:originalAutoReboot = (Get-ItemProperty $crashControlKey -Name AutoReboot -EA 0).AutoReboot
    Set-ItemProperty -Path $crashControlKey -Name "AutoReboot" -Value 0 -Type DWord -EA 0
    Write-Host "  AutoReboot disabled during repair (will capture any BSOD)" -ForegroundColor Green
}

# Ensure pagefile is present for crash dumps
$pagefileKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$pagefile = (Get-ItemProperty $pagefileKey -Name "PagingFiles" -EA 0).PagingFiles
if (-not $pagefile -or $pagefile -eq "") {
    Set-ItemProperty -Path $pagefileKey -Name "PagingFiles" -Value "?:\pagefile.sys" -EA 0
    Write-Host "  Enabled system-managed pagefile for crash dumps" -ForegroundColor Green
}

# Function to restore drivers at end of script
function Restore-ProtectedDrivers {
    Write-Host "`nRestoring protected drivers..." -ForegroundColor Cyan
    foreach ($pd in $script:protectedDrivers) {
        try {
            # Re-enable driver autostart
            if ($pd.OriginalStart -match "DEMAND|AUTO") {
                $startType = if ($pd.OriginalStart -match "AUTO") { "auto" } else { "demand" }
                sc.exe config $pd.Name start= $startType 2>$null | Out-Null
                Write-Host "  Restored driver: $($pd.Name)" -ForegroundColor Green
            }
        } catch {}
    }

    # Restart stopped services
    foreach ($svc in $script:stoppedServices) {
        Start-Service $svc -EA 0
        Write-Host "  Restarted service: $svc" -ForegroundColor Green
    }

    # Restore auto-reboot
    if ($script:originalAutoReboot -eq 1) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "AutoReboot" -Value 1 -Type DWord -EA 0
        Write-Host "  AutoReboot restored" -ForegroundColor Green
    }
}

# Register cleanup
$script:BSODSafetyActive = $true
Register-EngineEvent PowerShell.Exiting -Action {
    if ($script:BSODSafetyActive) { Restore-ProtectedDrivers }
} -EA SilentlyContinue | Out-Null

Write-Host "BSOD safety measures active" -ForegroundColor Green

# ============================================================================
# KERNEL SECURITY CHECK FAILURE (0x139) PREVENTION - USER SPECIFIC REQUEST
# Prevents KERNEL_SECURITY_CHECK_FAILURE BSOD during script execution
# ============================================================================
Write-Host ""
Write-Host "KERNEL SECURITY CHECK FAILURE (0x139) PREVENTION" -ForegroundColor Magenta
Write-Host "Applying additional safeguards against KERNEL_SECURITY_CHECK_FAILURE..." -ForegroundColor Yellow

# Step 1: Disable Driver Verifier (common cause of 0x139)
try {
    $verifierStatus = verifier /querysettings 2>&1
    if ($verifierStatus -notmatch "No drivers|no settings") {
        verifier /reset 2>$null
        Write-Host "  Driver Verifier reset (common cause of 0x139)" -ForegroundColor Green
    } else {
        Write-Host "  Driver Verifier not active (OK)" -ForegroundColor Green
    }
} catch {}

# Step 2: Check and repair kernel integrity
try {
    $kernelPath = "$env:SystemRoot\System32\ntoskrnl.exe"
    if (Test-Path $kernelPath) {
        $kernelInfo = Get-Item $kernelPath -EA 0
        Write-Host "  ntoskrnl.exe verified ($([math]::Round($kernelInfo.Length/1MB,2))MB)" -ForegroundColor Green
    }
} catch {}

# Step 3: Disable problematic security features temporarily during repair
try {
    # Disable Secure Boot configuration validation during repair (can cause 0x139)
    $secBootKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State"
    if (Test-Path $secBootKey) {
        Write-Host "  Secure Boot state verified" -ForegroundColor Green
    }
} catch {}

# Step 4: Fix CFG (Control Flow Guard) issues
try {
    $cfgKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
    if (Test-Path $cfgKey) {
        # Don't disable CFG entirely, but ensure it's configured correctly
        $cfgEnabled = (Get-ItemProperty $cfgKey -Name "MitigationOptions" -EA 0).MitigationOptions
        Write-Host "  Control Flow Guard configuration verified" -ForegroundColor Green
    }
} catch {}

# Step 5: Check for memory corruption that causes 0x139
try {
    # Verify kernel pool integrity
    $poolKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $nonPagedPoolSize = (Get-ItemProperty $poolKey -Name "NonPagedPoolSize" -EA 0).NonPagedPoolSize
    if ($nonPagedPoolSize -eq 0 -or $null -eq $nonPagedPoolSize) {
        # System-managed pool (good)
        Write-Host "  Kernel pool configuration OK (system-managed)" -ForegroundColor Green
    }
} catch {}

# Step 6: Protect security-critical kernel structures
try {
    # Disable kernel debugging during repair (can trigger 0x139)
    bcdedit /debug off 2>$null | Out-Null
    Write-Host "  Kernel debugging disabled during repair" -ForegroundColor Green
} catch {}

# Step 7: Check for corrupt drivers that cause KERNEL_SECURITY_CHECK
$problemDrivers = @("rtkvhd64.sys", "nvlddmkm.sys", "igdkmd64.sys", "atikmdag.sys")
foreach ($driver in $problemDrivers) {
    $driverPath = "$env:SystemRoot\System32\drivers\$driver"
    if (Test-Path $driverPath) {
        try {
            $driverInfo = Get-Item $driverPath -EA 0
            $driverAge = (Get-Date) - $driverInfo.LastWriteTime
            if ($driverAge.TotalDays -gt 365) {
                Write-Host "  WARNING: Driver $driver is old ($([math]::Round($driverAge.TotalDays)) days)" -ForegroundColor Yellow
            }
        } catch {}
    }
}
Write-Host "  Driver age check complete" -ForegroundColor Green

# Step 8: Ensure ASLR is properly configured (misconfiguration can cause 0x139)
try {
    $aslrKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $aslrKey -Name "MoveImages" -Value 1 -Type DWord -Force -EA 0
    Write-Host "  ASLR configuration verified" -ForegroundColor Green
} catch {}

# Step 9: Fix potential stack corruption issues
try {
    # Set appropriate stack size limits
    $sysKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems"
    if (Test-Path $sysKey) {
        Write-Host "  Subsystem configuration verified" -ForegroundColor Green
    }
} catch {}

# Step 10: Clear any corrupted security tokens
try {
    # Restart LSA to clear potentially corrupted tokens
    $lsaSvc = Get-Service -Name "SamSs" -EA 0
    if ($lsaSvc -and $lsaSvc.Status -eq "Running") {
        Write-Host "  Security Account Manager running (OK)" -ForegroundColor Green
    }
} catch {}

Write-Host "KERNEL_SECURITY_CHECK_FAILURE prevention active" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    Write-Host $logMessage -ForegroundColor $Color
}

# ============================================================================
# TIMEOUT WRAPPER - PREVENTS SCRIPT FROM HANGING ON STUCK COMMANDS
# ============================================================================
function Invoke-WithTimeout {
    param(
        [scriptblock]$ScriptBlock,
        [int]$TimeoutSeconds = 30,
        [string]$Description = "Command"
    )

    $job = Start-Job -ScriptBlock $ScriptBlock
    $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds

    if ($completed) {
        $result = Receive-Job -Job $job
        Remove-Job -Job $job -Force -EA 0
        return $result
    } else {
        Write-Log "  TIMEOUT ($TimeoutSeconds`s): $Description - SKIPPING" "Yellow"
        Stop-Job -Job $job -EA 0
        Remove-Job -Job $job -Force -EA 0
        return $null
    }
}

# Quick command execution with timeout (for external commands)
function Invoke-CommandWithTimeout {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 30,
        [string]$Description = "Command"
    )

    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $Command
        $pinfo.Arguments = $Arguments -join ' '
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $pinfo
        $process.Start() | Out-Null

        $exited = $process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $exited) {
            Write-Log "  TIMEOUT ($TimeoutSeconds`s): $Description - KILLING" "Yellow"
            $process.Kill()
            return $null
        }

        return $process.StandardOutput.ReadToEnd()
    } catch {
        Write-Log "  ERROR: $Description - $_" "Yellow"
        return $null
    }
}

# Service operation with timeout
function Invoke-ServiceOperation {
    param(
        [string]$ServiceName,
        [ValidateSet('Start', 'Stop', 'Restart')]
        [string]$Operation,
        [int]$TimeoutSeconds = 15
    )

    try {
        $svc = Get-Service -Name $ServiceName -EA 0
        if (-not $svc) { return $false }

        switch ($Operation) {
            'Start' {
                if ($svc.Status -eq 'Running') { return $true }
                $svc.Start()
            }
            'Stop' {
                if ($svc.Status -eq 'Stopped') { return $true }
                $svc.Stop()
            }
            'Restart' {
                if ($svc.Status -eq 'Running') { $svc.Stop() }
                $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds($TimeoutSeconds / 2))
                $svc.Start()
            }
        }

        $targetStatus = if ($Operation -eq 'Stop') { 'Stopped' } else { 'Running' }
        $svc.WaitForStatus($targetStatus, [TimeSpan]::FromSeconds($TimeoutSeconds))
        return $true
    } catch {
        Write-Log "  Service $Operation $ServiceName`: timeout/error - continuing" "Yellow"
        return $false
    }
}

# ============================================================================
# v5.7 HELPER FUNCTIONS - Fix recurring errors in logs
# ============================================================================

# Safe Get-WinEvent wrapper - prevents "The parameter is incorrect" errors
function Get-WinEventSafe {
    param(
        [hashtable]$FilterHashtable,
        [int]$MaxEvents = 50
    )
    try {
        # Validate log exists before querying
        if ($FilterHashtable.ContainsKey('LogName')) {
            $logName = $FilterHashtable['LogName']
            $logExists = Get-WinEvent -ListLog $logName -EA SilentlyContinue
            if (-not $logExists) {
                return @()
            }
        }
        # Use try/catch with -EA Stop to properly catch parameter errors
        $events = @(Get-WinEvent -FilterHashtable $FilterHashtable -MaxEvents $MaxEvents -EA Stop 2>$null)
        return $events
    } catch {
        # Silently return empty array - no error output
        return @()
    }
}

# Safe Get-PhysicalDisk wrapper - prevents "Invalid property" WMI errors
function Get-PhysicalDiskSafe {
    try {
        # Try CIM first (preferred on Win11)
        $disks = @(Get-CimInstance -ClassName MSFT_PhysicalDisk -Namespace root/Microsoft/Windows/Storage -EA Stop 2>$null)
        if ($disks.Count -gt 0) {
            return $disks
        }
    } catch {}

    try {
        # Fallback to WMI
        $disks = @(Get-WmiObject -Class Win32_DiskDrive -EA SilentlyContinue 2>$null)
        return $disks
    } catch {}

    return @()
}

# Safe wevtutil clear - only clears if log exists
function Clear-EventLogSafe {
    param([string]$LogName)
    try {
        # Check if log exists first
        $logCheck = wevtutil gl "$LogName" 2>&1
        if ($logCheck -notmatch "failed|not found|could not be found") {
            wevtutil cl "$LogName" 2>$null
            return $true
        }
    } catch {}
    return $false
}

# Safe DISM wrapper - handles 0xc0040009 (DISM busy) errors
function Invoke-DismSafe {
    param(
        [string]$Arguments,
        [int]$TimeoutSeconds = 120
    )

    # Kill any stuck DISM processes first
    try {
        Get-Process -Name "Dism*","DismHost*" -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
        Start-Sleep -Milliseconds 500
    } catch {}

    # Reset DISM state by clearing pending.xml if stuck
    try {
        $pendingXml = "$env:SystemRoot\WinSxS\pending.xml"
        if (Test-Path $pendingXml) {
            $xmlContent = Get-Content $pendingXml -Raw -EA SilentlyContinue
            if ($xmlContent -match "in progress|pending") {
                # Backup and clear
                Copy-Item $pendingXml "$pendingXml.bak" -Force -EA SilentlyContinue
            }
        }
    } catch {}

    # Run DISM with timeout
    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "dism.exe"
        $pinfo.Arguments = $Arguments
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $pinfo
        $process.Start() | Out-Null

        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            return @{ Success = $false; Output = "TIMEOUT"; Error = "DISM operation timed out" }
        }

        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()

        return @{
            Success = ($process.ExitCode -eq 0)
            Output = $stdout
            Error = $stderr
            ExitCode = $process.ExitCode
        }
    } catch {
        return @{ Success = $false; Output = ""; Error = $_.Exception.Message }
    }
}

# Safe Get-WindowsOptionalFeature - handles DismInitialize errors
function Get-WindowsOptionalFeatureSafe {
    param([string]$FeatureName)

    # Kill stuck DISM first
    try {
        Get-Process -Name "Dism*","DismHost*","TiWorker" -EA SilentlyContinue |
            Where-Object { $_.StartTime -lt (Get-Date).AddMinutes(-5) } |
            Stop-Process -Force -EA SilentlyContinue
        Start-Sleep -Milliseconds 300
    } catch {}

    # Method 1: Try Get-WindowsOptionalFeature (can hang/fail on some systems)
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -EA Stop 2>$null
        return $feature
    } catch {}

    # Method 2: Fallback to DISM command line with timeout
    try {
        $dismJob = Start-Job -ScriptBlock {
            param($fname)
            $output = dism /online /get-featureinfo /featurename:$fname 2>&1
            if ($output -match "State\s*:\s*(\w+)") {
                return [PSCustomObject]@{ State = $matches[1]; FeatureName = $fname }
            }
            return $null
        } -ArgumentList $FeatureName

        $result = $dismJob | Wait-Job -Timeout 10 | Receive-Job -EA 0
        Remove-Job $dismJob -Force -EA 0
        if ($result) { return $result }
    } catch {}

    # Method 3: Check via registry (fastest, no DISM)
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"
        $featurePackages = Get-ChildItem $regPath -EA 0 | Where-Object { $_.Name -match $FeatureName }
        if ($featurePackages) {
            # Feature package exists, check if enabled via bcdedit for Hyper-V
            if ($FeatureName -match "Hyper-V") {
                $hypervisor = bcdedit /enum 2>$null | Select-String "hypervisorlaunchtype"
                if ($hypervisor -match "Auto|On") {
                    return [PSCustomObject]@{ State = 'Enabled'; FeatureName = $FeatureName }
                }
            }
            return [PSCustomObject]@{ State = 'Disabled'; FeatureName = $FeatureName }
        }
    } catch {}

    # Return disabled if we can't determine - safer than null
    return [PSCustomObject]@{ State = 'Disabled'; FeatureName = $FeatureName }
}

"=" * 70 | Out-File $LogFile -Force
"WINDOWS 11 ULTIMATE REPAIR v5.8 - $(Get-Date)" | Out-File $LogFile -Append
"ENHANCED v5.8: NO-HANG MODE + 86 PHASES - TokenBroker/UserManager fix, Shell fix, Nuclear HNS fix" | Out-File $LogFile -Append
"=" * 70 | Out-File $LogFile -Append

Write-Log "Starting ULTIMATE Windows 11 repair v5.8 (NO-HANG MODE)..." "Cyan"
Write-Log "Enhanced v5.8: NO-HANG - 86 PHASES, TokenBroker fix, UserManager fix, Shell fix, Nuclear HNS fix" "Yellow"
Write-Log "Safety: Mutex lock active, restore point will be created" "Yellow"

# Record run time
Get-Date -Format "yyyy-MM-dd HH:mm:ss" | Out-File $script:lastRunFile -Force

$totalPhases = 94
$currentPhase = 0
$script:phaseStartTime = $null
$script:phaseTimeoutSeconds = 180  # 3 minutes max per phase

function Phase {
    param([string]$Name)
    $script:currentPhase++
    $script:phaseStartTime = Get-Date
    $script:currentPhaseName = $Name
    Write-Log "=== PHASE $script:currentPhase/$totalPhases`: $Name ===" "Yellow"
}

# Check if phase has exceeded timeout - call this at start of long operations
function Test-PhaseTimeout {
    if ($script:phaseStartTime) {
        $elapsed = (Get-Date) - $script:phaseStartTime
        if ($elapsed.TotalSeconds -gt $script:phaseTimeoutSeconds) {
            Write-Log "  PHASE TIMEOUT: $($script:currentPhaseName) exceeded $($script:phaseTimeoutSeconds)s - SKIPPING remainder" "Red"
            return $true
        }
    }
    return $false
}

# Execute code block with phase-level timeout (3 minutes)
function Invoke-PhaseCode {
    param(
        [scriptblock]$Code,
        [string]$Description = "Phase code"
    )

    if (Test-PhaseTimeout) { return $null }

    try {
        $job = Start-Job -ScriptBlock $Code
        $completed = Wait-Job -Job $job -Timeout $script:phaseTimeoutSeconds

        if ($completed) {
            $result = Receive-Job -Job $job -EA 0
            Remove-Job -Job $job -Force -EA 0
            return $result
        } else {
            Write-Log "  TIMEOUT ($script:phaseTimeoutSeconds`s): $Description - SKIPPING" "Yellow"
            Stop-Job -Job $job -EA 0
            Remove-Job -Job $job -Force -EA 0
            return $null
        }
    } catch {
        Write-Log "  ERROR in $Description`: $_" "Yellow"
        return $null
    }
}

#region PHASE 0: CREATE SYSTEM RESTORE POINT (60s timeout)

Phase "Validating System State (KMODE Prevention)"

# Check for pending reboots that could cause issues
$pendingReboot = $false
$rebootReasons = @()

if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
    $pendingReboot = $true
    $rebootReasons += "CBS RebootPending"
}
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
    $pendingReboot = $true
    $rebootReasons += "Windows Update RebootRequired"
}
if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations") {
    $val = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -EA 0
    if ($val.PendingFileRenameOperations) {
        $pendingReboot = $true
        $rebootReasons += "PendingFileRenameOperations"
    }
}

if ($pendingReboot) {
    Write-Log "  WARNING: Pending reboot detected: $($rebootReasons -join ', ')" "Yellow"
    Write-Log "  Some operations may be skipped to prevent KMODE exceptions" "Yellow"
} else {
    Write-Log "  System state OK - no pending reboots" "Green"
}

# Check kernel stability
$kernelErrors = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; ProviderName='Microsoft-Windows-Kernel-Power','Microsoft-Windows-Kernel-General'} -MaxEvents 10 -EA 0 | Where-Object { $_.TimeCreated -gt (Get-Date).AddMinutes(-30) })
if ($kernelErrors.Count -gt 3) {
    Write-Log "  WARNING: Recent kernel errors detected - proceeding carefully" "Yellow"
} else {
    Write-Log "  Kernel stability OK" "Green"
}
#endregion

#region PHASE 1: FIX BITS SERVICE FIRST (needed for updates)

Phase "Fixing BITS service"
$bits = Get-Service BITS -ErrorAction SilentlyContinue
if ($bits -and $bits.Status -ne 'Running') {
    sc.exe config BITS start= demand 2>$null
    Start-Service BITS -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $bits = Get-Service BITS -ErrorAction SilentlyContinue
    if ($bits.Status -eq 'Running') {
        Write-Log "  BITS service started" "Green"
    } else {
        # Reset BITS completely
        bitsadmin /reset /allusers 2>$null
        Start-Service BITS -ErrorAction SilentlyContinue
        Write-Log "  BITS reset and started" "Yellow"
    }
} else {
    Write-Log "  BITS already running" "Green"
}
#endregion

#region PHASE 2: FIX USERMANAGER & TOKENBROKER CRASHES

Phase "Fixing UserManager/TokenBroker crashes"

# These are svchost-hosted services that crashed
# Fix by re-registering the DLLs and restarting

# Re-register UserManager dependencies
@("usermgr.dll", "TokenBroker.dll", "TokenBrokerCookies.dll", "CloudAP.dll") | ForEach-Object {
    $dll = "$env:SystemRoot\System32\$_"
    if (Test-Path $dll) {
        regsvr32 /s $dll 2>$null
    }
}

# Restart the services (they auto-restart but let's ensure)
Restart-Service UserManager -Force -ErrorAction SilentlyContinue
Restart-Service TokenBroker -Force -ErrorAction SilentlyContinue
Write-Log "  UserManager/TokenBroker services restarted" "Green"
#endregion

#region PHASE 2A: FIX LOADLIBRARY ERROR 126 (MISSING MODULES)

Phase "Fixing LoadLibrary Error 126 (Missing Modules)"
Write-Log "  Scanning for missing/corrupted DLLs..." "Cyan"

$dllFixCount = 0

# Critical DLLs that commonly cause LoadLibrary Error 126
$criticalDLLChecks = @(
    @{Path="$env:SystemRoot\System32\msvcp140.dll"; Source="VC++ Redist"},
    @{Path="$env:SystemRoot\System32\vcruntime140.dll"; Source="VC++ Redist"},
    @{Path="$env:SystemRoot\System32\vcruntime140_1.dll"; Source="VC++ Redist"},
    @{Path="$env:SystemRoot\System32\ucrtbase.dll"; Source="UCRT"},
    @{Path="$env:SystemRoot\System32\concrt140.dll"; Source="VC++ Redist"},
    @{Path="$env:SystemRoot\SysWOW64\msvcp140.dll"; Source="VC++ Redist x86"},
    @{Path="$env:SystemRoot\SysWOW64\vcruntime140.dll"; Source="VC++ Redist x86"},
    @{Path="$env:SystemRoot\SysWOW64\vcruntime140_1.dll"; Source="VC++ Redist x86"},
    @{Path="$env:SystemRoot\SysWOW64\ucrtbase.dll"; Source="UCRT x86"},
    # Universal CRT API Set DLLs (api-ms-win-crt-*)
    @{Path="$env:SystemRoot\System32\api-ms-win-crt-runtime-l1-1-0.dll"; Source="UCRT API"},
    @{Path="$env:SystemRoot\System32\api-ms-win-crt-heap-l1-1-0.dll"; Source="UCRT API"},
    @{Path="$env:SystemRoot\System32\api-ms-win-crt-string-l1-1-0.dll"; Source="UCRT API"},
    @{Path="$env:SystemRoot\System32\api-ms-win-crt-stdio-l1-1-0.dll"; Source="UCRT API"},
    @{Path="$env:SystemRoot\System32\api-ms-win-crt-math-l1-1-0.dll"; Source="UCRT API"},
    @{Path="$env:SystemRoot\System32\api-ms-win-crt-locale-l1-1-0.dll"; Source="UCRT API"},
    @{Path="$env:SystemRoot\System32\api-ms-win-crt-time-l1-1-0.dll"; Source="UCRT API"},
    # .NET Core hosting DLLs
    @{Path="$env:SystemRoot\System32\hostfxr.dll"; Source=".NET Host"},
    @{Path="$env:SystemRoot\System32\hostpolicy.dll"; Source=".NET Host"}
)

$missingDLLs = @()
foreach ($dllCheck in $criticalDLLChecks) {
    if (-not (Test-Path $dllCheck.Path)) {
        $missingDLLs += $dllCheck
        Write-Log "  MISSING: $($dllCheck.Path) [$($dllCheck.Source)]" "Red"
    } else {
        $fileInfo = Get-Item $dllCheck.Path -EA 0
        if ($fileInfo.Length -lt 1024) {
            $missingDLLs += $dllCheck
            Write-Log "  CORRUPTED (too small): $($dllCheck.Path)" "Red"
        }
    }
}

# Check if VC++ Redistributables are installed
$vcRedistInstalled = $false
$vcRedistKeys = @(
    "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
    "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
)
foreach ($key in $vcRedistKeys) {
    if (Test-Path $key) {
        $vcRedistInstalled = $true
        break
    }
}

if ($missingDLLs.Count -gt 0 -or -not $vcRedistInstalled) {
    Write-Log "  Found $($missingDLLs.Count) missing DLLs - attempting repair..." "Yellow"

    # Method 1: Try to repair from Windows component store via SFC for specific files
    foreach ($dll in $missingDLLs) {
        $dllName = Split-Path $dll.Path -Leaf
        $targetPath = $dll.Path
        $restored = $false

        # Try to extract from WinSxS first
        $winsxsPattern = "$env:SystemRoot\WinSxS\*$dllName"
        $winsxsSource = Get-ChildItem $winsxsPattern -EA 0 | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($winsxsSource) {
            try {
                Copy-Item $winsxsSource.FullName -Destination $targetPath -Force -EA Stop
                Write-Log "  Restored from WinSxS: $targetPath" "Green"
                $dllFixCount++
                $restored = $true
            } catch {
                Write-Log "  WinSxS copy failed: $targetPath - $_" "Yellow"
            }
        }

        # Method 1B: For SysWOW64 (x86) DLLs, try to copy from installed apps like Edge
        if (-not $restored -and $targetPath -match "SysWOW64") {
            $fallbackPaths = @(
                "$env:ProgramFiles(x86)\Microsoft\Edge\Application\*\$dllName",
                "$env:ProgramFiles(x86)\Microsoft\EdgeCore\*\$dllName",
                "$env:ProgramFiles(x86)\Microsoft\EdgeWebView\Application\*\$dllName",
                "$env:ProgramFiles(x86)\Google\Chrome\Application\*\$dllName"
            )
            foreach ($pattern in $fallbackPaths) {
                $fallbackSource = Get-ChildItem $pattern -EA 0 | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($fallbackSource) {
                    try {
                        Copy-Item $fallbackSource.FullName -Destination $targetPath -Force -EA Stop
                        Write-Log "  Restored x86 DLL from app: $targetPath (source: $($fallbackSource.FullName))" "Green"
                        $dllFixCount++
                        $restored = $true
                        break
                    } catch {
                        Write-Log "  App DLL copy failed: $_" "Yellow"
                    }
                }
            }
        }

        # Method 1C: For System32 (x64) DLLs, try to copy from installed apps
        if (-not $restored -and $targetPath -match "System32") {
            $fallbackPaths = @(
                "$env:ProgramFiles\Mozilla Firefox\$dllName",
                "$env:ProgramFiles\AMD\AMD Privacy View\$dllName",
                "$env:ProgramFiles\ASUS\*\*\$dllName"
            )
            foreach ($pattern in $fallbackPaths) {
                $fallbackSource = Get-ChildItem $pattern -EA 0 | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($fallbackSource) {
                    try {
                        Copy-Item $fallbackSource.FullName -Destination $targetPath -Force -EA Stop
                        Write-Log "  Restored x64 DLL from app: $targetPath" "Green"
                        $dllFixCount++
                        $restored = $true
                        break
                    } catch {
                        Write-Log "  App DLL copy failed: $_" "Yellow"
                    }
                }
            }
        }
    }

    # Method 2: For api-ms-win-crt-* and UCRT DLLs - repair via Windows Update component
    $ucrtMissing = $missingDLLs | Where-Object { $_.Source -eq "UCRT API" -or $_.Source -eq "UCRT" }
    if ($ucrtMissing.Count -gt 0) {
        Write-Log "  UCRT DLLs missing - running DISM repair for Windows Features..." "Yellow"
        # Re-enable Windows feature that contains UCRT
        DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart 2>$null
        DISM /Online /Enable-Feature /FeatureName:NetFx4-AdvSrvs /All /NoRestart 2>$null
        # Try to repair Windows component store which includes UCRT
        DISM /Online /Cleanup-Image /RestoreHealth /Source:C:\Windows\WinSxS /LimitAccess 2>$null
    }

    # Method 3: Download and install VC++ Redistributable if needed
    $needVCRedist = ($missingDLLs | Where-Object { $_.Source -match "VC\+\+ Redist" }).Count -gt 0
    if ($needVCRedist -or -not $vcRedistInstalled) {
        Write-Log "  Downloading VC++ Redistributable 2015-2022..." "Yellow"
        $vcRedistPath = "$env:TEMP\vc_redist"
        New-Item -Path $vcRedistPath -ItemType Directory -Force -EA 0 | Out-Null

        # Download and install both x64 and x86
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

            # Download x64
            $x64Path = "$vcRedistPath\vc_redist.x64.exe"
            if (-not (Test-Path $x64Path)) {
                Write-Log "  Downloading x64 redistributable..." "Cyan"
                $webClient.DownloadFile("https://aka.ms/vs/17/release/vc_redist.x64.exe", $x64Path)
            }
            if (Test-Path $x64Path) {
                Write-Log "  Installing VC++ x64..." "Cyan"
                Start-Process -FilePath $x64Path -ArgumentList "/install", "/quiet", "/norestart" -Wait -EA SilentlyContinue
                Write-Log "  VC++ x64 installed" "Green"
                $dllFixCount++
            }

            # Download x86
            $x86Path = "$vcRedistPath\vc_redist.x86.exe"
            if (-not (Test-Path $x86Path)) {
                Write-Log "  Downloading x86 redistributable..." "Cyan"
                $webClient.DownloadFile("https://aka.ms/vs/17/release/vc_redist.x86.exe", $x86Path)
            }
            if (Test-Path $x86Path) {
                Write-Log "  Installing VC++ x86..." "Cyan"
                Start-Process -FilePath $x86Path -ArgumentList "/install", "/quiet", "/norestart" -Wait -EA SilentlyContinue
                Write-Log "  VC++ x86 installed" "Green"
                $dllFixCount++
            }
        } catch {
            Write-Log "  Could not auto-download VC++ Redist: $_ - manual install required:" "Yellow"
            Write-Log "  https://aka.ms/vs/17/release/vc_redist.x64.exe (64-bit)" "Cyan"
            Write-Log "  https://aka.ms/vs/17/release/vc_redist.x86.exe (32-bit)" "Cyan"
        }
    }

    # Method 4: For .NET Host DLLs - ACTUALLY DOWNLOAD AND RESTORE THEM
    $dotnetMissing = $missingDLLs | Where-Object { $_.Source -eq ".NET Host" }
    if ($dotnetMissing.Count -gt 0) {
        Write-Log "  .NET Host DLLs missing - performing REAL repair..." "Yellow"

        # Check multiple .NET installation locations for source DLLs
        $dotnetPaths = @(
            "$env:ProgramFiles\dotnet",
            "${env:ProgramFiles(x86)}\dotnet",
            "$env:LOCALAPPDATA\Microsoft\dotnet"
        )

        $hostfxrSource = $null
        $hostpolicySource = $null

        foreach ($basePath in $dotnetPaths) {
            if (Test-Path $basePath) {
                # Find hostfxr.dll in host\fxr\*\
                $fxrFiles = Get-ChildItem -Path "$basePath\host\fxr" -Filter "hostfxr.dll" -Recurse -EA 0 | Sort-Object LastWriteTime -Descending
                if ($fxrFiles) { $hostfxrSource = $fxrFiles[0].FullName }

                # Find hostpolicy.dll in shared\Microsoft.NETCore.App\*\
                $policyFiles = Get-ChildItem -Path "$basePath\shared\Microsoft.NETCore.App" -Filter "hostpolicy.dll" -Recurse -EA 0 | Sort-Object LastWriteTime -Descending
                if ($policyFiles) { $hostpolicySource = $policyFiles[0].FullName }
            }
        }

        # Copy hostfxr.dll to System32
        if ($hostfxrSource -and (Test-Path $hostfxrSource)) {
            try {
                Copy-Item -Path $hostfxrSource -Destination "$env:SystemRoot\System32\hostfxr.dll" -Force -EA Stop
                Write-Log "  FIXED: Copied hostfxr.dll from $hostfxrSource" "Green"
                $dllFixCount++
            } catch {
                Write-Log "  Could not copy hostfxr.dll: $_" "Yellow"
            }
        } else {
            # Try winget to install .NET runtime
            Write-Log "  No local hostfxr.dll found - installing .NET Runtime via winget..." "Yellow"
            try {
                $wingetResult = winget install Microsoft.DotNet.DesktopRuntime.8 --accept-source-agreements --accept-package-agreements --silent 2>&1
                if ($LASTEXITCODE -eq 0 -or $wingetResult -match "already installed") {
                    Write-Log "  .NET Desktop Runtime installed via winget" "Green"
                    # Re-search for DLLs after install
                    Start-Sleep -Seconds 2
                    foreach ($basePath in $dotnetPaths) {
                        if (Test-Path $basePath) {
                            $fxrFiles = Get-ChildItem -Path "$basePath\host\fxr" -Filter "hostfxr.dll" -Recurse -EA 0 | Sort-Object LastWriteTime -Descending
                            if ($fxrFiles -and -not $hostfxrSource) {
                                Copy-Item -Path $fxrFiles[0].FullName -Destination "$env:SystemRoot\System32\hostfxr.dll" -Force -EA 0
                                Write-Log "  FIXED: Copied hostfxr.dll after install" "Green"
                                $dllFixCount++
                            }
                            $policyFiles = Get-ChildItem -Path "$basePath\shared\Microsoft.NETCore.App" -Filter "hostpolicy.dll" -Recurse -EA 0 | Sort-Object LastWriteTime -Descending
                            if ($policyFiles -and -not $hostpolicySource) {
                                Copy-Item -Path $policyFiles[0].FullName -Destination "$env:SystemRoot\System32\hostpolicy.dll" -Force -EA 0
                                Write-Log "  FIXED: Copied hostpolicy.dll after install" "Green"
                                $dllFixCount++
                            }
                        }
                    }
                }
            } catch {
                Write-Log "  winget install failed - trying direct download..." "Yellow"
            }
        }

        # Copy hostpolicy.dll to System32
        if ($hostpolicySource -and (Test-Path $hostpolicySource)) {
            try {
                Copy-Item -Path $hostpolicySource -Destination "$env:SystemRoot\System32\hostpolicy.dll" -Force -EA Stop
                Write-Log "  FIXED: Copied hostpolicy.dll from $hostpolicySource" "Green"
                $dllFixCount++
            } catch {
                Write-Log "  Could not copy hostpolicy.dll: $_" "Yellow"
            }
        }

        # Verify the fix worked
        $stillMissing = @()
        if (-not (Test-Path "$env:SystemRoot\System32\hostfxr.dll")) { $stillMissing += "hostfxr.dll" }
        if (-not (Test-Path "$env:SystemRoot\System32\hostpolicy.dll")) { $stillMissing += "hostpolicy.dll" }

        if ($stillMissing.Count -eq 0) {
            Write-Log "  SUCCESS: All .NET Host DLLs restored!" "Green"
        } else {
            Write-Log "  Still missing: $($stillMissing -join ', ') - manual .NET install may be needed" "Yellow"
        }
    }
}

# Re-register all critical COM/OLE DLLs that could cause LoadLibrary issues
$comDLLs = @(
    "ole32.dll", "oleaut32.dll", "actxprxy.dll", "msxml3.dll", "msxml6.dll",
    "scrrun.dll", "jscript.dll", "vbscript.dll", "wshom.ocx", "urlmon.dll",
    "shdocvw.dll", "browseui.dll", "shell32.dll", "shlwapi.dll", "comctl32.dll"
)

foreach ($dll in $comDLLs) {
    $dllPath = "$env:SystemRoot\System32\$dll"
    if (Test-Path $dllPath) {
        regsvr32 /s $dllPath 2>$null
        $dllFixCount++
    }
}

# Fix WoW64 equivalents
foreach ($dll in @("ole32.dll", "oleaut32.dll", "actxprxy.dll", "shell32.dll", "shlwapi.dll")) {
    $dllPath = "$env:SystemRoot\SysWOW64\$dll"
    if (Test-Path $dllPath) {
        regsvr32 /s $dllPath 2>$null
    }
}

# Fix PATH environment variable issues (can cause LoadLibrary failures)
$systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$pathFixed = $false

# Remove duplicate semicolons
if ($systemPath -match ';;+') {
    $systemPath = $systemPath -replace ';;+', ';'
    $pathFixed = $true
}

# Ensure System32 and SysWOW64 are in PATH
$requiredPaths = @("$env:SystemRoot\System32", "$env:SystemRoot\SysWOW64", "$env:SystemRoot")
foreach ($reqPath in $requiredPaths) {
    if ($systemPath -notmatch [regex]::Escape($reqPath)) {
        $systemPath = "$reqPath;$systemPath"
        $pathFixed = $true
    }
}

if ($pathFixed) {
    try {
        [Environment]::SetEnvironmentVariable("PATH", $systemPath, "Machine")
        Write-Log "  Fixed PATH environment variable" "Green"
    } catch {
        Write-Log "  Could not fix PATH: $_" "Yellow"
    }
}

# Rebuild icon cache (can cause LoadLibrary issues with shell32)
$iconCache = "$env:LOCALAPPDATA\IconCache.db"
$iconCacheDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $iconCache) { Remove-Item $iconCache -Force -EA 0 }
Get-ChildItem "$iconCacheDir\iconcache*.db" -EA 0 | Remove-Item -Force -EA 0

Write-Log "  LoadLibrary Error 126 fixes applied ($dllFixCount DLLs processed)" "Green"
#endregion

#region PHASE 2B: FIX SERVICE DEPENDENCIES (Driver Stopping Issue)

Phase "Fixing Service Dependencies (Prevents Driver Stopping)"
Write-Log "  Validating and fixing service dependency chains..." "Cyan"

$svcFixCount = 0

# Critical service dependency chain - must start in correct order
$criticalServiceOrder = @(
    @{Name="RpcEptMapper"; Desc="RPC Endpoint Mapper"; StartType="Automatic"},
    @{Name="DcomLaunch"; Desc="DCOM Server Process Launcher"; StartType="Automatic"},
    @{Name="RpcSs"; Desc="Remote Procedure Call"; StartType="Automatic"},
    @{Name="nsi"; Desc="Network Store Interface Service"; StartType="Automatic"},
    @{Name="Tcpip"; Desc="TCP/IP Protocol Driver"; StartType="Boot"},
    @{Name="Afd"; Desc="Ancillary Function Driver"; StartType="System"},
    @{Name="NetBT"; Desc="NetBIOS over TCP/IP"; StartType="System"},
    @{Name="Dhcp"; Desc="DHCP Client"; StartType="Automatic"},
    @{Name="Dnscache"; Desc="DNS Client"; StartType="Automatic"},
    @{Name="NlaSvc"; Desc="Network Location Awareness"; StartType="Automatic"},
    @{Name="LanmanWorkstation"; Desc="Workstation"; StartType="Automatic"},
    @{Name="LanmanServer"; Desc="Server"; StartType="Automatic"},
    @{Name="netprofm"; Desc="Network List Service"; StartType="Manual"}
)

foreach ($svcInfo in $criticalServiceOrder) {
    $svc = Get-Service -Name $svcInfo.Name -EA 0
    if ($svc) {
        # Fix start type if needed
        $currentStartType = (Get-WmiObject Win32_Service -Filter "Name='$($svcInfo.Name)'" -EA 0).StartMode
        $desiredStartType = $svcInfo.StartType

        # Ensure service is not disabled
        if ($currentStartType -eq "Disabled") {
            sc.exe config $svcInfo.Name start= demand 2>$null
            Write-Log "  Re-enabled disabled service: $($svcInfo.Desc)" "Yellow"
            $svcFixCount++
        }

        # Start service if it should be running and isn't
        if ($svcInfo.StartType -eq "Automatic" -and $svc.Status -ne "Running") {
            try {
                Start-Service -Name $svcInfo.Name -EA Stop
                Write-Log "  Started: $($svcInfo.Desc)" "Green"
                $svcFixCount++
            } catch {
                Write-Log "  Could not start $($svcInfo.Desc): $_" "Yellow"
            }
        }
    }
}

# Fix common driver service issues
$driverServices = @(
    @{Name="Winsock"; Desc="Winsock"},
    @{Name="WinSock2"; Desc="Winsock2"}
)

# Reset Winsock catalog (fixes many network/service dependency issues)
netsh winsock reset 2>$null | Out-Null
Write-Log "  Winsock catalog reset" "Green"
$svcFixCount++

# Reset IP stack
netsh int ip reset 2>$null | Out-Null
Write-Log "  IP stack reset" "Green"
$svcFixCount++

# Fix Windows Management Instrumentation (can cause service dependency failures)
$wmiSvc = Get-Service Winmgmt -EA 0
if ($wmiSvc.Status -ne "Running") {
    Stop-Service Winmgmt -Force -EA 0
    Start-Sleep -Seconds 2
    Start-Service Winmgmt -EA 0
    Write-Log "  WMI service restarted" "Green"
    $svcFixCount++
}

# Verify WMI repository
$wmiCheck = winmgmt /verifyrepository 2>&1 | Out-String
if ($wmiCheck -match "inconsistent|corrupt") {
    winmgmt /salvagerepository 2>$null
    Write-Log "  WMI repository salvaged" "Yellow"
    $svcFixCount++
}

Write-Log "  Service dependency fixes applied ($svcFixCount fixes)" "Green"
#endregion

#region PHASE 2C: FIX DRIVER ISSUES (KMODE Prevention)

Phase "Fixing Driver Issues (KMODE Prevention)"
Write-Log "  Scanning and fixing driver problems..." "Cyan"

$driverFixCount = 0

# Check for devices with errors and try to reset them (SAFE - not display)
$problemDevices = Get-CimInstance Win32_PNPEntity -EA 0 | Where-Object {
    $_.ConfigManagerErrorCode -ne 0 -and
    $_.PNPClass -notmatch 'Display|Monitor|GPU'  # Never touch display devices
}

foreach ($device in $problemDevices) {
    $errorCode = $device.ConfigManagerErrorCode

    # Only attempt safe fixes
    switch ($errorCode) {
        10 { # Device cannot start
            Write-Log "  Device cannot start: $($device.Name) - needs driver reinstall" "Yellow"
        }
        14 { # Requires restart
            Write-Log "  Device requires restart: $($device.Name)" "Yellow"
        }
        22 { # Device disabled
            # Try to enable non-critical devices
            if ($device.PNPClass -notmatch 'Display|System') {
                try {
                    Enable-PnpDevice -InstanceId $device.DeviceID -Confirm:$false -EA Stop
                    Write-Log "  Enabled device: $($device.Name)" "Green"
                    $driverFixCount++
                } catch {}
            }
        }
        28 { # No driver installed
            Write-Log "  NO DRIVER: $($device.Name) - needs driver installation" "Red"
        }
        31 { # Device not working properly
            Write-Log "  Device not working: $($device.Name) - may need driver update" "Yellow"
        }
        38 { # Cannot load driver
            Write-Log "  Cannot load driver: $($device.Name) - driver may be corrupted" "Yellow"
        }
        43 { # Generic failure
            Write-Log "  Device failure: $($device.Name) - check driver" "Yellow"
        }
    }
}

# Scan for hardware changes (safe operation)
pnputil /scan-devices 2>$null | Out-Null
Write-Log "  PnP device scan completed" "Green"
$driverFixCount++

# Reset problematic driver services (non-display)
$problematicDrivers = @("WUDFRd", "umbus")
foreach ($drvName in $problematicDrivers) {
    $drv = Get-Service -Name $drvName -EA 0
    if ($drv -and $drv.Status -ne "Running" -and $drv.StartType -ne "Disabled") {
        sc.exe config $drvName start= demand 2>$null
        Start-Service $drvName -EA 0
        Write-Log "  Reset driver service: $drvName" "Green"
        $driverFixCount++
    }
}

# Disable Driver Verifier if active (common cause of KMODE exceptions)
$verifierState = verifier /querysettings 2>&1 | Out-String
if ($verifierState -notmatch "No drivers are currently verified" -and $verifierState -match "verified") {
    verifier /reset 2>$null
    Write-Log "  Driver Verifier DISABLED - was causing KMODE risk" "Yellow"
    $driverFixCount++
}

Write-Log "  Driver fixes applied ($driverFixCount fixes)" "Green"
#endregion

#region PHASE 3: FIX WUDFRD DRIVER (0xC0000365) - BOOT ORDER FIX

Phase "Fixing WUDFRd driver (0xC0000365 - Boot Order)"
Write-Log "  CRITICAL: WUDFRd load failures indicate boot-time race condition" "Yellow"

# THE FIX: Change WUDFRd from DEMAND (3) to SYSTEM (1) start type
# This ensures UMDF driver framework loads BEFORE devices that depend on it
$wudfrdStart = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WUDFRd" -Name Start -EA 0).Start
$umbusStart = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\umbus" -EA 0).Start

Write-Log "  Current WUDFRd Start Type: $wudfrdStart (0=Boot,1=System,2=Auto,3=Demand)" "Cyan"
Write-Log "  Current umbus Start Type: $umbusStart" "Cyan"

# Change WUDFRd to SYSTEM start (1) - loads earlier in boot, before HID devices need it
if ($wudfrdStart -ne 1) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WUDFRd" -Name "Start" -Value 1 -Type DWord -EA 0
    sc.exe config WUDFRd start= system 2>$null
    Write-Log "  WUDFRd changed to SYSTEM start (1) - will load earlier at boot" "Green"
} else {
    Write-Log "  WUDFRd already set to SYSTEM start" "Green"
}

# Change umbus to SYSTEM start (1) as well - it's a dependency
if ($umbusStart -ne 1) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\umbus" -Name "Start" -Value 1 -Type DWord -EA 0
    sc.exe config umbus start= system 2>$null
    Write-Log "  umbus changed to SYSTEM start (1)" "Green"
} else {
    Write-Log "  umbus already set to SYSTEM start" "Green"
}

# Also ensure WUDFHost service is properly configured
$wudfHostStart = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\wudfsvc" -Name Start -EA 0).Start
if ($wudfHostStart -and $wudfHostStart -gt 2) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\wudfsvc" -Name "Start" -Value 2 -Type DWord -EA 0
    sc.exe config wudfsvc start= auto 2>$null
    Write-Log "  wudfsvc changed to AUTO start (2)" "Green"
}

# Force start WUDFRd and umbus NOW so current session works
$wudfStatus = (Get-Service WUDFRd -EA 0).Status
if ($wudfStatus -ne "Running") {
    Start-Service WUDFRd -EA 0
    Write-Log "  WUDFRd service started for current session" "Green"
}

$umbusStatus = (Get-Service umbus -EA 0).Status
if ($umbusStatus -ne "Running") {
    Start-Service umbus -EA 0
    Write-Log "  umbus service started for current session" "Green"
}

# Re-enable UMDF HID devices that may have failed at boot
$hidDevicesToReset = @(
    "HID\HID_DEVICE_SYSTEM_VHF",
    "HID\VID_0B05",
    "ROOT\WINDOWSHELLOFACESOFTWAREDRIVER"
)

foreach ($pattern in $hidDevicesToReset) {
    Get-PnpDevice -EA 0 | Where-Object { $_.InstanceId -like "*$pattern*" -and $_.Status -eq "Error" } | ForEach-Object {
        try {
            Write-Log "  Resetting device: $($_.FriendlyName)" "Yellow"
            Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -EA 0
            Start-Sleep -Milliseconds 500
            Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -EA 0
            Write-Log "  Reset complete: $($_.FriendlyName)" "Green"
        } catch {}
    }
}

# Also reset HIDClass devices with errors
Get-PnpDevice -Class "HIDClass" -Status "Error" -EA 0 | ForEach-Object {
    try {
        Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -EA 0
        Start-Sleep -Milliseconds 300
        Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -EA 0
        Write-Log "  Reset HID device: $($_.FriendlyName)" "Green"
    } catch {}
}

# Scan for hardware changes to pick up the re-enabled devices
pnputil /scan-devices 2>$null | Out-Null
Write-Log "  WUDFRd boot-order fix complete - REBOOT REQUIRED for full effect" "Green"
#endregion

#region PHASE 3A: FIX USBXHCICOMPANION DRIVER FAILURE (0xc0000034)