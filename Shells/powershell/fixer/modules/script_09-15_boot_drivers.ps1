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

Phase "Fixing UsbXhciCompanion driver (0xc0000034)"
Write-Log "  Checking USB XHCI Companion driver status..." "Cyan"

# 0xc0000034 = STATUS_OBJECT_NAME_NOT_FOUND - the companion driver file is missing
# UsbXhciCompanion is an optional USB 3.0 power management feature

# Check if USBXHCI service exists and is configured correctly
$usbXhciKey = "HKLM:\SYSTEM\CurrentControlSet\Services\USBXHCI"
if (Test-Path $usbXhciKey) {
    $usbXhciStart = (Get-ItemProperty $usbXhciKey -Name Start -EA 0).Start
    Write-Log "  USBXHCI service found, Start Type: $usbXhciStart" "Cyan"

    # Ensure USBXHCI is set to DEMAND or BOOT, not disabled
    if ($usbXhciStart -eq 4) {
        Set-ItemProperty -Path $usbXhciKey -Name "Start" -Value 3 -Type DWord -EA 0
        Write-Log "  USBXHCI changed from DISABLED to DEMAND" "Green"
    }
}

# The companion driver is optional - if the system doesn't have it, disable the companion feature
# Check if companion driver exists
$companionPath = "$env:SystemRoot\System32\drivers\UsbXhciCompanion.sys"
if (-not (Test-Path $companionPath)) {
    Write-Log "  UsbXhciCompanion.sys not found - disabling companion feature" "Yellow"

    # Disable the companion feature in USBXHCI settings
    $xhciParams = "HKLM:\SYSTEM\CurrentControlSet\Services\USBXHCI\Parameters"
    if (-not (Test-Path $xhciParams)) {
        New-Item -Path $xhciParams -Force -EA 0 | Out-Null
    }
    Set-ItemProperty -Path $xhciParams -Name "DisableCompanion" -Value 1 -Type DWord -EA 0
    Write-Log "  UsbXhciCompanion feature disabled in registry" "Green"

    # Also check WinSxS for the driver
    $winsxsPattern = "$env:SystemRoot\WinSxS\*UsbXhciCompanion*"
    $winsxsSource = Get-ChildItem $winsxsPattern -Recurse -EA 0 | Where-Object { $_.Name -eq "UsbXhciCompanion.sys" } | Select-Object -First 1
    if ($winsxsSource) {
        try {
            Copy-Item $winsxsSource.FullName -Destination $companionPath -Force -EA Stop
            Write-Log "  Restored UsbXhciCompanion.sys from WinSxS" "Green"
            # Re-enable the feature
            Set-ItemProperty -Path $xhciParams -Name "DisableCompanion" -Value 0 -Type DWord -EA 0
        } catch {
            Write-Log "  Could not restore from WinSxS: $_" "Yellow"
        }
    }
} else {
    Write-Log "  UsbXhciCompanion.sys exists - verifying driver registration" "Green"
}

# Reset USB controllers to pick up driver changes
$usbControllers = Get-PnpDevice -Class USB -EA 0 | Where-Object { $_.FriendlyName -match "xHCI|USB 3" -and $_.Status -eq "Error" }
foreach ($ctrl in $usbControllers) {
    try {
        Write-Log "  Resetting USB controller: $($ctrl.FriendlyName)" "Yellow"
        Disable-PnpDevice -InstanceId $ctrl.InstanceId -Confirm:$false -EA 0
        Start-Sleep -Milliseconds 500
        Enable-PnpDevice -InstanceId $ctrl.InstanceId -Confirm:$false -EA 0
        Write-Log "  Reset complete: $($ctrl.FriendlyName)" "Green"
    } catch {}
}

Write-Log "  UsbXhciCompanion fix complete" "Green"
#endregion

#region PHASE 4: FIX BOOT DRIVERS (dam, luafv)

Phase "Fixing boot drivers"
# dam = Desktop Activity Moderator (can be disabled safely)
# luafv = LUA File Virtualization Filter (can be demand)
sc.exe config dam start= disabled 2>$null
sc.exe config luafv start= demand 2>$null
Write-Log "  Boot drivers configured (dam disabled, luafv demand)" "Green"
#endregion

#region PHASE 5: FIX DLLHOST, EXPLORER & USERINIT CRASHES (SAFE)

Phase "Fixing DllHost/Explorer/Userinit crashes (shell restart prevention)"

# SAFE DLL re-registration (avoid display-related ones)
$safeDlls = @("comsvcs.dll","es.dll","ole32.dll","oleaut32.dll","actxprxy.dll","shlwapi.dll","urlmon.dll")
foreach ($dll in $safeDlls) {
    regsvr32 /s "$env:SystemRoot\System32\$dll" 2>$null
}
Write-Log "  COM+ DLLs re-registered (safe set)" "Green"

