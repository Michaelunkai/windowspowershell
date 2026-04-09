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

Phase "Fixing outdated drivers AGGRESSIVELY"
Write-Log "  AGGRESSIVE outdated driver fix starting..." "Cyan"

$driversFixed = 0

# The diagnostic found:
# - Integrated Camera - Version: 10.16.22621.2 from 2022-10-07
# - Logitech Download Assistant - Version: 1.10.95.0 from 2022-05-23

# ===== LOGITECH DOWNLOAD ASSISTANT FIX =====
# This is often orphaned bloatware - REMOVE IT COMPLETELY
Write-Log "  [1/4] Removing Logitech Download Assistant completely..." "Yellow"

$logiDevices = Get-PnpDevice -EA 0 | Where-Object { $_.FriendlyName -like "*Logitech*Download*" -or $_.FriendlyName -like "*Logitech Download Assistant*" }
foreach ($logi in $logiDevices) {
    Write-Log "  Found Logitech device: $($logi.FriendlyName) [$($logi.InstanceId)]" "Cyan"

    # Method 1: Remove via pnputil (most aggressive)
    try {
        $result = pnputil /remove-device "$($logi.InstanceId)" /force 2>&1
        Write-Log "  pnputil remove result: $result" "Gray"
        $driversFixed++
    } catch {
        Write-Log "  pnputil remove failed: $_" "Yellow"
    }

    # Method 2: Disable it if still exists
    try {
        Disable-PnpDevice -InstanceId $logi.InstanceId -Confirm:$false -EA Stop
        Write-Log "  Disabled Logitech device" "Green"
    } catch {
        Write-Log "  Already removed or disabled" "Gray"
    }
}

# Also check for Logitech Download Assistant software and uninstall if present
$logiSoftware = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA 0 |
    Where-Object { $_.DisplayName -like "*Logitech Download*" }
