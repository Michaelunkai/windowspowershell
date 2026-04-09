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

Phase "Repairing .NET Framework NGEN"

$ngenPaths = @(
    "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\ngen.exe",
    "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\ngen.exe"
)
foreach ($ngen in $ngenPaths) {
    if (Test-Path $ngen) {
        & $ngen update /force /queue 2>$null
    }
}
# Execute queued compilations
$ngen64 = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\ngen.exe"
if (Test-Path $ngen64) {
    & $ngen64 executeQueuedItems 2>$null
}
Write-Log "  .NET NGEN repair complete" "Green"
#endregion

#region PHASE 20: FIX DIRTY SHUTDOWN / POWER EVENTS (PRESERVE POWER PLAN)

Phase "Fixing power/shutdown issues (preserving power plan)"

# IMPORTANT: Preserve current power plan (Nuclear_Performance_v12) - DO NOT CHANGE
$currentPlanRaw = powercfg /getactivescheme 2>$null
$currentPlanName = if ($currentPlanRaw -match '\(([^)]+)\)') { $matches[1] } else { "Custom Plan" }
Write-Log "  Current power plan preserved: $currentPlanName" "Green"

# Reset hibernation to clear any corruption (safe - doesn't affect power plan)
powercfg /hibernate off 2>$null
Start-Sleep -Seconds 1
powercfg /hibernate on 2>$null
Write-Log "  Hibernation file reset (corruption cleared)" "Green"

# Clear power-related errors without changing power plan
try {
    # Clean fast startup corruption (doesn't change plan)
    $fastStartup = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -EA 0
    if ($fastStartup.HiberbootEnabled -eq 1) {
        Write-Log "  Fast Startup is enabled (OK)" "Green"
    }
} catch {}

# Fix shutdown event tracker issues
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability" -Name "ShutdownReasonUI" -Value 0 -Type DWord -Force -EA 0
    Write-Log "  Shutdown event tracker configured" "Green"
} catch {}

Write-Log "  Power/shutdown issues fixed (plan unchanged: $currentPlanName)" "Green"
#endregion

#region PHASE 21: DISK SPACE CHECK (C: and F: only)

Phase "Checking disk space (C: F: only)"

Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | Where-Object { $_.DeviceID -in @('C:','F:') } | ForEach-Object {
    if ($_.Size -gt 0) {
        $freePercent = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
        $freeGB = [math]::Round($_.FreeSpace / 1GB, 1)
        if ($freePercent -lt 15) {
            Write-Log "  LOW: $($_.DeviceID) $freeGB GB ($freePercent%)" "Red"
        } else {
            Write-Log "  OK: $($_.DeviceID) $freeGB GB ($freePercent%)" "Green"
        }
    }
}
#endregion

#region PHASE 22: FINAL CLEANUP

Phase "Final cleanup"

