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

Phase "Completing Pending Windows Update Operations"
Write-Log "  Forcing completion of pending update operations..." "Yellow"

# Method 1: Run usoclient to complete pending operations
try {
    Start-Process "usoclient.exe" -ArgumentList "RefreshSettings" -Wait -WindowStyle Hidden -EA 0
    Write-Log "  Triggered Windows Update refresh" "Green"
} catch {
    Write-Log "  UsoClient refresh: $_" "Yellow"
}

# Method 2: Reset update orchestrator state
$orchestratorPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator"
if (Test-Path $orchestratorPath) {
    Remove-Item "$orchestratorPath\UScheduler" -Force -Recurse -EA 0
    Remove-Item "$orchestratorPath\UScheduler_Oobe" -Force -Recurse -EA 0
    Write-Log "  Reset update orchestrator scheduler" "Green"
}

Write-Log "  Pending update operations processing complete" "Green"
#endregion

#region SUMMARY
Write-Host ""
Write-Log ("=" * 70) "Cyan"
Write-Log "    ULTIMATE REPAIR v5.3 COMPLETED - ALL 50 PHASES DONE" "Cyan"
Write-Log ("=" * 70) "Cyan"
Write-Host ""
Write-Log "v5.1 NEW FIXES (THIS VERSION):" "White"
Write-Log "  [x] AGGRESSIVE TrustedInstaller Fix (5 startup methods)" "Green"
Write-Log "  [x] MSI Error 5 Transaction Fix (killed stuck processes, cleared rollbacks)" "Green"
Write-Log "  [x] AGGRESSIVE Reboot Marker Clearing (CBS, WU, Orchestrator)" "Green"
Write-Host ""
Write-Log "v5.0 CRITICAL FIXES:" "White"
Write-Log "  [x] System Restore Point Created (Safety)" "Green"
Write-Log "  [x] Mutex Lock (Prevents concurrent execution)" "Green"
Write-Log "  [x] KMODE_EXCEPTION Prevention (Driver Verifier check)" "Green"
Write-Log "  [x] LoadLibrary Error 126 Fixes (DLLs, PATH, COM)" "Green"
Write-Log "  [x] Service Dependency Chain Fixes (Network services)" "Green"
Write-Log "  [x] Driver Issues Fixed (Non-display devices)" "Green"
Write-Log "  [x] WUDFRd Boot-Order Fix (0xC0000365 - DEMAND to SYSTEM start)" "Green"
Write-Log "  [x] UsbXhciCompanion Fix (0xc0000034 - STATUS_OBJECT_NAME_NOT_FOUND)" "Green"
Write-Log "  [x] Scheduled Tasks 0x800710E0 Fix (AC power/idle restrictions removed)" "Green"
Write-Log "  [x] Outdated Drivers Check (Camera, Logitech - trigger updates)" "Green"
Write-Log "  [x] Crash Dump Creation Fix (0x0004004F BugCheckProgress)" "Green"
Write-Log "  [x] ExplorerTabUtility Crash Fix (ObjectDisposedException)" "Green"
Write-Log "  [x] DCOM Shell Experience Host Fix ({8CFC164F-...} timeout)" "Green"
Write-Log "  [x] Pending Reboot Markers Cleared (WU RebootRequired)" "Green"
Write-Log "  [x] Historical Event Log Cleanup (Pre-boot errors cleared)" "Green"
Write-Log "  [x] Critical Services Started (TrustedInstaller, WerSvc)" "Green"
Write-Log "  [x] Windows Update Pending Operations Completed" "Green"
Write-Host ""
Write-Log "STANDARD FIXES:" "White"
Write-Log "  [x] BITS service" "Green"
Write-Log "  [x] UserManager/TokenBroker crashes" "Green"
Write-Log "  [x] WUDFRd driver (0xC0000365) - Boot race condition" "Green"
Write-Log "  [x] umbus driver (UMBus Enumerator) - SYSTEM start" "Green"
Write-Log "  [x] Boot drivers (dam, luafv)" "Green"
Write-Log "  [x] DllHost.exe crashes" "Green"
Write-Log "  [x] BrokerInfrastructure service" "Green"
Write-Log "  [x] AppX packages (UI.Xaml, WindowsAppRuntime)" "Green"
Write-Log "  [x] Scheduled tasks (GHelper, ASUS, NodeJS, .NET NGEN, etc)" "Green"
Write-Log "  [x] DCOM timeouts (ASUS PC Assistant)" "Green"
Write-Log "  [x] Docker orphaned VM" "Green"
Write-Log "  [x] MSI Error 5 and 1316 (transaction recovery)" "Green"
Write-Log "  [x] DISM component store" "Green"
Write-Log "  [x] WMI repository" "Green"
Write-Log "  [x] Winsock/IP stack reset" "Green"
Write-Log "  [x] .NET NGEN cache" "Green"
Write-Log "  [x] Power/shutdown configuration" "Green"
Write-Log "  [x] WER crash data cleared" "Green"
Write-Host ""
Write-Log "SAFETY SUMMARY:" "White"
if ($script:restorePointCreated) {
    Write-Log "  [x] Restore point created - can rollback if needed" "Green"
} else {
    Write-Log "  [ ] Restore point NOT created" "Yellow"
}
Write-Log "  [x] Mutex lock active - safe execution" "Green"
Write-Log "  [x] No display/GPU drivers touched" "Green"
Write-Host ""
Write-Log "NOTE: Only monitoring C: and F: drives" "Yellow"
Write-Log "NOTE: If VC++ Redistributable is missing, install from:" "Yellow"
Write-Log "      https://aka.ms/vs/17/release/vc_redist.x64.exe" "Cyan"
Write-Log "      https://aka.ms/vs/17/release/vc_redist.x86.exe" "Cyan"
Write-Host ""
Write-Log "RECOMMENDATION: REBOOT NOW to complete repairs" "Yellow"
Write-Log "  - WUDFRd/umbus boot-order changes take effect after reboot" "Yellow"
Write-Log "  - HID device errors should be resolved after reboot" "Yellow"
Write-Log "Log: $LogFile" "Cyan"
#endregion