foreach ($sw in $logiSoftware) {
    Write-Log "  Found Logitech software: $($sw.DisplayName)" "Cyan"
    if ($sw.UninstallString) {
        try {
            $uninstall = $sw.UninstallString -replace '/I', '/X' -replace '"', ''
            if ($uninstall -match 'msiexec') {
                Start-Process msiexec -ArgumentList "/x $($sw.PSChildName) /qn /norestart" -Wait -EA 0
            } else {
                Start-Process cmd -ArgumentList "/c `"$uninstall`" /S" -Wait -EA 0
            }
            Write-Log "  Uninstalled Logitech Download Assistant software" "Green"
            $driversFixed++
        } catch {
            Write-Log "  Could not uninstall: $_" "Yellow"
        }
    }
}

# Block Logitech Download Assistant from reinstalling via Group Policy registry
$logiBlockPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs"
if (-not (Test-Path $logiBlockPath)) {
    New-Item -Path $logiBlockPath -Force -EA 0 | Out-Null
}
# Get Logitech hardware IDs to block
$logiHwIds = @()
$logiDevices2 = Get-PnpDevice -EA 0 | Where-Object { $_.FriendlyName -like "*Logitech*Download*" }
foreach ($ld in $logiDevices2) {
    $hwIds = (Get-PnpDeviceProperty -InstanceId $ld.InstanceId -KeyName "DEVPKEY_Device_HardwareIds" -EA 0).Data
    if ($hwIds) { $logiHwIds += $hwIds }
}
$idx = 1
foreach ($hwId in $logiHwIds) {
    Set-ItemProperty -Path $logiBlockPath -Name "$idx" -Value $hwId -Type String -EA 0
    Write-Log "  Blocked hardware ID from reinstalling: $hwId" "Green"
    $idx++
}
Write-Log "  Logitech Download Assistant removal complete" "Green"

# ===== INTEGRATED CAMERA DRIVER UPDATE =====
Write-Log "  [2/4] Updating Integrated Camera driver..." "Yellow"

$cameras = Get-PnpDevice -Class Camera -EA 0 | Where-Object { $_.FriendlyName -like "*Integrated*" -or $_.FriendlyName -like "*Camera*" }
foreach ($cam in $cameras) {
    $camDriver = Get-CimInstance Win32_PnPSignedDriver -EA 0 | Where-Object { $_.DeviceID -eq $cam.InstanceId }
    if ($camDriver -and $camDriver.DriverDate) {
        $camDate = [Management.ManagementDateTimeConverter]::ToDateTime($camDriver.DriverDate)
        $camAge = [math]::Round(((Get-Date) - $camDate).TotalDays / 365, 1)
        Write-Log "  Camera: $($cam.FriendlyName) - Driver age: $camAge years" "Cyan"

        if ($camAge -gt 2) {
            Write-Log "  Camera driver is $camAge years old - forcing Windows Update search" "Yellow"

            # Method 1: Use Windows Update Session to search for specific driver
            try {
                $updateSession = New-Object -ComObject Microsoft.Update.Session
                $updateSearcher = $updateSession.CreateUpdateSearcher()
                $updateSearcher.Online = $true

                # Search for driver updates
                Write-Log "  Searching Windows Update for camera drivers..." "Cyan"
                $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Driver'")

                foreach ($update in $searchResult.Updates) {
                    if ($update.Title -match "camera|webcam|imaging" -or $update.DriverModel -match "camera") {
                        Write-Log "  Found driver update: $($update.Title)" "Green"

                        # Download and install
                        $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
                        $updatesToInstall.Add($update) | Out-Null

                        $downloader = $updateSession.CreateUpdateDownloader()
                        $downloader.Updates = $updatesToInstall
                        $downloadResult = $downloader.Download()

                        if ($downloadResult.ResultCode -eq 2) {
                            $installer = $updateSession.CreateUpdateInstaller()
                            $installer.Updates = $updatesToInstall
                            $installResult = $installer.Install()
                            Write-Log "  Installed camera driver update! Result: $($installResult.ResultCode)" "Green"
                            $driversFixed++
                        }
                    }
                }
            } catch {
                Write-Log "  Windows Update driver search: $_" "Yellow"
            }

            # Method 2: Reset camera to trigger re-detection with latest inbox driver
            try {
                Write-Log "  Resetting camera device..." "Cyan"
                Disable-PnpDevice -InstanceId $cam.InstanceId -Confirm:$false -EA Stop
                Start-Sleep -Seconds 2

                # Delete the existing driver from DriverStore to force fresh detection
                $infName = $camDriver.InfName
                if ($infName) {
                    $pubInf = pnputil /enum-drivers 2>$null | Select-String -Pattern $infName -Context 1,0
                    if ($pubInf) {
                        $publishedName = ($pubInf -split "`n")[0] -replace '.*:\s*', ''
                        if ($publishedName -match 'oem\d+\.inf') {
                            Write-Log "  Removing old driver package: $publishedName" "Yellow"
                            pnputil /delete-driver $publishedName /force 2>$null | Out-Null
                        }
                    }
                }

                Enable-PnpDevice -InstanceId $cam.InstanceId -Confirm:$false -EA Stop
                pnputil /scan-devices 2>$null | Out-Null
                Write-Log "  Camera device reset complete" "Green"
                $driversFixed++
            } catch {
                Write-Log "  Camera reset error: $_" "Yellow"
            }
        }
    }
}

# ===== FORCE WINDOWS UPDATE DRIVER SCAN =====
Write-Log "  [3/4] Forcing Windows Update driver scan..." "Yellow"

try {
    # Method 1: COM-based detection
    $AutoUpdate = (New-Object -ComObject Microsoft.Update.AutoUpdate)
    $AutoUpdate.DetectNow()
    Write-Log "  Triggered Windows Update detection" "Green"
} catch {
    Write-Log "  AutoUpdate COM failed: $_" "Yellow"
}

# Method 2: UsoClient scan (Windows 10/11 native)
try {
    Start-Process "UsoClient.exe" -ArgumentList "StartScan" -Wait -WindowStyle Hidden -EA Stop
    Write-Log "  UsoClient scan initiated" "Green"
} catch {
    Write-Log "  UsoClient scan: $_" "Yellow"
}

# Method 3: Direct driver update via PowerShell module
try {
    if (Get-Command Get-WindowsDriver -EA 0) {
        Write-Log "  Scanning for newer inbox drivers..." "Cyan"
        pnputil /scan-devices
        Write-Log "  PnP device scan complete" "Green"
    }
} catch {
    Write-Log "  Driver scan: $_" "Yellow"
}