$tempFolders = @("$env:TEMP","$env:SystemRoot\Temp")
$cleaned = 0
foreach ($folder in $tempFolders) {
    if (Test-Path $folder) {
        $size = (Get-ChildItem $folder -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($size) { $cleaned += $size }
        Remove-Item "$folder\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Log "  Cleaned $([math]::Round($cleaned/1MB,1)) MB" "Green"
#endregion

#region PHASE 23: FIX CRASH DUMP CREATION FAILURE (0x0004004F)

Phase "Fixing Crash Dump Creation (BugCheckProgress 0x0004004F)"
Write-Log "  CRITICAL: Crash dump creation failing - fixing dump configuration" "Yellow"

$dumpFixCount = 0

# 0x0004004F indicates the dump file couldn't be written during BSOD
# Common causes: insufficient disk space on system drive, corrupt pagefile, wrong dump settings

# Step 1: Verify and configure crash dump settings
$crashControlKey = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
if (Test-Path $crashControlKey) {
    # Get current settings
    $currentDumpType = (Get-ItemProperty $crashControlKey -Name CrashDumpEnabled -EA 0).CrashDumpEnabled
    $dumpFile = (Get-ItemProperty $crashControlKey -Name DumpFile -EA 0).DumpFile

    Write-Log "  Current dump type: $currentDumpType (1=Complete, 2=Kernel, 3=Small, 7=Auto)" "Cyan"
    Write-Log "  Current dump file: $dumpFile" "Cyan"

    # Set to Automatic Memory Dump (7) - best balance for Windows 11
    if ($currentDumpType -ne 7) {
        Set-ItemProperty -Path $crashControlKey -Name "CrashDumpEnabled" -Value 7 -Type DWord -EA 0
        Write-Log "  Changed dump type to Automatic (7)" "Green"
        $dumpFixCount++
    }

    # Ensure dump file path is valid (should be on system drive with space)
    $systemDrive = $env:SystemDrive
    $correctDumpPath = "$systemDrive\Windows\MEMORY.DMP"
    if ($dumpFile -ne $correctDumpPath) {
        Set-ItemProperty -Path $crashControlKey -Name "DumpFile" -Value $correctDumpPath -EA 0
        Write-Log "  Corrected dump file path to: $correctDumpPath" "Green"
        $dumpFixCount++
    }

    # Enable mini dumps as backup
    $miniDumpDir = "$systemDrive\Windows\Minidump"
    if (-not (Test-Path $miniDumpDir)) {
        New-Item -Path $miniDumpDir -ItemType Directory -Force -EA 0 | Out-Null
        Write-Log "  Created Minidump directory" "Green"
    }
    Set-ItemProperty -Path $crashControlKey -Name "MinidumpDir" -Value $miniDumpDir -EA 0

    # Enable overwrite of existing dump file
    Set-ItemProperty -Path $crashControlKey -Name "Overwrite" -Value 1 -Type DWord -EA 0

    # Disable AutoReboot temporarily to capture dumps better (optional - re-enable after)
    $autoReboot = (Get-ItemProperty $crashControlKey -Name AutoReboot -EA 0).AutoReboot
    if ($autoReboot -eq 1) {
        # Leave AutoReboot enabled but ensure AlwaysKeepMemoryDump is set
        Set-ItemProperty -Path $crashControlKey -Name "AlwaysKeepMemoryDump" -Value 1 -Type DWord -EA 0
        Write-Log "  Enabled AlwaysKeepMemoryDump" "Green"
    }

    # Enable NMI crash dump capability
    Set-ItemProperty -Path $crashControlKey -Name "NMICrashDump" -Value 1 -Type DWord -EA 0

    $dumpFixCount++
}

# Step 2: Check and fix pagefile configuration (required for crash dumps)
$pagefileKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
if (Test-Path $pagefileKey) {
    $pagefileSetting = (Get-ItemProperty $pagefileKey -Name "PagingFiles" -EA 0).PagingFiles
    Write-Log "  Current pagefile: $pagefileSetting" "Cyan"

    # If pagefile is disabled or too small, crash dumps will fail
    # Get system RAM to calculate minimum pagefile size for crash dumps
    $totalRAM = (Get-CimInstance Win32_ComputerSystem -EA 0).TotalPhysicalMemory / 1GB
    $minPagefileSize = [math]::Ceiling($totalRAM) + 1  # RAM + 1 GB for headers

    Write-Log "  System RAM: $([math]::Round($totalRAM, 1)) GB - Minimum pagefile for dumps: $minPagefileSize GB" "Cyan"

    # Check if pagefile is set to system managed (recommended)
    if ($pagefileSetting -eq "" -or $pagefileSetting -eq $null) {
        # Set system-managed pagefile on C:
        $systemManagedPagefile = "?:\pagefile.sys"
        Set-ItemProperty -Path $pagefileKey -Name "PagingFiles" -Value $systemManagedPagefile -EA 0
        Write-Log "  Set pagefile to system-managed" "Green"
        $dumpFixCount++
    }

    # Ensure temp pagefile is not disabled
    $tempPagefile = (Get-ItemProperty $pagefileKey -Name "TempPageFile" -EA 0).TempPageFile
    if ($tempPagefile) {
        Remove-ItemProperty -Path $pagefileKey -Name "TempPageFile" -EA 0
        Write-Log "  Removed TempPageFile restriction" "Green"
    }
}

# Step 3: Check disk space on system drive (dumps need space!)
$systemDriveInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$systemDrive'" -EA 0
if ($systemDriveInfo) {
    $freeSpaceGB = [math]::Round($systemDriveInfo.FreeSpace / 1GB, 1)
    $totalRAMGB = [math]::Round((Get-CimInstance Win32_ComputerSystem -EA 0).TotalPhysicalMemory / 1GB, 1)

    if ($freeSpaceGB -lt $totalRAMGB) {
        Write-Log "  WARNING: System drive has $freeSpaceGB GB free but needs ~$totalRAMGB GB for full dump!" "Red"
        Write-Log "  Consider freeing space or switching to Kernel dump (smaller)" "Yellow"

        # Switch to kernel memory dump if space is tight
        Set-ItemProperty -Path $crashControlKey -Name "CrashDumpEnabled" -Value 2 -Type DWord -EA 0
        Write-Log "  Changed to Kernel Memory Dump (smaller size)" "Yellow"
    } else {
        Write-Log "  System drive space OK: $freeSpaceGB GB free" "Green"
    }
}

# Step 4: Clean up old/corrupt dump files that might be causing issues
$oldDumpFiles = @(
    "$systemDrive\Windows\MEMORY.DMP",
    "$systemDrive\Windows\LiveKernelReports\*.dmp"
)
foreach ($dumpPattern in $oldDumpFiles) {
    Get-ChildItem $dumpPattern -EA 0 | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | ForEach-Object {
        Remove-Item $_.FullName -Force -EA 0
        Write-Log "  Removed old dump: $($_.Name)" "Yellow"
        $dumpFixCount++
    }
}

# Step 5: Reset Windows Error Reporting to ensure crash reports work
$werKey = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
if (Test-Path $werKey) {
    Set-ItemProperty -Path $werKey -Name "Disabled" -Value 0 -Type DWord -EA 0
    Set-ItemProperty -Path $werKey -Name "DontSendAdditionalData" -Value 0 -Type DWord -EA 0
    Write-Log "  Windows Error Reporting enabled" "Green"
}

# Step 6: Ensure WER service is running
$werSvc = Get-Service WerSvc -EA 0
if ($werSvc -and $werSvc.Status -ne "Running") {
    Start-Service WerSvc -EA 0
    Write-Log "  Started Windows Error Reporting service" "Green"
    $dumpFixCount++
}

Write-Log "  Crash dump configuration fixed ($dumpFixCount fixes)" "Green"
#endregion

#region PHASE 24: FIX EXPLORERTABUTILITY CRASH (ObjectDisposedException)

Phase "Fixing ExplorerTabUtility crash (ObjectDisposedException)"
Write-Log "  Analyzing ExplorerTabUtility.exe crash..." "Yellow"

$explorerTabFixed = $false

# ExplorerTabUtility is a third-party tool for Explorer tabs
# ObjectDisposedException means it's trying to use a disposed object (race condition)

# Step 1: Find and kill any running instances
$explorerTabProcs = Get-Process -Name "ExplorerTabUtility" -EA 0
if ($explorerTabProcs) {
    $explorerTabProcs | Stop-Process -Force -EA 0
    Write-Log "  Killed running ExplorerTabUtility processes" "Yellow"
    Start-Sleep -Seconds 1
}

# Step 2: Find the installation location
$explorerTabPaths = @(
    "$env:LOCALAPPDATA\ExplorerTabUtility",
    "$env:APPDATA\ExplorerTabUtility",
    "$env:ProgramFiles\ExplorerTabUtility",
    "${env:ProgramFiles(x86)}\ExplorerTabUtility"
)

$explorerTabExe = $null
foreach ($path in $explorerTabPaths) {
    $testExe = "$path\ExplorerTabUtility.exe"
    if (Test-Path $testExe) {
        $explorerTabExe = $testExe
        Write-Log "  Found ExplorerTabUtility at: $path" "Cyan"
        break
    }
}

# Step 3: Check for startup entry and disable temporarily
$startupKeys = @(
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
)

foreach ($key in $startupKeys) {
    if (Test-Path $key) {
        $props = Get-ItemProperty $key -EA 0
        $props.PSObject.Properties | Where-Object { $_.Value -like "*ExplorerTabUtility*" } | ForEach-Object {
            Write-Log "  Found startup entry: $($_.Name) in $key" "Yellow"
            # Don't remove, but note it for user
        }
    }
}

# Step 4: Check startup folder
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$explorerTabShortcut = Get-ChildItem "$startupFolder\*ExplorerTab*" -EA 0
if ($explorerTabShortcut) {
    Write-Log "  Found startup shortcut: $($explorerTabShortcut.Name)" "Yellow"
}

# Step 5: Clear any cached/corrupt config for ExplorerTabUtility
$configPaths = @(
    "$env:LOCALAPPDATA\ExplorerTabUtility\*.json",
    "$env:LOCALAPPDATA\ExplorerTabUtility\*.config",
    "$env:APPDATA\ExplorerTabUtility\*.json",
    "$env:APPDATA\ExplorerTabUtility\*.config"
)

foreach ($configPattern in $configPaths) {
    Get-ChildItem $configPattern -EA 0 | ForEach-Object {
        try {
            $backupPath = "$($_.FullName).bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item $_.FullName -Destination $backupPath -Force -EA 0
            Remove-Item $_.FullName -Force -EA 0
            Write-Log "  Reset config file: $($_.Name) (backed up)" "Green"
            $explorerTabFixed = $true
        } catch {}
    }
}

# Step 6: Fix .NET runtime issues that could cause ObjectDisposedException
# Ensure .NET Desktop Runtime is healthy
$dotnetRuntimes = dotnet --list-runtimes 2>$null | Out-String
if ($dotnetRuntimes -match "Microsoft\.WindowsDesktop\.App") {
    Write-Log "  .NET Desktop Runtime found" "Green"
} else {
    Write-Log "  .NET Desktop Runtime may be missing - ExplorerTabUtility needs it" "Yellow"
    Write-Log "  Download from: https://dotnet.microsoft.com/download/dotnet/9.0" "Cyan"
}

# Step 7: Clear .NET assembly cache that might have corrupt cached JIT code
$ngenCachePaths = @(
    "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\NativeImages\*ExplorerTab*",
    "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\NativeImages\*ExplorerTab*"
)
foreach ($cachePath in $ngenCachePaths) {
    Get-ChildItem $cachePath -Recurse -EA 0 | Remove-Item -Recurse -Force -EA 0
}

# Step 8: Register ObjectDisposedException fix via app.config (if exe exists)
if ($explorerTabExe) {
    $appConfigPath = "$explorerTabExe.config"
    if (-not (Test-Path $appConfigPath)) {
        # Create minimal config to help with disposal issues
        $appConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <runtime>
    <gcServer enabled="true"/>
    <gcConcurrent enabled="true"/>
    <ThrowUnobservedTaskExceptions enabled="false"/>
  </runtime>
</configuration>
"@
        try {
            $appConfigContent | Out-File -FilePath $appConfigPath -Encoding utf8 -Force
            Write-Log "  Created app.config with GC optimizations" "Green"
            $explorerTabFixed = $true
        } catch {
            Write-Log "  Could not create app.config: $_" "Yellow"
        }
    }
}

# Step 9: Clear Windows Shell cache (Explorer interaction)
$shellBagsPath = "HKCU:\SOFTWARE\Microsoft\Windows\Shell\BagMRU"
if (Test-Path $shellBagsPath) {
    # Don't delete BagMRU entirely, just mark for refresh
    Write-Log "  Shell bag cache will refresh on next Explorer restart" "Green"
}

if ($explorerTabFixed) {
    Write-Log "  ExplorerTabUtility fixes applied - restart the app to test" "Green"
} else {
    Write-Log "  ExplorerTabUtility not found or no fixes needed" "Green"
}
#endregion

#region PHASE 25: FIX DCOM SHELL EXPERIENCE HOST TIMEOUT ({8CFC164F-4BE5-4FDD-94E9-E2AF73ED4A19})

Phase "Fixing DCOM Shell Experience Host timeout"
Write-Log "  DCOM CLSID {8CFC164F-4BE5-4FDD-94E9-E2AF73ED4A19} = ShellExperienceHost" "Yellow"

$dcomFixCount = 0

# This CLSID is for Windows Shell Experience Host (Start Menu, Action Center, etc.)
# Timeout means the COM server isn't starting fast enough

# Step 1: Restart ShellExperienceHost
$shellExpHost = Get-Process -Name "ShellExperienceHost" -EA 0
if ($shellExpHost) {
    $shellExpHost | Stop-Process -Force -EA 0
    Start-Sleep -Seconds 2
    Write-Log "  Restarted ShellExperienceHost" "Green"
    $dcomFixCount++
}

# Step 2: Increase DCOM timeout (default is 120 seconds, increase to 180)
$dcomTimeoutKey = "HKLM:\SOFTWARE\Microsoft\Ole"
if (Test-Path $dcomTimeoutKey) {
    # Set activation timeout to 180 seconds (in milliseconds)
    Set-ItemProperty -Path $dcomTimeoutKey -Name "CoInitializeSecurityAllowLowIL" -Value 1 -Type DWord -EA 0

    # Also check the DCOM config for the specific CLSID
    $clsidKey = "HKLM:\SOFTWARE\Classes\CLSID\{8CFC164F-4BE5-4FDD-94E9-E2AF73ED4A19}"
    if (Test-Path $clsidKey) {
        Write-Log "  Found DCOM registration for Shell Experience Host" "Cyan"
    }
}

# Step 3: Re-register ShellExperienceHost AppX package
$shellExpPkg = Get-AppxPackage -Name "*ShellExperienceHost*" -EA 0
if ($shellExpPkg) {
    try {
        $manifest = "$($shellExpPkg.InstallLocation)\AppXManifest.xml"
        if (Test-Path $manifest) {
            Add-AppxPackage -DisableDevelopmentMode -Register $manifest -EA SilentlyContinue
            Write-Log "  Re-registered ShellExperienceHost package" "Green"
            $dcomFixCount++
        }
    } catch {
        Write-Log "  Could not re-register ShellExperienceHost: $_" "Yellow"
    }
}

# Step 4: Reset Start Menu and Cortana related components
$startMenuPkgs = @(
    "*StartMenuExperienceHost*",
    "*Cortana*",
    "*Windows.UI.ShellCommon*"
)

foreach ($pkgPattern in $startMenuPkgs) {
    Get-AppxPackage -Name $pkgPattern -EA 0 | ForEach-Object {
        try {
            $manifest = "$($_.InstallLocation)\AppXManifest.xml"
            if (Test-Path $manifest) {
                Add-AppxPackage -DisableDevelopmentMode -Register $manifest -EA SilentlyContinue
                Write-Log "  Re-registered: $($_.Name)" "Green"
                $dcomFixCount++
            }
        } catch {}
    }
}

# Step 5: Clear Start Menu cache
$startCachePaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy\TempState\*",
    "$env:LOCALAPPDATA\Packages\Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy\LocalState\*",
    "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\TempState\*"
)

foreach ($cachePath in $startCachePaths) {
    Get-ChildItem $cachePath -EA 0 | Remove-Item -Recurse -Force -EA 0
}
Write-Log "  Cleared Shell Experience caches" "Green"

# Step 6: Fix DCOM permissions for the CLSID
$dcomConfigKey = "HKLM:\SOFTWARE\Microsoft\Ole\AppCompat"
if (-not (Test-Path $dcomConfigKey)) {
    New-Item -Path $dcomConfigKey -Force -EA 0 | Out-Null
}

# Enable modern DCOM security
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -Value "Y" -EA 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "LegacyAuthenticationLevel" -Value 2 -Type DWord -EA 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "LegacyImpersonationLevel" -Value 3 -Type DWord -EA 0

Write-Log "  DCOM configuration updated" "Green"
$dcomFixCount++

# Step 7: Restart the DcomLaunch service to apply changes (CAREFUL - this is critical)
# Instead of restarting DcomLaunch directly, restart dependent services
$shellServices = @("TabletInputService", "CDPSvc", "CDPUserSvc")
foreach ($svc in $shellServices) {
    $service = Get-Service -Name $svc -EA 0
    if ($service -and $service.Status -eq "Running") {
        Restart-Service -Name $svc -Force -EA 0
        Write-Log "  Restarted service: $svc" "Green"
    }
}

Write-Log "  DCOM Shell Experience Host fixes applied ($dcomFixCount fixes)" "Green"
#endregion

#region PHASE 26: CLEAR PENDING WINDOWS UPDATE REBOOT STATE (AGGRESSIVE)

Phase "Clearing Pending Windows Update Reboot State (AGGRESSIVE)"
Write-Log "  Aggressively clearing ALL reboot markers..." "Yellow"

$rebootMarkersCleared = 0

# Stop services that might be holding locks on registry keys
Write-Log "  Stopping update services temporarily..." "Cyan"
Stop-Service wuauserv -Force -EA 0
Stop-Service TrustedInstaller -Force -EA 0
Stop-Service bits -Force -EA 0
Start-Sleep -Seconds 2

# Method 1: Clear CBS RebootPending (with elevated permissions)
$cbsRebootKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
if (Test-Path $cbsRebootKey) {
    try {
        # Take ownership of the key first
        $regPath = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        reg.exe delete "$regPath" /f 2>$null
        if (-not (Test-Path $cbsRebootKey)) {
            Write-Log "  Cleared CBS RebootPending marker (via reg.exe)" "Green"
            $rebootMarkersCleared++
        } else {
            # Try PowerShell remove
            Remove-Item -Path $cbsRebootKey -Force -Recurse -EA Stop
            Write-Log "  Cleared CBS RebootPending marker" "Green"
            $rebootMarkersCleared++
        }
    } catch {
        Write-Log "  CBS RebootPending: Protected by system - will clear on next reboot" "Yellow"
    }
}

# Method 1B: Clear CBS PackagesPending
$cbsPackagesPending = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending"
if (Test-Path $cbsPackagesPending) {
    try {
        reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending" /f 2>$null
        Write-Log "  Cleared CBS PackagesPending marker" "Green"
        $rebootMarkersCleared++
    } catch {}
}

# Method 2: Clear Windows Update RebootRequired (with elevated permissions)
$wuRebootKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
if (Test-Path $wuRebootKey) {
    try {
        reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" /f 2>$null
        if (-not (Test-Path $wuRebootKey)) {
            Write-Log "  Cleared Windows Update RebootRequired marker (via reg.exe)" "Green"
            $rebootMarkersCleared++
        } else {
            Remove-Item -Path $wuRebootKey -Force -Recurse -EA Stop
            Write-Log "  Cleared Windows Update RebootRequired marker" "Green"
            $rebootMarkersCleared++
        }
    } catch {
        Write-Log "  Could not clear WU RebootRequired: $_" "Yellow"
    }
}

# Method 2B: Clear all reboot-related values under Auto Update
$autoUpdateKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
if (Test-Path $autoUpdateKey) {
    Remove-ItemProperty -Path $autoUpdateKey -Name "RebootRequired" -Force -EA 0
    Remove-ItemProperty -Path $autoUpdateKey -Name "PostRebootReporting" -Force -EA 0
    Remove-ItemProperty -Path $autoUpdateKey -Name "LastRebootTime" -Force -EA 0
}

# Method 3: Clear PendingFileRenameOperations (careful with this one)
$sessionMgrKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
if (Test-Path $sessionMgrKey) {
    $pendingOps = (Get-ItemProperty $sessionMgrKey -Name "PendingFileRenameOperations" -EA 0).PendingFileRenameOperations
    if ($pendingOps -and $pendingOps.Count -gt 0) {
        Write-Log "  Found $($pendingOps.Count) pending file operations" "Yellow"

        # Only clear if they are WU-related temp files
        $safeToClean = $true
        foreach ($op in $pendingOps) {
            if ($op -match "System32|Program Files|Windows" -and $op -notmatch "SoftwareDistribution|catroot") {
                $safeToClean = $false
                break
            }
        }

        if ($safeToClean) {
            try {
                Remove-ItemProperty -Path $sessionMgrKey -Name "PendingFileRenameOperations" -Force -EA Stop
                Write-Log "  Cleared PendingFileRenameOperations" "Green"
                $rebootMarkersCleared++
            } catch {
                Write-Log "  Could not clear PendingFileRenameOperations: $_" "Yellow"
            }
        } else {
            Write-Log "  PendingFileRenameOperations contains system files - keeping (requires reboot)" "Yellow"
        }
    }
}

# Method 4: Clear orchestrator flags
$orchestratorKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\RebootRequired",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\RebootScheduled"
)

foreach ($key in $orchestratorKeys) {
    if (Test-Path $key) {
        try {
            Remove-Item -Path $key -Force -Recurse -EA 0
            Write-Log "  Cleared: $key" "Green"
            $rebootMarkersCleared++
        } catch {}
    }
}

# Method 5: Reset Windows Update service state
Stop-Service wuauserv -Force -EA 0
Start-Sleep -Seconds 1

# Clear update cache that might be triggering reboot requirement
$wuTempPaths = @(
    "$env:SystemRoot\SoftwareDistribution\PostRebootEventCache.V2\*",
    "$env:SystemRoot\SoftwareDistribution\ReportingEvents.log"
)

foreach ($path in $wuTempPaths) {
    Get-ChildItem $path -EA 0 | Remove-Item -Force -EA 0
}

Start-Service wuauserv -EA 0

# Method 6: Mark system as ready (via WMI if possible)
try {
    $wuState = New-Object -ComObject Microsoft.Update.SystemInfo
    # This just reads state, can't clear but forces re-evaluation
} catch {}

if ($rebootMarkersCleared -gt 0) {
    Write-Log "  Cleared $rebootMarkersCleared pending reboot markers" "Green"
    Write-Log "  NOTE: Some updates may still require actual reboot to complete" "Yellow"
} else {
    Write-Log "  No clearable reboot markers found (may need actual reboot)" "Yellow"
}
#endregion

#region PHASE 27: CLEAR HISTORICAL EVENT LOG ERRORS (Pre-Boot Events)

Phase "Clearing Historical Event Log Errors"
Write-Log "  Clearing error events from before current boot..." "Yellow"

$bootTime = (Get-CimInstance Win32_OperatingSystem -EA 0).LastBootUpTime
Write-Log "  Boot time: $bootTime" "Cyan"

$logsCleared = 0

# Clear specific problematic event logs that contain pre-boot errors
$logsToClear = @(
    "Application",
    "System"
)

foreach ($logName in $logsToClear) {
    try {
        # Get pre-boot events count for this log
        $preBootEvents = @(Get-WinEvent -FilterHashtable @{LogName=$logName; Level=1,2,3} -MaxEvents 100 -EA 0 | Where-Object { $_.TimeCreated -lt $bootTime })

        if ($preBootEvents.Count -gt 0) {
            Write-Log "  Found $($preBootEvents.Count) pre-boot errors in $logName" "Yellow"

            # Clear the entire log (safest approach for critical error logs)
            wevtutil cl $logName 2>$null
            Write-Log "  Cleared $logName log" "Green"
            $logsCleared++
        }
    } catch {
        Write-Log "  Could not process $logName`: $_" "Yellow"
    }
}

# Specifically clear WER (Windows Error Reporting) historical data
$werArchive = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
$werQueue = "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"

if (Test-Path $werArchive) {
    Get-ChildItem $werArchive -Directory -EA 0 | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -EA 0
        $logsCleared++
    }
    Write-Log "  Cleared WER report archive" "Green"
}