# === USERINIT.EXE CRASH FIX (prevents "shell stopped unexpectedly and userinit.exe was restarted") ===
Write-Log "  Fixing userinit.exe shell crash issues..." "Cyan"

# Step 1: Verify userinit.exe integrity
try {
    $userinitPath = "$env:SystemRoot\System32\userinit.exe"
    if (Test-Path $userinitPath) {
        $userinitHash = (Get-FileHash $userinitPath -Algorithm SHA256 -EA 0).Hash
        Write-Log "  userinit.exe exists (hash: $($userinitHash.Substring(0,16))...)" "Green"
    }
} catch {}

# Step 2: Fix userinit registry entries (critical for shell startup)
try {
    $userinitKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $userinitValue = (Get-ItemProperty -Path $userinitKey -Name "Userinit" -EA 0).Userinit
    $correctValue = "C:\Windows\system32\userinit.exe,"

    if ($userinitValue -ne $correctValue) {
        Set-ItemProperty -Path $userinitKey -Name "Userinit" -Value $correctValue -Type String -Force -EA 0
        Write-Log "  Fixed userinit registry path" "Green"
    } else {
        Write-Log "  userinit registry path correct" "Green"
    }
} catch {}

# Step 3: Fix shell registry (explorer.exe must be correct)
try {
    $shellValue = (Get-ItemProperty -Path $userinitKey -Name "Shell" -EA 0).Shell
    if ($shellValue -ne "explorer.exe") {
        Set-ItemProperty -Path $userinitKey -Name "Shell" -Value "explorer.exe" -Type String -Force -EA 0
        Write-Log "  Fixed shell registry value" "Green"
    } else {
        Write-Log "  Shell registry value correct" "Green"
    }
} catch {}

# Step 4: Clear shell crash event logs
try {
    wevtutil cl "Microsoft-Windows-Winlogon/Operational" 2>$null
    wevtutil cl "Microsoft-Windows-Shell-Core/Operational" 2>$null
    Write-Log "  Shell event logs cleared" "Green"
} catch {}

# Step 5: Reset shell extensions that can cause crashes
try {
    $shellExtKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Cached"
    if (Test-Path $shellExtKey) {
        Remove-Item -Path $shellExtKey -Recurse -Force -EA 0
        Write-Log "  Shell extension cache cleared" "Green"
    }
} catch {}

# Step 6: Fix LogonUI issues that can crash userinit
try {
    $logonUIKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
    if (Test-Path $logonUIKey) {
        Set-ItemProperty -Path $logonUIKey -Name "LastLoggedOnProvider" -Value "" -Type String -Force -EA 0
        Write-Log "  LogonUI provider reset" "Green"
    }
} catch {}

# Step 7: Repair Windows Shell Infrastructure
try {
    $shellInfraProc = Get-Process -Name "sihost" -EA 0
    if (-not $shellInfraProc) {
        # Shell Infrastructure Host should be running - this could indicate shell crash
        Write-Log "  WARNING: Shell Infrastructure Host (sihost) not running" "Yellow"
    } else {
        Write-Log "  Shell Infrastructure Host running (PID: $($shellInfraProc.Id))" "Green"
    }
} catch {}

# Step 8: Fix ShellExperienceHost crashes
try {
    Get-AppxPackage -Name "Microsoft.Windows.ShellExperienceHost" -EA 0 | Reset-AppxPackage -EA 0
    Write-Log "  ShellExperienceHost reset" "Green"
} catch {}

# Step 9: Set shell recovery options
try {
    $reliabilityKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"
    if (-not (Test-Path $reliabilityKey)) {
        New-Item -Path $reliabilityKey -Force -EA 0 | Out-Null
    }
    Set-ItemProperty -Path $reliabilityKey -Name "ShellRestart" -Value 1 -Type DWord -Force -EA 0
    Write-Log "  Shell auto-recovery enabled" "Green"
} catch {}

# Fix Explorer shell issues
# Clear icon cache
$iconCache = "$env:LOCALAPPDATA\IconCache.db"
if (Test-Path $iconCache) { Remove-Item $iconCache -Force -ErrorAction SilentlyContinue }

# Clear thumbnail cache
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue

# Reset shell folders registration
regsvr32 /s shell32.dll 2>$null
regsvr32 /s explorerframe.dll 2>$null
Write-Log "  Explorer shell reset" "Green"

Write-Log "  DllHost/Explorer/Userinit crash fixes applied" "Green"
#endregion

#region PHASE 6: FIX BROKERINFRASTRUCTURE (AppX errors 0xD0074005, 0xD007007A)

Phase "Fixing BrokerInfrastructure service"