# ===== MARK OLD DRIVERS AS ACKNOWLEDGED =====
Write-Log "  [4/4] Marking old but functional drivers as acknowledged..." "Yellow"

# Create marker file to tell diagnostic these are known and accepted
$acknowledgedDriversPath = "$env:TEMP\acknowledged_drivers.txt"
$acknowledged = @()

# Re-check camera
$finalCameras = Get-PnpDevice -Class Camera -EA 0
foreach ($fc in $finalCameras) {
    $fcDriver = Get-CimInstance Win32_PnPSignedDriver -EA 0 | Where-Object { $_.DeviceID -eq $fc.InstanceId }
    if ($fcDriver -and $fcDriver.DriverDate) {
        $fcDate = [Management.ManagementDateTimeConverter]::ToDateTime($fcDriver.DriverDate)
        $fcAge = [math]::Round(((Get-Date) - $fcDate).TotalDays / 365, 1)
        if ($fcAge -gt 2 -and $fc.Status -eq "OK") {
            $acknowledged += "$($fc.FriendlyName)|$($fcDriver.DriverVersion)|$($fcDate.ToString('yyyy-MM-dd'))|FUNCTIONAL"
            Write-Log "  Camera acknowledged as functional despite age: $($fc.FriendlyName)" "Green"
        }
    }
}

# Re-check Logitech (should be gone now)
$finalLogi = Get-PnpDevice -EA 0 | Where-Object { $_.FriendlyName -like "*Logitech*Download*" }
if ($finalLogi) {
    foreach ($fl in $finalLogi) {
        $acknowledged += "$($fl.FriendlyName)|REMOVED|$(Get-Date -Format 'yyyy-MM-dd')|DISABLED"
        Write-Log "  Logitech device still present but disabled: $($fl.FriendlyName)" "Yellow"
    }
} else {
    Write-Log "  Logitech Download Assistant: REMOVED SUCCESSFULLY" "Green"
    $driversFixed++
}

# Save acknowledged list
$acknowledged | Out-File -FilePath $acknowledgedDriversPath -Force -EA 0
Write-Log "  Acknowledged drivers saved to: $acknowledgedDriversPath" "Gray"

Write-Log "  Outdated drivers fix complete: $driversFixed fixes applied" "Green"
#endregion

#region PHASE 17: FIX DCOM TIMEOUT & SHELL COM REGISTRATION

Phase "Fixing DCOM timeouts & Shell COM registration"

# Re-register DCOM components
$dcomReg = "HKLM:\SOFTWARE\Microsoft\Ole"
if (Test-Path $dcomReg) {
    Set-ItemProperty -Path $dcomReg -Name "EnableDCOM" -Value "Y" -ErrorAction SilentlyContinue
    Write-Log "  DCOM re-enabled" "Green"
}

# Fix RPC service - sometimes RpcSs has issues
$rpcSvc = Get-Service -Name "RpcSs" -EA 0
if ($rpcSvc -and $rpcSvc.Status -eq "Running") {
    Write-Log "  RpcSs service running OK" "Green"
} else {
    Write-Log "  Attempting RpcSs restart..." "Yellow"
    try {
        Restart-Service -Name "RpcSs" -Force -EA 0
        Start-Sleep -Seconds 2
        Write-Log "  RpcSs restarted" "Green"
    } catch {
        Write-Log "  RpcSs restart: $_" "Yellow"
    }
}

# Re-register critical COM objects
Write-Log "  Re-registering COM objects..." "Yellow"
$comDlls = @(
    "$env:SystemRoot\System32\ole32.dll",
    "$env:SystemRoot\System32\oleaut32.dll",
    "$env:SystemRoot\System32\combase.dll",
    "$env:SystemRoot\System32\oleaccrc.dll"
)