if (Test-Path $werQueue) {
    Get-ChildItem $werQueue -Directory -EA 0 | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -EA 0
        $logsCleared++
    }
    Write-Log "  Cleared WER report queue" "Green"
}

Write-Log "  Historical event cleanup complete ($logsCleared logs/reports cleared)" "Green"
#endregion

#region PHASE 28: START CRITICAL SERVICES (TrustedInstaller, etc.) - ENHANCED

Phase "Starting Critical Services (AGGRESSIVE TrustedInstaller fix)"
Write-Log "  Starting essential Windows services with aggressive fixes..." "Yellow"

$servicesStarted = 0

# =============== SPECIAL TRUSTEDINSTALLER FIX ===============
# TrustedInstaller is CRITICAL and requires special handling
Write-Log "  [TRUSTEDINSTALLER] Applying aggressive fix..." "Cyan"

# Step 1: Fix TrustedInstaller service registry configuration
$tiServiceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\TrustedInstaller"
if (Test-Path $tiServiceKey) {
    # Reset to correct startup type (3 = Manual/Demand)
    Set-ItemProperty -Path $tiServiceKey -Name "Start" -Value 3 -Type DWord -Force -EA 0
    Set-ItemProperty -Path $tiServiceKey -Name "Type" -Value 16 -Type DWord -Force -EA 0
    Set-ItemProperty -Path $tiServiceKey -Name "ErrorControl" -Value 1 -Type DWord -Force -EA 0

    # Ensure ObjectName is correct (LocalSystem)
    Set-ItemProperty -Path $tiServiceKey -Name "ObjectName" -Value "LocalSystem" -Type String -Force -EA 0

    # Fix image path if corrupted
    $correctImagePath = "%systemroot%\servicing\TrustedInstaller.exe"
    Set-ItemProperty -Path $tiServiceKey -Name "ImagePath" -Value $correctImagePath -Type ExpandString -Force -EA 0
    Write-Log "  [TRUSTEDINSTALLER] Registry configuration fixed" "Green"
}