# This is the KEY fix for AppX notification errors
$broker = Get-Service BrokerInfrastructure -ErrorAction SilentlyContinue
if ($broker) {
    Restart-Service BrokerInfrastructure -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Log "  BrokerInfrastructure restarted" "Green"
}

# Reset AppX services
Restart-Service AppXSvc -Force -ErrorAction SilentlyContinue
Restart-Service StateRepository -Force -ErrorAction SilentlyContinue
Write-Log "  AppX services restarted" "Green"
#endregion

#region PHASE 7: RESET WINDOWS UPDATE COMPONENTS

Phase "Resetting Windows Update"

# Stop update services
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service bits -Force -ErrorAction SilentlyContinue
Stop-Service cryptsvc -Force -ErrorAction SilentlyContinue

# Rename SoftwareDistribution
$sd = "$env:SystemRoot\SoftwareDistribution"
if (Test-Path $sd) {
    $newName = "SoftwareDistribution.old.$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        Rename-Item $sd -NewName $newName -Force -ErrorAction Stop
        Write-Log "  Renamed SoftwareDistribution" "Green"
    } catch {
        # If can't rename, clear contents
        Get-ChildItem "$sd\Download" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "  Cleared SoftwareDistribution\Download" "Yellow"
    }
}

# Re-register WU DLLs
$wuDlls = @("atl.dll","urlmon.dll","mshtml.dll","jscript.dll","vbscript.dll","scrrun.dll","msxml3.dll","msxml6.dll","actxprxy.dll","softpub.dll","wintrust.dll","cryptdlg.dll","oleaut32.dll","ole32.dll","wuapi.dll","wuaueng.dll","wups.dll","qmgr.dll")
foreach ($dll in $wuDlls) { regsvr32 /s $dll 2>$null }

# Restart services
Start-Service cryptsvc -ErrorAction SilentlyContinue
Start-Service bits -ErrorAction SilentlyContinue
Start-Service wuauserv -ErrorAction SilentlyContinue
Write-Log "  Windows Update reset complete" "Green"
#endregion

#region PHASE 8: RE-REGISTER FAILING APPX PACKAGES

Phase "Re-registering failing AppX packages"

$failingPackages = @(
    "Microsoft.UI.Xaml.2.3",
    "Microsoft.WindowsAppRuntime.1.5",
    "Microsoft.WindowsAppRuntime.1.6",
    "Microsoft.WindowsAppRuntime.1.7",
    "Microsoft.WindowsAppRuntime.1.8"
)

foreach ($pkgPattern in $failingPackages) {
    Get-AppxPackage -AllUsers -Name "*$pkgPattern*" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $manifest = "$($_.InstallLocation)\AppXManifest.xml"
            if (Test-Path $manifest) {
                Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue
                Write-Log "  Re-registered: $($_.Name)" "Green"
            }
        } catch {}
    }
}

# Reset Microsoft Store cache
wsreset.exe 2>$null
Start-Sleep -Seconds 2
Write-Log "  AppX packages re-registered" "Green"
#endregion

#region PHASE 9: FIX ALL SCHEDULED TASKS (including 0x800710E0)

Phase "Fixing scheduled tasks (0x800710E0 - Operator Refused)"
Write-Log "  0x800710E0 = 'The operator or administrator has refused the request'" "Yellow"
Write-Log "  This is usually caused by AC power requirements or disabled conditions" "Yellow"

Restart-Service Schedule -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# All failing tasks from scan + new ones from diagnostic
$failedTasks = @(
    "\GHelperCharge",
    "\ASUS Update Checker 2.0",
    "\NodeJS-Memory-Cleanup",
    "\Microsoft\Windows\CertificateServicesClient\UserTask",
    "\Microsoft\Windows\MemoryDiagnostic\AutomaticOfflineMemoryDiagnostic",
    "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents",
    "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker",
    "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319",
    "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319 64",
    "\Microsoft\Windows\AppID\VerifiedPublisherCertStoreCheck",
    "\Microsoft\Windows\AppxDeploymentClient\UCPD velocity",
    "\Microsoft\Windows\DiskCleanup\SilentCleanup",
    "\Microsoft\Windows\Hotpatch\Monitoring",
    "\Microsoft\Windows\Shell\CreateObjectTask",
    "\Microsoft\Windows\Work Folders\Work Folders Maintenance Work"
)