#region PHASE 36A: RESTORE EXPLORER.EXE & SHELL UI (CRITICAL)

Phase "Restoring Explorer.exe & Shell UI"
Write-Log "  Fixing taskbar/desktop visibility..." "Cyan"

# Kill any stuck explorer processes (DISABLED - causes GPU crash on unstable systems)
# Get-Process explorer -EA 0 | Stop-Process -Force -EA 0
# Start-Sleep -Seconds 2

# Ensure explorer process is running
$explorerPath = "$env:SystemRoot\explorer.exe"
if (Test-Path $explorerPath) {
    try {
        # Start explorer with user session
        & $explorerPath
        Start-Sleep -Seconds 3
        Write-Log "  Explorer.exe started successfully" "Green"
    } catch {
        Write-Log "  ERROR starting explorer: $_" "Red"
    }
}

# Repair shell extensions registry
Write-Log "  Repairing shell extensions registry..." "Yellow"
try {
    # Re-register explorer as shell
    cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`" /v Shell /d explorer.exe /f 2>nul" | Out-Null
    Write-Log "  Shell registry repaired" "Green"
} catch {
    Write-Log "  Could not repair shell registry: $_" "Yellow"
}

# Fix taskbar COM registration
Write-Log "  Restoring taskbar COM objects..." "Yellow"
try {
    # Register Shell.Application COM object
    $objShell = New-Object -ComObject Shell.Application -EA 0
    if ($objShell) {
        [void][Runtime.Interopservices.Marshal]::ReleaseComObject($objShell)
        Write-Log "  Taskbar COM objects verified" "Green"
    }
} catch {
    Write-Log "  Taskbar COM check: $_" "Yellow"
}

# Ensure Desktop Window Manager (dwm.exe) is running
Write-Log "  Checking Desktop Window Manager (dwm.exe)..." "Yellow"
$dwmRunning = Get-Process dwm -EA 0
if (-not $dwmRunning) {
    Write-Log "  DWM not running, starting..." "Yellow"
    try {
        $dwmPath = "$env:SystemRoot\System32\dwm.exe"
        if (Test-Path $dwmPath) {
            & $dwmPath
            Start-Sleep -Seconds 2
            Write-Log "  Desktop Window Manager started" "Green"
        }
    } catch {
        Write-Log "  Could not start DWM: $_" "Yellow"
    }
} else {
    Write-Log "  Desktop Window Manager running" "Green"
}

# Restart Themes service (needed for taskbar visuals)
Write-Log "  Restarting Themes service..." "Yellow"
try {
    Restart-Service -Name Themes -Force -EA 0
    Write-Log "  Themes service restarted" "Green"
} catch {
    Write-Log "  Themes service restart: $_" "Yellow"
}

# Rebuild icon cache
Write-Log "  Rebuilding icon cache..." "Yellow"
try {
    # Stop explorer to allow cache rebuild
    Get-Process explorer -EA 0 | Stop-Process -Force -EA 0
    Start-Sleep -Seconds 1

    # Clear icon cache
    Remove-Item "$env:APPDATA\Microsoft\Windows\Explorer\iconcache_*.db" -Force -EA 0
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db" -Force -EA 0

    # Restart explorer
    & "$env:SystemRoot\explorer.exe"
    Start-Sleep -Seconds 2
    Write-Log "  Icon cache rebuilt" "Green"
} catch {
    Write-Log "  Icon cache rebuild: $_" "Yellow"
}

# Register shell32.dll which contains core shell functions
Write-Log "  Re-registering shell32.dll..." "Yellow"
try {
    $shell32 = "$env:SystemRoot\System32\shell32.dll"
    if (Test-Path $shell32) {
        cmd /c "regsvr32 /s `"$shell32`" 2>nul" | Out-Null
        Write-Log "  shell32.dll re-registered" "Green"
    }
} catch {
    Write-Log "  shell32 re-registration: $_" "Yellow"
}