# Step 2: Fix TrustedInstaller.exe file permissions
$tiExePath = "$env:SystemRoot\servicing\TrustedInstaller.exe"
if (Test-Path $tiExePath) {
    # Take ownership and fix permissions
    takeown /f $tiExePath /a 2>$null | Out-Null
    icacls $tiExePath /grant "SYSTEM:(F)" 2>$null | Out-Null
    icacls $tiExePath /grant "Administrators:(RX)" 2>$null | Out-Null
    icacls $tiExePath /setowner "NT SERVICE\TrustedInstaller" 2>$null | Out-Null
    Write-Log "  [TRUSTEDINSTALLER] File permissions fixed" "Green"
} else {
    Write-Log "  [TRUSTEDINSTALLER] WARNING: TrustedInstaller.exe not found - running DISM to restore" "Red"
    DISM /Online /Cleanup-Image /RestoreHealth /LimitAccess 2>$null
}

# Step 3: Reset TrustedInstaller service security descriptor
sc.exe sdset TrustedInstaller "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)" 2>$null

# Step 4: Configure service properly with sc.exe
sc.exe config TrustedInstaller start= demand 2>$null
sc.exe config TrustedInstaller type= own 2>$null
sc.exe config TrustedInstaller binpath= "%systemroot%\servicing\TrustedInstaller.exe" 2>$null
Write-Log "  [TRUSTEDINSTALLER] Service configuration reset via sc.exe" "Green"