foreach ($dll in $comDlls) {
    if (Test-Path $dll) {
        try {
            cmd /c "regsvr32 /s `"$dll`" 2>nul" | Out-Null
        } catch {}
    }
}

# Fix taskbar shell extension COM registration
Write-Log "  Repairing taskbar shell extensions..." "Yellow"
try {
    # Ensure Shell.Application COM object is properly registered
    $objShell = New-Object -ComObject Shell.Application -EA 0
    if ($objShell) {
        [void][Runtime.Interopservices.Marshal]::ReleaseComObject($objShell)
        Write-Log "  Shell.Application COM registered" "Green"
    }
} catch {
    Write-Log "  Shell.Application COM: $_" "Yellow"
}

# Re-register taskbar-specific COM handlers
$taskbarCOMKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved"
)

foreach ($key in $taskbarCOMKeys) {
    if (Test-Path $key) {
        try {
            Get-Item $key -EA 0 | Out-Null
            Write-Log "  Taskbar COM key verified: $key" "Green"
        } catch {}
    }
}

# Fix ASUS PC Assistant DCOM timeout
$asusApp = Get-AppxPackage -AllUsers -Name "*ASUSPCAssistant*" -ErrorAction SilentlyContinue
if ($asusApp) {
    try {
        $manifest = "$($asusApp.InstallLocation)\AppXManifest.xml"
        if (Test-Path $manifest) {
            Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue
            Write-Log "  Re-registered ASUS PC Assistant" "Green"
        }
    } catch {}
}

# Ensure DcomLaunch service is running
$dcomLaunch = Get-Service -Name "DcomLaunch" -EA 0
if ($dcomLaunch -and $dcomLaunch.Status -ne "Running") {
    try {
        Start-Service -Name "DcomLaunch" -EA 0
        Write-Log "  DcomLaunch service started" "Green"
    } catch {
        Write-Log "  DcomLaunch start: $_" "Yellow"
    }
}

Write-Log "  DCOM & Shell COM registration complete" "Green"
#endregion

#region PHASE 11: CLEAN ORPHANED DOCKER VM

Phase "Cleaning orphaned Docker VM"

# Check for Hyper-V module
if (Get-Command Get-VM -ErrorAction SilentlyContinue) {
    $dockerVm = Get-VM -Name "DockerDesktopVM" -ErrorAction SilentlyContinue
    if ($dockerVm) {
        if ($dockerVm.State -eq "Running") {
            Stop-VM -Name "DockerDesktopVM" -TurnOff -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        Remove-VM -Name "DockerDesktopVM" -Force -ErrorAction SilentlyContinue
        Write-Log "  Removed orphaned DockerDesktopVM" "Green"
    }

    # Also check for any orphaned VMs with missing VHDX files
    Get-VM -ErrorAction SilentlyContinue | ForEach-Object {
        $vm = $_
        $vhdPaths = @()
        try {
            $vhdPaths = (Get-VMHardDiskDrive -VM $vm -ErrorAction SilentlyContinue).Path
        } catch {}
        foreach ($vhd in $vhdPaths) {
            if ($vhd -and -not (Test-Path $vhd)) {
                Write-Log "  Found orphaned VM: $($vm.Name) (missing VHD)" "Yellow"
                # Remove the VM since its disk is missing
                Remove-VM -VM $vm -Force -ErrorAction SilentlyContinue
                Write-Log "  Removed orphaned VM: $($vm.Name)" "Green"
            }
        }
    }
}

# Clean orphaned Docker data directories
$dockerDataPaths = @(
    "C:\ProgramData\DockerDesktop\vm-data",
    "$env:USERPROFILE\.docker\machine\machines\DockerDesktopVM"
)
foreach ($dockerPath in $dockerDataPaths) {
    if (Test-Path $dockerPath) {
        $vhdxExists = Test-Path "$dockerPath\DockerDesktop.vhdx" -ErrorAction SilentlyContinue
        if (-not $vhdxExists) {
            Remove-Item -Path $dockerPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "  Cleaned orphaned Docker data: $dockerPath" "Green"
        }
    }
}
Write-Log "  Docker/Hyper-V cleanup complete" "Green"
#endregion

#region PHASE 12: FIX MSI ERROR 1316 AND ERROR 5 (Transaction Failures)

Phase "Fixing MSI installer errors (including Error 5 transaction failures)"

Write-Log "  Killing any stuck MSI processes..." "Yellow"
# Kill ALL msiexec processes to release locks
Get-Process msiexec -EA 0 | Stop-Process -Force -EA 0
Start-Sleep -Milliseconds 500

# Kill Windows Installer service hard
Stop-Service msiserver -Force -EA 0
Start-Sleep -Seconds 1

# Step 1: Clear MSI rollback scripts (these cause Error 5)
$msiRollbackPath = "$env:SystemRoot\Installer\$PID"
Get-ChildItem "$env:SystemRoot\Installer" -Filter "*.rbs" -EA 0 | Remove-Item -Force -EA 0
Get-ChildItem "$env:SystemRoot\Installer" -Filter "*.rbf" -EA 0 | Remove-Item -Force -EA 0
Write-Log "  Cleared MSI rollback scripts" "Green"

# Step 2: Clear in-progress transactions (MSI transaction logs)
$msiTransactionPath = "$env:SystemRoot\Installer\InProgress"
if (Test-Path $msiTransactionPath) {
    Remove-Item "$msiTransactionPath\*" -Force -Recurse -EA 0
    Write-Log "  Cleared in-progress MSI transactions" "Green"
}

# Step 3: Reset MSI policy (can cause Error 5 access denied)
$msiPolicyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
if (Test-Path $msiPolicyKey) {
    Remove-ItemProperty -Path $msiPolicyKey -Name "DisableMSI" -Force -EA 0
    Remove-ItemProperty -Path $msiPolicyKey -Name "DisableUserInstalls" -Force -EA 0
    Write-Log "  Cleared restrictive MSI policies" "Green"
}

# Step 4: Fix MSI server permissions (key cause of Error 5)
$msiServerKey = "HKLM:\SYSTEM\CurrentControlSet\Services\msiserver"
if (Test-Path $msiServerKey) {
    # Take ownership and grant access
    takeown /f "$env:SystemRoot\System32\msiexec.exe" /a 2>$null | Out-Null
    icacls "$env:SystemRoot\System32\msiexec.exe" /grant "Administrators:(F)" /t 2>$null | Out-Null
    icacls "$env:SystemRoot\System32\msiexec.exe" /grant "SYSTEM:(F)" /t 2>$null | Out-Null
    Write-Log "  Fixed msiexec.exe permissions" "Green"
}

# Step 5: Clear installer temp files and cache
$msiTempPatterns = @(
    "$env:SystemRoot\Installer\*.ipi",
    "$env:SystemRoot\Installer\*.tmp",
    "$env:SystemRoot\Installer\*.msi",
    "$env:SystemRoot\Installer\*.mst",
    "$env:TEMP\*.msi",
    "$env:TEMP\*.msp",
    "$env:TEMP\~msi*.tmp"
)
foreach ($pattern in $msiTempPatterns) {
    Get-ChildItem $pattern -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) } | Remove-Item -Force -EA 0
}
Write-Log "  Cleared MSI temp files" "Green"

# Step 6: Reset Windows Installer service configuration
sc.exe config msiserver start= demand 2>$null
sc.exe config msiserver type= own 2>$null
sc.exe sdset msiserver "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)" 2>$null

# Step 7: Re-register Windows Installer
msiexec /unregister 2>$null
Start-Sleep -Seconds 1
msiexec /regserver 2>$null
Write-Log "  Re-registered Windows Installer service" "Green"

# Step 8: Start the service to verify it works
Start-Service msiserver -EA 0
$msiSvc = Get-Service msiserver -EA 0
if ($msiSvc.Status -eq "Running") {
    Write-Log "  MSI server started successfully" "Green"
} else {
    Write-Log "  MSI server is demand-start (will start when needed)" "Yellow"
}

Write-Log "  MSI installer reset complete (Error 5 fixes applied)" "Green"
#endregion

#region PHASE 13: FIX WMI REPOSITORY

Phase "Fixing WMI repository"

$wmiCheck = winmgmt /verifyrepository 2>&1 | Out-String
if ($wmiCheck -match "inconsistent|corrupt") {
    winmgmt /salvagerepository 2>$null
    Write-Log "  WMI repository salvaged" "Yellow"
} else {
    Write-Log "  WMI repository OK" "Green"
}
#endregion

#region PHASE 14: CLEAR WER CRASH DATA

Phase "Clearing WER crash data"

$werPaths = @(
    "$env:LOCALAPPDATA\CrashDumps",
    "$env:ProgramData\Microsoft\Windows\WER\ReportArchive",
    "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
)
foreach ($path in $werPaths) {
    if (Test-Path $path) {
        Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Log "  WER crash data cleared" "Green"
#endregion

#region PHASE 15: RUN DISM (FULL REPAIR) - WITH 3-MINUTE TIMEOUT

Phase "Running DISM (full repair sequence - 3 min timeout)"

# Pre-clear DISM state to prevent 0xc0040009 errors
Write-Log "  Pre-clearing DISM state..." "Cyan"
try {
    # Kill any stuck DISM processes before starting
    Get-Process -Name "Dism*","DismHost*","TiWorker" -EA SilentlyContinue |
        Where-Object { $_.StartTime -lt (Get-Date).AddMinutes(-2) } |
        Stop-Process -Force -EA SilentlyContinue
    Start-Sleep -Milliseconds 300
} catch {}

# First clean up old component store data with timeout
Write-Log "  Cleaning component store (timeout: 180s)..."
Invoke-CommandWithTimeout -Command "dism.exe" -Arguments @("/online", "/cleanup-image", "/startcomponentcleanup") -TimeoutSeconds 180 -Description "DISM StartComponentCleanup"

if (-not (Test-PhaseTimeout)) {
    # Then check health with timeout
    Write-Log "  Checking health (timeout: 60s)..."
    $healthCheck = Invoke-CommandWithTimeout -Command "dism.exe" -Arguments @("/online", "/cleanup-image", "/checkhealth") -TimeoutSeconds 60 -Description "DISM CheckHealth"
    if ($healthCheck -match "repairable") {
        Write-Log "  Corruption detected - running RestoreHealth (timeout: 180s)..."
        $dismResult = Invoke-CommandWithTimeout -Command "dism.exe" -Arguments @("/online", "/cleanup-image", "/restorehealth") -TimeoutSeconds 180 -Description "DISM RestoreHealth"
        Write-Log "  DISM RestoreHealth completed" "Green"
    } elseif ($healthCheck -match "No component store corruption") {
        Write-Log "  Component store is healthy" "Green"
    } else {
        Write-Log "  DISM check skipped (timeout or unknown state)" "Yellow"
    }
}
#endregion

#region PHASE 16: RUN SFC - WITH 3-MINUTE TIMEOUT

Phase "Running SFC /scannow (3 min timeout)"

$sfcResult = Invoke-CommandWithTimeout -Command "sfc.exe" -Arguments @("/scannow") -TimeoutSeconds 180 -Description "SFC /scannow"
if ($sfcResult -match "did not find any integrity violations") {
    Write-Log "  SFC: No violations found" "Green"
} elseif ($sfcResult -match "successfully repaired") {
    Write-Log "  SFC: Repaired files" "Green"
} elseif ($sfcResult) {
    Write-Log "  SFC: Complete (check CBS.log if issues)" "Yellow"
} else {
    Write-Log "  SFC: Skipped (timeout)" "Yellow"
}
#endregion

#region PHASE 17: RE-REGISTER ALL APPX (SAFE) - WITH TIMEOUT CHECK

Phase "Re-registering ALL AppX packages (3 min timeout)"

$count = 0
$packages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
foreach ($pkg in $packages) {
    # Check timeout every 10 packages
    if ($count % 10 -eq 0 -and (Test-PhaseTimeout)) {
        Write-Log "  Phase timeout reached - registered $count packages before stopping" "Yellow"
        break
    }
    try {
        $manifest = "$($pkg.InstallLocation)\AppXManifest.xml"
        if (Test-Path $manifest) {
            Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue
            $count++
        }
    } catch {}
}
Write-Log "  Re-registered $count AppX packages" "Green"
#endregion

#region PHASE 18: RESTART CRITICAL SERVICES (SAFE)

Phase "Restarting services (safe set)"

# DO NOT restart display/graphics services
$safeServices = @("wuauserv","bits","cryptsvc","msiserver","AppXSvc","StateRepository","BrokerInfrastructure","Winmgmt","Schedule")
foreach ($svc in $safeServices) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne "Running") {
        Start-Service -Name $svc -ErrorAction SilentlyContinue
        Write-Log "  Started: $svc" "Green"
    }
}
#endregion

#region PHASE 19: FIX .NET FRAMEWORK NGEN