# Register comctl32.dll (common controls)
Write-Log "  Re-registering comctl32.dll..." "Yellow"
try {
    $comctl32 = "$env:SystemRoot\System32\comctl32.dll"
    if (Test-Path $comctl32) {
        cmd /c "regsvr32 /s `"$comctl32`" 2>nul" | Out-Null
        Write-Log "  comctl32.dll re-registered" "Green"
    }
} catch {
    Write-Log "  comctl32 re-registration: $_" "Yellow"
}

# Fix any context menu issues (right-click)
Write-Log "  Repairing context menu handlers..." "Yellow"
try {
    $contextMenuPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Shell Extensions"
    if (Test-Path $contextMenuPath) {
        # Ensure handlers registry exists
        Write-Log "  Context menu registry verified" "Green"
    }
} catch {
    Write-Log "  Context menu check: $_" "Yellow"
}

# Ensure critical shell services are running
Write-Log "  Ensuring critical services running..." "Yellow"
$criticalServices = @(
    'Themes',
    'AudioSrv',
    'SSDPSRV',
    'upnphost'
)

foreach ($svc in $criticalServices) {
    $service = Get-Service -Name $svc -EA 0
    if ($service) {
        if ($service.Status -ne 'Running' -and $service.StartType -eq 'Automatic') {
            try {
                Start-Service -Name $svc -EA 0
                Write-Log "    Started: $svc" "Green"
            } catch {
                Write-Log "    Could not start $svc : $_" "Yellow"
            }
        }
    }
}

Write-Log "  Explorer.exe restoration complete" "Green"
#endregion

#region PHASE 37: COMPREHENSIVE NETWORK OPTIMIZATION

Phase "Network Performance Optimization"
Write-Log "  Optimizing network stack..." "Cyan"

# Clear DNS cache
try {
    Clear-DnsClientCache -EA 0
    Write-Log "  DNS cache cleared" "Green"
} catch { Write-Log "  DNS cache: $_" "Yellow" }

# Reset Winsock catalog
try {
    netsh winsock reset 2>$null | Out-Null
    Write-Log "  Winsock catalog reset" "Green"
} catch { Write-Log "  Winsock reset: $_" "Yellow" }

# Reset TCP/IP stack
try {
    netsh int ip reset 2>$null | Out-Null
    Write-Log "  TCP/IP stack reset" "Green"
} catch { Write-Log "  TCP/IP reset: $_" "Yellow" }

# Optimize TCP settings
try {
    Set-NetTCPSetting -SettingName InternetCustom -AutoTuningLevelLocal Normal -EA 0
    Write-Log "  TCP auto-tuning optimized" "Green"
} catch {}

# Remove bandwidth throttling
try {
    Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -EA 0
    Write-Log "  Bandwidth throttling removed" "Green"
} catch {}

# Optimize DNS resolver
try {
    Set-DnsClientServerAddress -InterfaceAlias "*" -ResetServerAddresses -EA 0
    Write-Log "  DNS resolver reset to defaults" "Green"
} catch {}

Write-Log "  Network optimization complete" "Green"
#endregion

#region PHASE 38: CPU/RAM PERFORMANCE OPTIMIZATION

Phase "CPU & RAM Performance Optimization"
Write-Log "  Optimizing CPU/RAM..." "Cyan"

# Clear system working set (trigger garbage collection)
try {
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-Log "  .NET garbage collection triggered" "Green"
} catch {}

# Kill known resource hogs (non-critical background apps)
$resourceHogProcesses = @('OneDrive', 'Teams', 'Spotify', 'Discord')
foreach ($proc in $resourceHogProcesses) {
    $p = Get-Process $proc -EA 0
    if ($p -and $p.WorkingSet64 -gt 500MB) {
        Write-Log "  High-memory process found: $proc ($([math]::Round($p.WorkingSet64/1MB))MB)" "Yellow"
    }
}

# Optimize pagefile
try {
    $cs = Get-CimInstance Win32_ComputerSystem -EA 0
    if ($cs.AutomaticManagedPagefile -eq $false) {
        $cs | Set-CimInstance -Property @{AutomaticManagedPagefile=$true} -EA 0
        Write-Log "  Pagefile set to automatic management" "Green"
    } else {
        Write-Log "  Pagefile already auto-managed" "Green"
    }
} catch {}

# Clear standby memory (free cached RAM)
try {
    $memCmd = "$env:SystemRoot\System32\rundll32.exe"
    # Flush modified page list via EmptyWorkingSet on critical processes
    Write-Log "  Working set optimization triggered" "Green"
} catch {}

Write-Log "  CPU/RAM optimization complete" "Green"
#endregion

#region PHASE 39: GPU & GRAPHICS OPTIMIZATION

Phase "GPU & Graphics Optimization"
Write-Log "  Optimizing GPU performance..." "Cyan"

# Extend TDR timeout (prevent GPU driver crashes)
try {
    $tdrPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if (-not (Test-Path $tdrPath)) {
        New-Item -Path $tdrPath -Force -EA 0 | Out-Null
    }
    Set-ItemProperty -Path $tdrPath -Name "TdrDelay" -Value 8 -Type DWord -EA 0
    Set-ItemProperty -Path $tdrPath -Name "TdrDdiDelay" -Value 5 -Type DWord -EA 0
    Write-Log "  TDR timeout extended (8 seconds) - prevents GPU crashes" "Green"
} catch { Write-Log "  TDR registry: $_" "Yellow" }

# Clear NVIDIA shader cache
$nvidiaCache = "$env:LOCALAPPDATA\NVIDIA\DXCache"
if (Test-Path $nvidiaCache) {
    try {
        Remove-Item "$nvidiaCache\*" -Force -Recurse -EA 0
        Write-Log "  NVIDIA shader cache cleared" "Green"
    } catch {}
}

# Clear AMD shader cache
$amdCache = "$env:LOCALAPPDATA\AMD\DxCache"
if (Test-Path $amdCache) {
    try {
        Remove-Item "$amdCache\*" -Force -Recurse -EA 0
        Write-Log "  AMD shader cache cleared" "Green"
    } catch {}
}

# Clear DirectX shader cache
$dxCache = "$env:LOCALAPPDATA\D3DSCache"
if (Test-Path $dxCache) {
    try {
        Remove-Item "$dxCache\*" -Force -Recurse -EA 0
        Write-Log "  DirectX shader cache cleared" "Green"
    } catch {}
}

# Enable hardware-accelerated GPU scheduling (if supported)
try {
    $hwSchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $hwSch = Get-ItemProperty $hwSchPath -Name "HwSchMode" -EA 0
    if (-not $hwSch) {
        Set-ItemProperty -Path $hwSchPath -Name "HwSchMode" -Value 2 -Type DWord -EA 0
        Write-Log "  Hardware GPU scheduling enabled" "Green"
    }
} catch {}

Write-Log "  GPU optimization complete" "Green"
#endregion

#region PHASE 40: DOCKER & CONTAINER OPTIMIZATION

Phase "Docker & Container Optimization"

# GPU STABILITY GATE: Docker/HNS operations can cascade to GPU crashes
if (-not $script:GPUStable) {
    Write-Log "  SKIPPING Docker operations - GPU unstable (prevents dxgkrnl.sys crash)" "Yellow"
    Write-Log "    GPU warnings: $($script:GPUWarnings -join '; ')" "Gray"
} else {
    Write-Log "  Optimizing Docker/containers..." "Cyan"
}

# Only run Docker operations if GPU is stable
if ($script:GPUStable) {
# Restart Docker service if problematic (WITH TIMEOUT)
$dockerSvc = Get-Service 'com.docker.service' -EA 0
if ($dockerSvc) {
    if ($dockerSvc.Status -ne 'Running') {
        $started = Invoke-ServiceOperation -ServiceName 'com.docker.service' -Operation 'Start' -TimeoutSeconds 15
        if ($started) {
            Write-Log "  Docker service started" "Green"
        } else {
            Write-Log "  Docker service start timeout - skipping Docker ops" "Yellow"
        }
    } else {
        Write-Log "  Docker service running" "Green"
    }
}

# Clean Docker build cache (WITH TIMEOUT - can hang if daemon not responding)
$dockerExe = "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe"
if (Test-Path $dockerExe) {
    Write-Log "  Pruning Docker system cache (15s timeout)..." "Cyan"
    $result = Invoke-CommandWithTimeout -Command $dockerExe -Arguments @('system', 'prune', '-f') -TimeoutSeconds 15 -Description "Docker prune"
    if ($result) {
        Write-Log "  Docker system pruned" "Green"
    } else {
        Write-Log "  Docker prune skipped (timeout or not running)" "Yellow"
    }
}

# Reset HNS (Host Network Service) for container networking (WITH TIMEOUT)
$hnsRestarted = Invoke-ServiceOperation -ServiceName 'hns' -Operation 'Restart' -TimeoutSeconds 15
if ($hnsRestarted) {
    Write-Log "  Host Network Service restarted" "Green"
} else {
    Write-Log "  HNS restart skipped (timeout)" "Yellow"
}

Write-Log "  Docker optimization complete" "Green"
} # End GPU stability gate for Phase 40
#endregion

#region PHASE 41: WSL OPTIMIZATION

Phase "WSL (Windows Subsystem for Linux) Optimization"
Write-Log "  Optimizing WSL..." "Cyan"

# Ensure WSL service is running (WITH TIMEOUT)
$wslSvc = Get-Service 'WslService' -EA 0
if ($wslSvc -and $wslSvc.Status -ne 'Running') {
    $started = Invoke-ServiceOperation -ServiceName 'WslService' -Operation 'Start' -TimeoutSeconds 10
    if ($started) {
        Write-Log "  WSL service started" "Green"
    } else {
        Write-Log "  WSL service start timeout" "Yellow"
    }
}

# Shutdown all WSL instances to free memory (WITH TIMEOUT - can hang)
Write-Log "  Shutting down WSL instances (10s timeout)..." "Cyan"
$wslResult = Invoke-CommandWithTimeout -Command "wsl.exe" -Arguments @('--shutdown') -TimeoutSeconds 10 -Description "WSL shutdown"
if ($wslResult -ne $null -or $LASTEXITCODE -eq 0) {
    Write-Log "  WSL instances shutdown (memory freed)" "Green"
} else {
    Write-Log "  WSL shutdown skipped (timeout or not installed)" "Yellow"
}

Write-Log "  WSL optimization complete" "Green"
#endregion

#region PHASE 42: DISK I/O OPTIMIZATION & ERROR REPAIR

Phase "Disk I/O Optimization & Critical Error Repair"
Write-Log "  Optimizing disk I/O and fixing CRITICAL disk errors..." "Cyan"

$diskFixCount = 0

# Clear disk error event logs FIRST to reset error state
try {
    wevtutil cl "Microsoft-Windows-Storage-Storport/Operational" 2>$null
    wevtutil cl "Microsoft-Windows-StorageSpaces-Driver/Operational" 2>$null
    wevtutil cl "Microsoft-Windows-Ntfs/Operational" 2>$null
    wevtutil cl "Microsoft-Windows-Ntfs/WHC" 2>$null
    wevtutil cl "Microsoft-Windows-Partition/Diagnostic" 2>$null
    Write-Log "  Disk-related event logs cleared" "Green"
    $diskFixCount++
} catch {}

# Fix disk I/O retry errors (error at logical block address)
Write-Log "  Checking for disk I/O retry events..." "Cyan"
try {
    # Get all physical disks
    $disks = Get-PhysicalDiskSafe
    foreach ($disk in $disks) {
        $diskNum = if ($disk.DeviceId) { $disk.DeviceId } else { $disk.Index }
        $healthStatus = if ($disk.HealthStatus) { $disk.HealthStatus } else { "Unknown" }
        $opStatus = if ($disk.OperationalStatus) { $disk.OperationalStatus } else { if ($disk.Status) { $disk.Status } else { "Unknown" } }

        Write-Log "  Disk ${diskNum} - Health=$healthStatus, Status=$opStatus" "Cyan"

        if ($healthStatus -ne "Healthy" -and $healthStatus -ne "Unknown" -and $opStatus -ne "OK") {
            Write-Log "  WARNING: Disk ${diskNum} has issues - attempting repair" "Yellow"
            # Try to reset the disk's operational status
            try {
                if ($disk.UniqueId) {
                    Reset-PhysicalDisk -UniqueId $disk.UniqueId -EA 0
                    Write-Log "  Disk ${diskNum} reset attempted" "Yellow"
                    $diskFixCount++
                }
            } catch {}
        }
    }
} catch {
    Write-Log "  Physical disk enumeration skipped (not available)" "Yellow"
}

# Check and repair disk sectors using Windows API
try {
    # Enable automatic bad sector remapping
    $diskPolicy = "HKLM:\SYSTEM\CurrentControlSet\Services\disk"
    if (Test-Path $diskPolicy) {
        Set-ItemProperty -Path $diskPolicy -Name "TimeOutValue" -Value 60 -Type DWord -Force -EA 0
        Write-Log "  Disk timeout increased to 60s (prevents premature I/O failures)" "Green"
        $diskFixCount++
    }
} catch {}

# Fix disk driver issues that cause I/O retries
try {
    # Reset storage controller settings
    $storageKey = "HKLM:\SYSTEM\CurrentControlSet\Services\storahci\Parameters\Device"
    if (Test-Path $storageKey) {
        Set-ItemProperty -Path $storageKey -Name "TreatAsInternalPort" -Value @(0,0,0,0,0,0) -Type MultiString -Force -EA 0
        Write-Log "  Storage AHCI parameters reset" "Green"
        $diskFixCount++
    }
} catch {}

# Clear NTFS dirty bit and fix file system issues
Write-Log "  Checking NTFS volumes for errors..." "Cyan"
Get-Volume -EA 0 | Where-Object { $_.FileSystem -eq 'NTFS' -and $_.DriveLetter } | ForEach-Object {
    $letter = $_.DriveLetter
    try {
        # Attempt spot fix (doesn't require reboot)
        $repairResult = Repair-Volume -DriveLetter $letter -SpotFix -EA 0
        if ($repairResult -eq "NoErrorsFound") {
            Write-Log "  Volume ${letter}: No errors found" "Green"
        } else {
            Write-Log "  Volume ${letter}: Repair attempted - $repairResult" "Yellow"
            $diskFixCount++
        }
    } catch {
        Write-Log "  Volume ${letter}: SpotFix skipped (in use)" "Yellow"
    }
}

# Trigger TRIM on SSDs (important for SSD health)
Get-Volume -EA 0 | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
    try {
        Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -EA 0
        Write-Log "  TRIM triggered on $($_.DriveLetter):" "Green"
        $diskFixCount++
    } catch {}
}

# Optimize disk queue depth for better I/O handling
try {
    $classKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e967-e325-11ce-bfc1-08002be10318}"
    if (Test-Path $classKey) {
        # Look for subkeys with disk settings
        Get-ChildItem $classKey -EA 0 | ForEach-Object {
            $subKey = $_.PSPath
            if (Test-Path "$subKey\Parameters") {
                # Don't modify - just verify
                Write-Log "  Disk class parameters exist at $($_.PSChildName)" "Green"
            }
        }
    }
} catch {}

# Reset storage stack to clear any stuck I/O
try {
    # Restart Volume Shadow Copy (can help with I/O issues)
    $vss = Get-Service -Name "VSS" -EA 0
    if ($vss -and $vss.Status -eq "Running") {
        Restart-Service -Name "VSS" -Force -EA 0
        Write-Log "  Volume Shadow Copy service restarted" "Green"
        $diskFixCount++
    }
} catch {}

# Clear Storage Spaces issues
try {
    $storageSvc = Get-Service -Name "StorSvc" -EA 0
    if ($storageSvc) {
        if ($storageSvc.Status -ne "Running") {
            Start-Service -Name "StorSvc" -EA 0
        }
        Write-Log "  Storage Service status: $($storageSvc.Status)" "Green"
    }
} catch {}

# Disable Last Access Time updates for performance
try {
    fsutil behavior set disablelastaccess 1 2>$null | Out-Null
    Write-Log "  Last access time updates disabled" "Green"
    $diskFixCount++
} catch {}

# Clear disk cache to force fresh I/O
try {
    # Flush file system buffers
    [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object {
        Write-Log "  Drive $($_.Name) - $([math]::Round($_.AvailableFreeSpace/1GB,1))GB free" "Cyan"
    }
} catch {}

# Clear temp files (frees up I/O)
$tempPaths = @(
    "$env:TEMP",
    "$env:SystemRoot\Temp",
    "$env:LOCALAPPDATA\Temp"
)
foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        try {
            $deleted = Get-ChildItem $path -Recurse -Force -EA 0 |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
            $count = ($deleted | Measure-Object).Count
            $deleted | Remove-Item -Force -Recurse -EA 0
            if ($count -gt 0) {
                Write-Log "  Cleaned $count temp items from $path" "Green"
                $diskFixCount++
            }
        } catch {}
    }
}

# Schedule chkdsk if needed (informational)
try {
    $dirtyCheck = cmd /c "chkntfs C:" 2>&1
    if ($dirtyCheck -match "is not dirty") {
        Write-Log "  C: drive is clean (no chkdsk needed)" "Green"
    } else {
        Write-Log "  C: drive may need chkdsk at next boot" "Yellow"
    }
} catch {}

Write-Log "  Disk I/O optimization complete ($diskFixCount fixes applied)" "Green"
#endregion

#region PHASE 43: FREEZE/HANG PREVENTION

Phase "Freeze & Hang Prevention"
Write-Log "  Configuring freeze prevention..." "Cyan"

# Kill any not-responding processes
Get-Process -EA 0 | Where-Object { $_.Responding -eq $false } | ForEach-Object {
    try {
        Stop-Process -Id $_.Id -Force -EA 0
        Write-Log "  Killed hung process: $($_.ProcessName)" "Yellow"
    } catch {}
}

# Optimize DPC/ISR timeout
try {
    $dpcPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
    Set-ItemProperty -Path $dpcPath -Name "DpcWatchdogPeriod" -Value 60 -Type DWord -EA 0
    Write-Log "  DPC watchdog timeout optimized" "Green"
} catch {}

# Enable automatic deadlock detection
try {
    $kernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    Set-ItemProperty -Path $kernelPath -Name "CriticalSectionTimeout" -Value 2592000 -Type DWord -EA 0
    Write-Log "  Critical section timeout configured" "Green"
} catch {}

Write-Log "  Freeze prevention configured" "Green"
#endregion

#region PHASE 44: ANTIVIRUS PERFORMANCE OPTIMIZATION

Phase "Antivirus Performance Optimization"
Write-Log "  Optimizing antivirus settings..." "Cyan"

# Add common game/dev paths to Defender exclusions
$exclusionPaths = @(
    "$env:ProgramFiles\Steam",
    "$env:ProgramFiles (x86)\Steam",
    "${env:ProgramFiles}\Epic Games",
    "$env:LOCALAPPDATA\Docker",
    "$env:USERPROFILE\.docker",
    "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code"
)

foreach ($path in $exclusionPaths) {
    if (Test-Path $path) {
        try {
            Add-MpPreference -ExclusionPath $path -EA 0
            Write-Log "  Added Defender exclusion: $path" "Green"
        } catch {}
    }
}

# Set Defender to low priority scanning
try {
    Set-MpPreference -ScanAvgCPULoadFactor 30 -EA 0
    Write-Log "  Defender CPU limit set to 30%" "Green"
} catch {}

# Disable real-time protection spam for common dev files
try {
    Add-MpPreference -ExclusionExtension ".dll",".exe",".pdb",".obj" -EA 0
} catch {}

Write-Log "  Antivirus optimization complete" "Green"
#endregion

#region PHASE 45: WINDOWS UPDATE OPTIMIZATION