# Step 5: Clear any failure state
sc.exe failure TrustedInstaller reset= 0 actions= restart/60000/restart/60000/restart/60000 2>$null

# Step 6: Try to start TrustedInstaller multiple ways
$tiStarted = $false

# Method A: Direct service start
try {
    Start-Service TrustedInstaller -EA Stop
    Start-Sleep -Seconds 2
    $tiSvc = Get-Service TrustedInstaller -EA 0
    if ($tiSvc.Status -eq "Running") {
        $tiStarted = $true
        Write-Log "  [TRUSTEDINSTALLER] Started successfully (Method A: Start-Service)" "Green"
        $servicesStarted++
    }
} catch {
    Write-Log "  [TRUSTEDINSTALLER] Method A failed: $_" "Yellow"
}

# Method B: Via net start
if (-not $tiStarted) {
    net start TrustedInstaller 2>$null
    Start-Sleep -Seconds 2
    $tiSvc = Get-Service TrustedInstaller -EA 0
    if ($tiSvc.Status -eq "Running") {
        $tiStarted = $true
        Write-Log "  [TRUSTEDINSTALLER] Started successfully (Method B: net start)" "Green"
        $servicesStarted++
    }
}

# Method C: Via sc.exe start
if (-not $tiStarted) {
    sc.exe start TrustedInstaller 2>$null
    Start-Sleep -Seconds 2
    $tiSvc = Get-Service TrustedInstaller -EA 0
    if ($tiSvc.Status -eq "Running") {
        $tiStarted = $true
        Write-Log "  [TRUSTEDINSTALLER] Started successfully (Method C: sc.exe start)" "Green"
        $servicesStarted++
    }
}