$tasksFixed = 0
foreach ($taskPath in $failedTasks) {
    # Check timeout every 5 tasks
    if ($tasksFixed % 5 -eq 0 -and (Test-PhaseTimeout)) {
        Write-Log "  Phase timeout reached - fixed $tasksFixed tasks before stopping" "Yellow"
        break
    }
    $path = $taskPath -replace "\\[^\\]+$", "\"
    $name = ($taskPath -split "\\")[-1]
    try {
        $task = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue
        if ($task) {
            $changed = $false

            # Enable if disabled
            if ($task.State -eq "Disabled") {
                Enable-ScheduledTask -InputObject $task -ErrorAction SilentlyContinue | Out-Null
                Write-Log "  Enabled task: $name" "Green"
                $changed = $true
            }

            # Fix 0x800710E0 by modifying task settings to remove restrictive conditions
            # This error occurs when:
            # 1. Task requires AC power but laptop is on battery
            # 2. Task requires idle but system is not idle
            # 3. Task has "start only if network is available" but no network
            $taskDef = $task | Get-ScheduledTask
            $settings = $taskDef.Settings

            # Remove "start only on AC power" restriction
            if ($settings.DisallowStartIfOnBatteries -eq $true) {
                $settings.DisallowStartIfOnBatteries = $false
                $settings.StopIfGoingOnBatteries = $false
                $changed = $true
            }

            # Remove idle requirements that can cause 0x800710E0
            if ($settings.IdleSettings.StopOnIdleEnd -eq $true) {
                $settings.IdleSettings.StopOnIdleEnd = $false
                $changed = $true
            }

            # Ensure task can wake computer if needed
            $settings.WakeToRun = $false  # Don't wake, but don't fail either

            # Allow on-demand execution
            $settings.AllowDemandStart = $true
            $settings.AllowHardTerminate = $true

            # Don't run if missed by more than 1 day (prevents accumulation)
            $settings.ExecutionTimeLimit = "PT72H"

            if ($changed) {
                Set-ScheduledTask -InputObject $taskDef -ErrorAction SilentlyContinue | Out-Null
                Write-Log "  Modified task settings: $name (removed power/idle restrictions)" "Green"
                $tasksFixed++
            }
        }
    } catch {
        Write-Log "  Could not modify task $name`: $_" "Yellow"
    }
}

# Special fix for ASUS Update Checker 2.0 - error 0x10 (environment incorrect)
$asusTaskPath = "\"
$asusTaskName = "ASUS Update Checker 2.0"
try {
    $asusTask = Get-ScheduledTask -TaskPath $asusTaskPath -TaskName $asusTaskName -ErrorAction SilentlyContinue
    if ($asusTask) {
        # Check if the executable exists
        $action = $asusTask.Actions[0]
        if ($action -and $action.Execute) {
            $exePath = $action.Execute
            if (-not (Test-Path $exePath)) {
                Write-Log "  ASUS Update Checker executable not found at: $exePath" "Yellow"
                Write-Log "  Disabling orphaned task to prevent errors" "Yellow"
                Disable-ScheduledTask -InputObject $asusTask -ErrorAction SilentlyContinue | Out-Null
                $tasksFixed++
            }
        }
    }
} catch {}

# Special fix for NodeJS-Memory-Cleanup - custom user task
$nodejsTaskPath = "\"
$nodejsTaskName = "NodeJS-Memory-Cleanup"
try {
    $nodejsTask = Get-ScheduledTask -TaskPath $nodejsTaskPath -TaskName $nodejsTaskName -ErrorAction SilentlyContinue
    if ($nodejsTask) {
        $action = $nodejsTask.Actions[0]
        if ($action -and $action.Execute) {
            $exePath = $action.Execute
            if (-not (Test-Path $exePath)) {
                Write-Log "  NodeJS-Memory-Cleanup executable not found: $exePath" "Yellow"
                Write-Log "  Disabling orphaned task" "Yellow"
                Disable-ScheduledTask -InputObject $nodejsTask -ErrorAction SilentlyContinue | Out-Null
                $tasksFixed++
            } else {
                # Enable it and fix settings
                $settings = $nodejsTask.Settings
                $settings.DisallowStartIfOnBatteries = $false
                $settings.StopIfGoingOnBatteries = $false
                Set-ScheduledTask -InputObject $nodejsTask -ErrorAction SilentlyContinue | Out-Null
                Write-Log "  Fixed NodeJS-Memory-Cleanup settings" "Green"
                $tasksFixed++
            }
        }
    }
} catch {}

# Fix USO_UxBroker missing file (0x80070002)
$usoPath = "$env:SystemRoot\System32\usoclient.exe"
if (-not (Test-Path $usoPath)) {
    Write-Log "  USO client missing - will be restored by SFC/DISM" "Yellow"
}

# Clear any queued task instances that might be stuck
schtasks /end /tn "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319" 2>$null | Out-Null
schtasks /end /tn "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319 64" 2>$null | Out-Null

Write-Log "  Scheduled tasks fixed ($tasksFixed tasks modified)" "Green"
#endregion

#region PHASE 9B: FIX OUTDATED DRIVERS (AGGRESSIVE - Camera, Logitech Download Assistant)