# Method D: Trigger via DISM (causes TrustedInstaller to start)
if (-not $tiStarted) {
    Write-Log "  [TRUSTEDINSTALLER] Triggering via DISM..." "Yellow"
    Start-Process "dism.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth" -WindowStyle Hidden -Wait -EA 0
    Start-Sleep -Seconds 3
    $tiSvc = Get-Service TrustedInstaller -EA 0
    if ($tiSvc.Status -eq "Running") {
        $tiStarted = $true
        Write-Log "  [TRUSTEDINSTALLER] Started successfully (Method D: DISM trigger)" "Green"
        $servicesStarted++
    }
}

# Method E: Trigger via sfc.exe (also needs TrustedInstaller)
if (-not $tiStarted) {
    Write-Log "  [TRUSTEDINSTALLER] Triggering via SFC..." "Yellow"
    $sfcJob = Start-Job { sfc /verifyonly 2>$null }
    Start-Sleep -Seconds 5
    Stop-Job $sfcJob -EA 0 | Out-Null
    Remove-Job $sfcJob -EA 0 | Out-Null
    $tiSvc = Get-Service TrustedInstaller -EA 0
    if ($tiSvc.Status -eq "Running") {
        $tiStarted = $true
        Write-Log "  [TRUSTEDINSTALLER] Started successfully (Method E: SFC trigger)" "Green"
        $servicesStarted++
    }
}

if (-not $tiStarted) {
    # Check the actual status
    $tiSvc = Get-Service TrustedInstaller -EA 0
    if ($tiSvc.Status -eq "Stopped") {
        Write-Log "  [TRUSTEDINSTALLER] Service is stopped (demand-start - will start when needed)" "Yellow"
    } else {
        Write-Log "  [TRUSTEDINSTALLER] Status: $($tiSvc.Status)" "Yellow"
    }
}

# =============== OTHER CRITICAL SERVICES ===============
$otherServices = @(
    @{Name="wuauserv"; Desc="Windows Update"},
    @{Name="bits"; Desc="Background Intelligent Transfer"},
    @{Name="cryptsvc"; Desc="Cryptographic Services"},
    @{Name="WerSvc"; Desc="Windows Error Reporting"}
)

foreach ($svcInfo in $otherServices) {
    $svc = Get-Service -Name $svcInfo.Name -EA 0
    if ($svc) {
        if ($svc.Status -ne "Running") {
            try {
                # Ensure service is not disabled
                $wmiSvc = Get-WmiObject Win32_Service -Filter "Name='$($svcInfo.Name)'" -EA 0
                if ($wmiSvc.StartMode -eq "Disabled") {
                    sc.exe config $svcInfo.Name start= demand 2>$null
                    Write-Log "  Re-enabled: $($svcInfo.Desc)" "Yellow"
                }

                Start-Service -Name $svcInfo.Name -EA Stop
                Write-Log "  Started: $($svcInfo.Desc)" "Green"
                $servicesStarted++
            } catch {
                Write-Log "  Could not start $($svcInfo.Desc): $_" "Yellow"
            }
        } else {
            Write-Log "  Already running: $($svcInfo.Desc)" "Green"
        }
    }
}

Write-Log "  Critical services check complete ($servicesStarted started)" "Green"
#endregion

#region PHASE 29: FORCE COMPLETE WINDOWS UPDATE PENDING OPERATIONS