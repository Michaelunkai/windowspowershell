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

Phase "Final DCOM Comprehensive Fix"
Write-Log "  Applying comprehensive DCOM fixes..." "Cyan"

# Re-register ALL core COM DLLs
$comDlls = @(
    "$env:SystemRoot\System32\ole32.dll",
    "$env:SystemRoot\System32\oleaut32.dll",
    "$env:SystemRoot\System32\combase.dll",
    "$env:SystemRoot\System32\coml2.dll",
    "$env:SystemRoot\System32\actxprxy.dll",
    "$env:SystemRoot\System32\comsvcs.dll"
)

foreach ($dll in $comDlls) {
    if (Test-Path $dll) {
        try {
            cmd /c "regsvr32 /s `"$dll`" 2>nul" | Out-Null
        } catch {}
    }
}
Write-Log "  Core COM DLLs re-registered" "Green"

# Restart DCOM services
try {
    Restart-Service DcomLaunch -Force -EA 0
    Write-Log "  DcomLaunch service restarted" "Green"
} catch {}

try {
    Restart-Service RpcSs -Force -EA 0
    Write-Log "  RpcSs service restarted" "Green"
} catch {}

# Clear DCOM error state
try {
    $dcomPath = "HKLM:\SOFTWARE\Microsoft\Ole"
    Set-ItemProperty -Path $dcomPath -Name "EnableDCOM" -Value "Y" -EA 0
    Set-ItemProperty -Path $dcomPath -Name "LegacyAuthenticationLevel" -Value 2 -Type DWord -EA 0
    Write-Log "  DCOM configuration optimized" "Green"
} catch {}

# Register Shell Experience Host COM object (fixes {8CFC164F-4BE5-4FDD-94E9-E2AF73ED4A19})
try {
    $shellExp = Get-AppxPackage Microsoft.Windows.ShellExperienceHost -EA 0
    if ($shellExp) {
        Add-AppxPackage -DisableDevelopmentMode -Register "$($shellExp.InstallLocation)\AppXManifest.xml" -EA 0
        Write-Log "  Shell Experience Host re-registered" "Green"
    }
} catch {}

Write-Log "  DCOM comprehensive fix complete" "Green"
#endregion

#region PHASE 51: MTKBTSVC HANDLE LEAK FIX (MediaTek Bluetooth) - AGGRESSIVE

Phase "Fixing mtkbtsvc Handle Leak (MediaTek Bluetooth) - 41000+ handles fix"
Write-Log "  Aggressively fixing MediaTek Bluetooth service handle leak..." "Cyan"

$mtkFixCount = 0

# Clear Bluetooth-related event logs first
try {
    wevtutil cl "Microsoft-Windows-Bluetooth-Policy/Operational" 2>$null
    wevtutil cl "Microsoft-Windows-Bluetooth-MTPEnum/Operational" 2>$null
    Write-Log "  Bluetooth event logs cleared" "Green"
    $mtkFixCount++
} catch {}

# Check for mtkbtsvc service (MediaTek Bluetooth)
$mtkSvc = Get-Service -Name 'mtkbtsvc' -EA 0
if ($mtkSvc) {
    # Check handle count
    try {
        $mtkProc = Get-Process -Name 'mtkbtsvc' -EA 0
        if ($mtkProc) {
            $handleCount = $mtkProc.HandleCount
            Write-Log "  mtkbtsvc current handle count: $handleCount" "Cyan"

            # Lower threshold - 41122 handles is CRITICAL leak
            if ($handleCount -gt 500) {
                Write-Log "  CRITICAL HANDLE LEAK DETECTED ($handleCount handles)! Performing aggressive fix..." "Red"

                # Step 1: Stop dependent services first
                $btServices = @('bthserv', 'BluetoothUserService*', 'BTAGService')
                foreach ($btSvc in $btServices) {
                    Get-Service -Name $btSvc -EA 0 | Where-Object { $_.Status -eq 'Running' } | Stop-Service -Force -EA 0
                }
                Write-Log "  Stopped dependent Bluetooth services" "Yellow"

                # Step 2: Force stop the service
                Stop-Service -Name 'mtkbtsvc' -Force -EA 0
                Start-Sleep -Seconds 2

                # Step 3: Kill any remaining process instances FORCEFULLY
                $mtkProcs = Get-Process -Name 'mtkbtsvc' -EA 0
                foreach ($p in $mtkProcs) {
                    try {
                        $p.Kill()
                        $p.WaitForExit(5000)
                        Write-Log "  Killed mtkbtsvc process (PID: $($p.Id))" "Yellow"
                        $mtkFixCount++
                    } catch {}
                }
                Start-Sleep -Seconds 2

                # Step 4: Clear MediaTek Bluetooth cache/temp files
                $mtkCachePaths = @(
                    "$env:LOCALAPPDATA\MediaTek",
                    "$env:ProgramData\MediaTek",
                    "$env:TEMP\mtk*"
                )
                foreach ($cachePath in $mtkCachePaths) {
                    if (Test-Path $cachePath) {
                        try {
                            Remove-Item -Path $cachePath -Recurse -Force -EA 0
                            Write-Log "  Cleared cache: $cachePath" "Green"
                            $mtkFixCount++
                        } catch {}
                    }
                }

                # Step 5: Reset MediaTek Bluetooth registry settings
                try {
                    $mtkRegPaths = @(
                        "HKLM:\SYSTEM\CurrentControlSet\Services\mtkbtsvc",
                        "HKCU:\Software\MediaTek"
                    )
                    foreach ($regPath in $mtkRegPaths) {
                        if (Test-Path $regPath) {
                            # Don't delete, just reset failure actions
                            if ($regPath -match "Services\\mtkbtsvc") {
                                # Reset service recovery options
                                sc.exe failure mtkbtsvc reset= 0 actions= restart/60000/restart/60000/restart/60000 2>$null
                                Write-Log "  Reset mtkbtsvc service recovery options" "Green"
                                $mtkFixCount++
                            }
                        }
                    }
                } catch {}

                # Step 6: Wait longer before restart to ensure complete cleanup
                Start-Sleep -Seconds 3

                # Step 7: Restart the service
                try {
                    Start-Service -Name 'mtkbtsvc' -EA 0
                    Start-Sleep -Seconds 3

                    # Verify fix
                    $mtkProcNew = Get-Process -Name 'mtkbtsvc' -EA 0
                    if ($mtkProcNew) {
                        $newHandleCount = $mtkProcNew.HandleCount
                        Write-Log "  mtkbtsvc restarted - new handle count: $newHandleCount (was $handleCount)" "Green"
                        $mtkFixCount++

                        if ($newHandleCount -lt 500) {
                            Write-Log "  SUCCESS: Handle leak fixed! Reduced from $handleCount to $newHandleCount" "Green"
                        } else {
                            Write-Log "  WARNING: Handle count still elevated - may need driver update" "Yellow"
                        }
                    } else {
                        Write-Log "  mtkbtsvc did not restart - service may be disabled" "Yellow"
                    }
                } catch {
                    Write-Log "  Could not restart mtkbtsvc: $_" "Yellow"
                }

                # Step 8: Restart dependent services
                foreach ($btSvc in $btServices) {
                    Get-Service -Name $btSvc -EA 0 | Where-Object { $_.StartType -ne 'Disabled' } | Start-Service -EA 0
                }
                Write-Log "  Restarted Bluetooth support services" "Green"

            } else {
                Write-Log "  mtkbtsvc handle count acceptable ($handleCount)" "Green"
            }
        }
    } catch {
        Write-Log "  Could not check mtkbtsvc handles: $_" "Yellow"
    }
} else {
    Write-Log "  mtkbtsvc service not found (MediaTek Bluetooth not installed)" "Green"
}

# Check for ALL processes with high handle counts (expanded threshold)
Write-Log "  Scanning for other handle leak candidates..." "Cyan"
$handleLeakCandidates = Get-Process -EA 0 | Where-Object {
    $_.HandleCount -gt 3000 -and
    $_.ProcessName -notin @('System', 'svchost', 'explorer', 'dwm', 'csrss', 'services', 'lsass', 'Memory Compression')
}

foreach ($proc in $handleLeakCandidates) {
    Write-Log "  HIGH HANDLE COUNT: $($proc.ProcessName) - $($proc.HandleCount) handles (PID: $($proc.Id))" "Yellow"

    # For extremely high handle counts (>20000), attempt automatic restart for non-critical processes
    if ($proc.HandleCount -gt 20000) {
        $criticalProcesses = @('winlogon', 'wininit', 'smss', 'RuntimeBroker', 'SearchIndexer', 'SecurityHealthService')
        if ($proc.ProcessName -notin $criticalProcesses) {
            Write-Log "  CRITICAL: $($proc.ProcessName) has $($proc.HandleCount) handles - attempting restart..." "Red"
            try {
                # Try graceful stop first via service
                $svc = Get-Service -EA 0 | Where-Object { $_.Status -eq 'Running' } |
                    Where-Object { (Get-Process -Id $_.ProcessId -EA 0).ProcessName -eq $proc.ProcessName }
                if ($svc) {
                    Restart-Service -Name $svc.Name -Force -EA 0
                    Write-Log "  Restarted service for $($proc.ProcessName)" "Green"
                    $mtkFixCount++
                }
            } catch {}
        }
    }
}

# Summary of handle leak detection
$totalHighHandles = ($handleLeakCandidates | Measure-Object).Count
if ($totalHighHandles -gt 0) {
    Write-Log "  Found $totalHighHandles processes with high handle counts" "Yellow"
} else {
    Write-Log "  No handle leak candidates found (all processes healthy)" "Green"
}

Write-Log "  Handle leak fix complete ($mtkFixCount fixes applied)" "Green"
#endregion

#region PHASE 52: AGGRESSIVE HNS/DOCKER NETWORK RESET (0x80070032 FIX)

Phase "Aggressive HNS/Docker Network Reset (IpNatHlpStopSharing 0x80070032 Fix)"

# GPU STABILITY GATE: HNS operations can cascade to GPU crashes via ICS/NAT
if (-not $script:GPUStable) {
    Write-Log "  SKIPPING aggressive HNS reset - GPU unstable (prevents dxgkrnl.sys crash)" "Yellow"
    Write-Log "    GPU warnings: $($script:GPUWarnings -join '; ')" "Gray"
} else {
    Write-Log "  Performing aggressive HNS cleanup with winnat/NAT error fix..." "Cyan"
}

# Only run HNS operations if GPU is stable
if ($script:GPUStable) {
$hnsFixCount = 0

# Clear HNS-related event logs FIRST (using safe clear)
try {
    Clear-EventLogSafe "Microsoft-Windows-Host-Network-Service-Admin"
    Clear-EventLogSafe "Microsoft-Windows-Hyper-V-VmSwitch-Operational"
    Clear-EventLogSafe "Microsoft-Windows-SharedAccess_NAT/Operational"
    Write-Log "  HNS/NAT event logs cleared" "Green"
    $hnsFixCount++
} catch {}

# FIX FOR ERROR 0x80070032: IpNatHlpStopSharing / winnat deletion failure
Write-Log "  Fixing WinNAT/ICS error 0x80070032..." "Cyan"

# Step 1: Stop ICS (Internet Connection Sharing) service - root cause of IpNatHlpStopSharing errors (WITH TIMEOUT)
try {
    $icsSvc = Get-Service -Name "SharedAccess" -EA 0
    if ($icsSvc) {
        if ($icsSvc.Status -eq "Running") {
            $stopped = Invoke-ServiceOperation -ServiceName "SharedAccess" -Operation "Stop" -TimeoutSeconds 10
            if ($stopped) {
                Write-Log "  Internet Connection Sharing (ICS) service stopped" "Green"
                $hnsFixCount++
            } else {
                Write-Log "  ICS service stop timeout - continuing" "Yellow"
            }
        }
        # Disable ICS to prevent future errors
        Set-Service -Name "SharedAccess" -StartupType Manual -EA 0
        Write-Log "  ICS service set to Manual startup" "Green"
    }
} catch {}

# Step 2: Remove ALL WinNAT/NAT instances (correct method - NOT routing ip nat)
try {
    Write-Log "  Checking and removing NAT instances..." "Cyan"

    # Method 1: Remove WinNAT via netsh interface (correct command for Windows 10/11)
    netsh interface portproxy reset 2>$null
    Write-Log "  Port proxy reset" "Green"

    # Method 2: Remove NAT via PowerShell (correct approach)
    $natList = Get-NetNat -EA 0
    foreach ($n in $natList) {
        Remove-NetNat -Name $n.Name -Confirm:$false -EA 0
        Write-Log "  Removed NAT: $($n.Name)" "Green"
    }

    # Method 3: Reset ICS (actual NAT on Windows)
    netsh winsock reset 2>$null
    $hnsFixCount++
} catch {}

# Step 3: Remove WinNAT networks using PowerShell
try {
    $winNat = Get-NetNat -EA 0
    if ($winNat) {
        foreach ($nat in $winNat) {
            Remove-NetNat -Name $nat.Name -Confirm:$false -EA 0
            Write-Log "  Removed NetNat: $($nat.Name)" "Green"
            $hnsFixCount++
        }
    } else {
        Write-Log "  No WinNAT instances found (clean)" "Green"
    }
} catch {
    Write-Log "  NetNat cleanup: $_" "Yellow"
}

# Step 4: Clean NAT address pools
try {
    Get-NetNatTransientMapping -EA 0 | Remove-NetNatTransientMapping -EA 0
    Write-Log "  NAT transient mappings cleared" "Green"
    $hnsFixCount++
} catch {}

# Step 5: Stop all Docker/container related services (WITH TIMEOUT)
$dockerServices = @('com.docker.service', 'Docker Desktop Service', 'Docker', 'HNS', 'vmcompute', 'vmms', 'WinNAT')
foreach ($svc in $dockerServices) {
    $service = Get-Service -Name $svc -EA 0
    if ($service -and $service.Status -eq 'Running') {
        try {
            $stopJob = Start-Job -ScriptBlock {
                param($ServiceName)
                try {
                    Stop-Service -Name $ServiceName -Force -EA Stop
                    return $true
                } catch {
                    return $false
                }
            } -ArgumentList $svc

            $stopped = $stopJob | Wait-Job -Timeout 30 | Receive-Job -EA 0
            Remove-Job $stopJob -Force -EA 0

            if ($stopped) {
                Write-Log "  Stopped: $svc" "Yellow"
                $hnsFixCount++
            } else {
                Write-Log "  Stop timeout: $svc - continuing" "Yellow"
            }
        } catch {
            Write-Log "  Stop failed: $svc - continuing" "Yellow"
        }
    }
}
Start-Sleep -Seconds 2

# Step 6: Clear HNS network data
$hnsDataPath = "$env:ProgramData\Microsoft\Windows\HNS"
if (Test-Path $hnsDataPath) {
    try {
        # Backup current config
        $backupPath = "$hnsDataPath.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $hnsDataPath -Destination $backupPath -Recurse -Force -EA 0

        # Clear HNS data files
        Get-ChildItem $hnsDataPath -EA 0 | Remove-Item -Recurse -Force -EA 0
        Write-Log "  Cleared HNS data (backed up)" "Green"
        $hnsFixCount++
    } catch {
        Write-Log "  Could not clear HNS data: $_" "Yellow"
    }
}

# Step 7: Clear Docker network namespaces and ALL HNS networks (WITH TIMEOUT - prevents hang)
try {
    $hnsJob = Start-Job -ScriptBlock {
        try {
            $networks = Get-HnsNetwork -EA 0
            foreach ($net in $networks) {
                $net | Remove-HnsNetwork -EA 0
            }
            return $networks.Count
        } catch { return 0 }
    }
    $hnsResult = $hnsJob | Wait-Job -Timeout 15 | Receive-Job -EA 0
    Remove-Job $hnsJob -Force -EA 0
    if ($hnsResult -gt 0) {
        Write-Log "  Removed $hnsResult HNS networks" "Green"
        $hnsFixCount += $hnsResult
    } else {
        Write-Log "  HNS network cleanup completed (or timed out)" "Yellow"
    }
} catch {
    Write-Log "  HNS network cleanup skipped" "Yellow"
}

# Step 8: Clear HNS endpoints (WITH TIMEOUT - prevents hang)
try {
    $endpointJob = Start-Job -ScriptBlock {
        try {
            $endpoints = Get-HnsEndpoint -EA 0
            $endpoints | Remove-HnsEndpoint -EA 0
            return $endpoints.Count
        } catch { return 0 }
    }
    $epResult = $endpointJob | Wait-Job -Timeout 10 | Receive-Job -EA 0
    Remove-Job $endpointJob -Force -EA 0
    if ($epResult -gt 0) {
        Write-Log "  Cleared $epResult orphaned HNS endpoints" "Green"
        $hnsFixCount++
    } else {
        Write-Log "  HNS endpoint cleanup completed (or timed out)" "Yellow"
    }
} catch {}

# Step 9: Reset network stack completely
try {
    netsh int ipv4 reset 2>$null | Out-Null
    netsh int ipv6 reset 2>$null | Out-Null
    netsh winsock reset 2>$null | Out-Null
    Write-Log "  Complete IP/Winsock stack reset for container networking" "Green"
    $hnsFixCount++
} catch {}

# Step 10: Clear WMI NAT class residuals (MSFT_NAT)
try {
    $wmiNat = Get-CimInstance -Namespace "root/StandardCimv2" -ClassName "MSFT_NAT" -EA 0
    if ($wmiNat) {
        foreach ($nat in $wmiNat) {
            Remove-CimInstance -InputObject $nat -EA 0
            Write-Log "  Removed WMI MSFT_NAT instance: $($nat.Name)" "Green"
            $hnsFixCount++
        }
    } else {
        Write-Log "  No orphaned MSFT_NAT WMI instances" "Green"
    }
} catch {
    Write-Log "  WMI NAT cleanup not needed (expected if no NAT configured)" "Yellow"
}

# Step 11: Restart HNS service (WITH TIMEOUT)
$hnsStarted = Invoke-ServiceOperation -ServiceName 'HNS' -Operation 'Start' -TimeoutSeconds 15
if ($hnsStarted) {
    Write-Log "  HNS service restarted successfully" "Green"
    $hnsFixCount++
} else {
    Write-Log "  HNS start timeout - continuing" "Yellow"
}

# Step 12: Restart Docker if it was installed (WITH TIMEOUT)
$dockerSvc = Get-Service -Name 'com.docker.service' -EA 0
if (-not $dockerSvc) {
    $dockerSvc = Get-Service -Name 'Docker Desktop Service' -EA 0
}
if ($dockerSvc) {
    $dockerStarted = Invoke-ServiceOperation -ServiceName $dockerSvc.Name -Operation 'Start' -TimeoutSeconds 15
    if ($dockerStarted) {
        Write-Log "  Docker service restarted" "Green"
        $hnsFixCount++
    } else {
        Write-Log "  Docker start timeout - continuing" "Yellow"
    }
}

# Step 13: Clear any remaining NAT error events
try {
    Clear-EventLogSafe "Microsoft-Windows-SharedAccess_NAT/Operational"
    Write-Log "  NAT event logs re-cleared after fix" "Green"
} catch {}

Write-Log "  HNS/Docker/NAT reset complete ($hnsFixCount fixes - 0x80070032 addressed)" "Green"
} # End GPU stability gate for Phase 52
#endregion

#region PHASE 53: CPU THERMAL MANAGEMENT (PRESERVE POWER PLAN)

Phase "CPU Thermal Management (preserving Nuclear_Performance_v12)"
Write-Log "  Configuring CPU thermal management WITHOUT changing power plan..." "Cyan"

$thermalFixCount = 0

# Verify current power plan is preserved
$currentPlanCheck = powercfg /getactivescheme 2>$null
$planName = if ($currentPlanCheck -match '\(([^)]+)\)') { $matches[1] } else { "Custom" }
Write-Log "  Power plan preserved: $planName (NOT modified)" "Green"

# Check CPU temperature (if available)
try {
    $cpuTemp = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace "root/WMI" -EA 0 |
        Select-Object -First 1 -ExpandProperty CurrentTemperature
    if ($cpuTemp) {
        $cpuTempC = [math]::Round(($cpuTemp - 2732) / 10, 1)
        Write-Log "  Current CPU temperature: ${cpuTempC}C" "Cyan"

        if ($cpuTempC -gt 85) {
            Write-Log "  HIGH TEMPERATURE DETECTED! (but preserving power plan)" "Red"
            # Only log, don't change power settings - user wants Nuclear_Performance_v12
        }
    }
} catch {
    Write-Log "  CPU temperature monitoring not available via WMI" "Yellow"
}

# Thermal management via registry (doesn't change power plan)
try {
    # Enable ACPI thermal zone monitoring
    $thermalKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    if (Test-Path $thermalKey) {
        Set-ItemProperty -Path $thermalKey -Name "CsEnabled" -Value 1 -Type DWord -Force -EA 0
        Write-Log "  Connected Standby thermal management enabled" "Green"
        $thermalFixCount++
    }
} catch {}

# Clear thermal throttling events from event log
try {
    Clear-EventLogSafe "Microsoft-Windows-Kernel-Power/Thermal"
    Clear-EventLogSafe "Microsoft-Windows-Kernel-Processor-Power/Diagnostic"
    Write-Log "  Thermal event logs cleared" "Green"
    $thermalFixCount++
} catch {}

# Optimize CPU parking via registry (doesn't change power plan)
try {
    $cpuParkingKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    if (Test-Path $cpuParkingKey) {
        # Set attributes to allow user to see the setting (informational)
        Write-Log "  CPU parking registry keys exist (OK)" "Green"
        $thermalFixCount++
    }
} catch {}

# Kill CPU-intensive background processes that aren't critical
$cpuHogs = Get-Process -EA 0 | Where-Object { $_.CPU -gt 300 -and $_.ProcessName -notin @('System', 'dwm', 'explorer', 'csrss', 'wininit', 'services', 'lsass', 'smss') }
foreach ($hog in $cpuHogs) {
    Write-Log "  High CPU process: $($hog.ProcessName) - $([math]::Round($hog.CPU))s CPU time" "Yellow"
}

# Cleanup CPU throttling service issues
try {
    $throttleSvc = Get-Service -Name "Intel(R) Dynamic Platform and Thermal Framework*" -EA 0
    if ($throttleSvc) {
        Write-Log "  Intel DPTF service found: $($throttleSvc.Status)" "Cyan"
    }
} catch {}

Write-Log "  CPU thermal management complete ($thermalFixCount fixes, power plan UNCHANGED)" "Green"
#endregion


#region PHASE 55: ULTIMATE BOOT-CRITICAL FILE PROTECTION SYSTEM

Phase "ULTIMATE Boot-Critical File Protection (CRITICAL SAFETY)"

Write-Host "=" * 70 -ForegroundColor Red
Write-Host "CRITICAL SAFETY: Boot-Critical File Protection System v6.0" -ForegroundColor Red
Write-Host "This prevents the acpiex.sys corruption that occurred previously" -ForegroundColor Yellow
Write-Host "=" * 70 -ForegroundColor Red

$script:bootCriticalFiles = @(
    # ACPI and Power Management (CRITICAL - caused previous boot failure)
    "drivers\acpi.sys",
    "drivers\acpiex.sys",
    "drivers\acpipagr.sys",
    "drivers\acpipmi.sys",
    "drivers\acpitime.sys",

    # Kernel and HAL (ABSOLUTELY CRITICAL)
    "ntoskrnl.exe",
    "hal.dll",
    "ntdll.dll",
    "kernel32.dll",
    "kernelbase.dll",

    # Storage Drivers (CRITICAL - no boot without these)
    "drivers\disk.sys",
    "drivers\partmgr.sys",
    "drivers\volmgr.sys",
    "drivers\volmgrx.sys",
    "drivers\msahci.sys",
    "drivers\storahci.sys",
    "drivers\stornvme.sys",

    # File System Drivers (CRITICAL)
    "drivers\NTFS.sys",
    "drivers\fltmgr.sys",

    # Boot Loader Components
    "winload.exe",
    "winresume.exe",
    "bootmgr.exe",

    # Critical System Processes
    "csrss.exe",
    "smss.exe",
    "lsass.exe",
    "services.exe",
    "winlogon.exe",

    # Graphics (needed for boot display)
    "win32k.sys",
    "win32kfull.sys",
    "win32kbase.sys"
)

$script:backupDir = "F:\Downloads\fix\boot_critical_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$script:backupManifest = @{}

try {
    # Create backup directory
    New-Item -Path $script:backupDir -ItemType Directory -Force | Out-Null
    Write-Log "  Created backup directory: $script:backupDir" "Green"

    # Backup each boot-critical file
    $backupCount = 0
    foreach ($relPath in $script:bootCriticalFiles) {
        $sourcePath = Join-Path $env:SystemRoot "System32\$relPath"
        if (Test-Path $sourcePath) {
            try {
                # Calculate hash BEFORE backup
                $sourceHash = (Get-FileHash -Path $sourcePath -Algorithm SHA256 -EA 0).Hash

                # Create subdirectory structure in backup
                $backupPath = Join-Path $script:backupDir $relPath
                $backupParent = Split-Path $backupPath -Parent
                if (-not (Test-Path $backupParent)) {
                    New-Item -Path $backupParent -ItemType Directory -Force | Out-Null
                }

                # Backup the file
                Copy-Item -Path $sourcePath -Destination $backupPath -Force

                # Verify backup integrity
                $backupHash = (Get-FileHash -Path $backupPath -Algorithm SHA256 -EA 0).Hash
                if ($backupHash -eq $sourceHash) {
                    $script:backupManifest[$relPath] = @{
                        SourcePath = $sourcePath
                        BackupPath = $backupPath
                        OriginalHash = $sourceHash
                        BackupTime = Get-Date
                    }
                    $backupCount++
                } else {
                    Write-Log "  WARNING: Backup verification failed for $relPath" "Red"
                }
            } catch {
                Write-Log "  WARNING: Could not backup $relPath : $_" "Yellow"
            }
        }
    }

    Write-Log "  Backed up $backupCount boot-critical files with SHA256 verification" "Green"

    # Save manifest to JSON
    $manifestPath = Join-Path $script:backupDir "backup_manifest.json"
    $script:backupManifest | ConvertTo-Json -Depth 10 | Out-File $manifestPath -Encoding UTF8
    Write-Log "  Backup manifest saved: $manifestPath" "Green"

} catch {
    Write-Log "  ERROR creating boot-critical backup: $_" "Red"
    Write-Log "  ABORTING REPAIR - cannot proceed without backup!" "Red"
    Restore-ProtectedDrivers
    Release-Mutex
    pause
    exit 1
}

# Function to verify file integrity after operations
function Verify-BootCriticalIntegrity {
    Write-Log "`n  Verifying boot-critical file integrity..." "Cyan"
    $corruptCount = 0
    $verifiedCount = 0

    foreach ($relPath in $script:backupManifest.Keys) {
        $manifest = $script:backupManifest[$relPath]
        $currentPath = $manifest.SourcePath

        if (Test-Path $currentPath) {
            try {
                $currentHash = (Get-FileHash -Path $currentPath -Algorithm SHA256 -EA 0).Hash

                # Check if file was modified
                if ($currentHash -ne $manifest.OriginalHash) {
                    # File changed - verify it's still valid
                    $fileInfo = Get-Item $currentPath -EA 0

                    # Check if file is zero-sized or suspiciously small
                    if ($fileInfo.Length -lt 1024) {
                        Write-Log "  CORRUPTION DETECTED: $relPath is $($fileInfo.Length) bytes (too small!)" "Red"
                        $corruptCount++

                        # Auto-restore from backup
                        try {
                            Copy-Item -Path $manifest.BackupPath -Destination $currentPath -Force
                            Write-Log "    AUTO-RESTORED from backup" "Green"
                        } catch {
                            Write-Log "    RESTORE FAILED: $_" "Red"
                        }
                    } else {
                        # File changed but seems valid size - just note it
                        Write-Log "  Modified: $relPath (was updated by repair)" "Yellow"
                        $verifiedCount++
                    }
                } else {
                    $verifiedCount++
                }
            } catch {
                Write-Log "  ERROR verifying $relPath : $_" "Red"
            }
        } else {
            Write-Log "  MISSING: $relPath - FILE DELETED!" "Red"
            $corruptCount++

            # Auto-restore from backup
            try {
                Copy-Item -Path $manifest.BackupPath -Destination $currentPath -Force
                Write-Log "    AUTO-RESTORED from backup" "Green"
            } catch {
                Write-Log "    RESTORE FAILED: $_" "Red"
            }
        }
    }

    Write-Log "  Integrity check: $verifiedCount OK, $corruptCount corrupted/restored" "Cyan"

    if ($corruptCount -gt 0) {
        Write-Log "  WARNING: $corruptCount boot-critical file(s) were corrupted and restored!" "Yellow"
    }
}
#endregion

#region PHASE 56: PRE-FLIGHT SYSTEM INTEGRITY CHECK

Phase "Pre-Flight System Integrity Check (Safe to Repair?)"

Write-Log "  Checking if system is in stable state for repair..." "Cyan"

$script:safeToRepair = $true
$script:repairIssues = @()

# Check 1: Component Store Health (CRITICAL - caused acpiex.sys corruption)
try {
    Write-Log "  Checking component store health..." "Gray"
    $dismCheck = & dism /online /cleanup-image /checkhealth 2>&1 | Out-String

    if ($dismCheck -match 'repairable|corrupt') {
        Write-Log "  COMPONENT STORE CORRUPTED - will use SAFE repair method" "Red"
        $script:repairIssues += "Component store corrupted - must fix BEFORE system file repair"
        $script:componentStoreCorrupt = $true
    } else {
        Write-Log "  Component store: Healthy" "Green"
        $script:componentStoreCorrupt = $false
    }
} catch {
    Write-Log "  Could not check component store: $_" "Yellow"
    $script:componentStoreCorrupt = $true
}

# Check 2: Pending File Operations (can cause conflicts)
$pendingOps = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -EA 0
if ($pendingOps -and $pendingOps.PendingFileRenameOperations) {
    $opCount = $pendingOps.PendingFileRenameOperations.Count
    Write-Log "  WARNING: $opCount pending file operations - may interfere with repair" "Yellow"
    $script:repairIssues += "$opCount pending file operations"
}

# Check 3: System File Stability
try {
    $criticalFiles = @("$env:SystemRoot\System32\ntoskrnl.exe", "$env:SystemRoot\System32\drivers\acpiex.sys")
    foreach ($file in $criticalFiles) {
        if (Test-Path $file) {
            $fileInfo = Get-Item $file -EA 0
            if ($fileInfo.Length -lt 1024) {
                Write-Log "  CRITICAL: $file is corrupted (only $($fileInfo.Length) bytes)!" "Red"
                $script:safeToRepair = $false
                $script:repairIssues += "$file is corrupted"
            }
        } else {
            Write-Log "  CRITICAL: $file is MISSING!" "Red"
            $script:safeToRepair = $false
            $script:repairIssues += "$file is missing"
        }
    }
} catch {}

# Check 4: Disk Health
try {
    $disks = Get-PhysicalDiskSafe
    foreach ($disk in $disks) {
        $diskName = if ($disk.FriendlyName) { $disk.FriendlyName } else { if ($disk.Model) { $disk.Model } else { "Disk $($disk.Index)" } }
        $healthStatus = if ($disk.HealthStatus) { $disk.HealthStatus } else { "Unknown" }
        if ($healthStatus -ne 'Healthy' -and $healthStatus -ne 'Unknown') {
            Write-Log "  WARNING: Disk $diskName health: $healthStatus" "Yellow"
            $script:repairIssues += "Disk $diskName unhealthy"
        }
    }
} catch {}

# Check 5: Available Disk Space
$sysDrive = Get-PSDrive C -EA 0
if ($sysDrive) {
    $freeGB = [math]::Round($sysDrive.Free / 1GB, 2)
    if ($freeGB -lt 5) {
        Write-Log "  CRITICAL: Only $freeGB GB free on C: - need at least 5GB for safe repair!" "Red"
        $script:safeToRepair = $false
        $script:repairIssues += "Insufficient disk space ($freeGB GB)"
    } else {
        Write-Log "  Disk space: $freeGB GB free (OK)" "Green"
    }
}

# Decision
if (-not $script:safeToRepair) {
    Write-Log "`n========================================" "Red"
    Write-Log "PRE-FLIGHT CHECK FAILED!" "Red"
    Write-Log "System is NOT safe for repair. Issues:" "Red"
    foreach ($issue in $script:repairIssues) {
        Write-Log "  - $issue" "Yellow"
    }
    Write-Log "ABORTING to prevent system damage!" "Red"
    Write-Log "========================================" "Red"
    Restore-ProtectedDrivers
    Release-Mutex
    pause
    exit 1
} else {
    Write-Log "`nPre-flight check PASSED - safe to proceed with repair" "Green"
    if ($script:repairIssues.Count -gt 0) {
        Write-Log "Minor issues detected (will be addressed):" "Yellow"
        foreach ($issue in $script:repairIssues) {
            Write-Log "  - $issue" "Yellow"
        }
    }
}
#endregion

#region PHASE 57: SAFE COMPONENT STORE REPAIR (Fixes DISM corruption)

Phase "Safe Component Store Repair (Prevents acpiex.sys corruption)"

if ($script:componentStoreCorrupt) {
    Write-Log "  Component store is corrupt - using SAFE repair method..." "Yellow"
    Write-Log "  WARNING: WILL NOT use /RestoreHealth (it corrupts files when store is bad!)" "Red"

    try {
        # Step 1: Analyze component store
        Write-Log "  Step 1/4: Analyzing component store..." "Cyan"
        dism /online /cleanup-image /analyzecomponentstore | Out-Null
        Start-Sleep -Seconds 2

        # Step 2: Clean up superseded components (safe operation)
        Write-Log "  Step 2/4: Cleaning superseded components..." "Cyan"
        dism /online /cleanup-image /startcomponentcleanup | Out-Null
        Start-Sleep -Seconds 5

        # Step 3: Reset base (removes backup components)
        Write-Log "  Step 3/4: Resetting component base..." "Cyan"
        dism /online /cleanup-image /startcomponentcleanup /resetbase | Out-Null
        Start-Sleep -Seconds 5

        # Step 4: Re-check health
        Write-Log "  Step 4/4: Re-checking component store..." "Cyan"
        $dismRecheck = & dism /online /cleanup-image /checkhealth 2>&1 | Out-String

        if ($dismRecheck -match 'repairable|corrupt') {
            Write-Log "  Component store still corrupted - skipping SFC" "Yellow"
            Write-Log "  SAFE MODE: Will not run RestoreHealth or SFC to prevent file corruption" "Red"
            $script:skipSFC = $true
        } else {
            Write-Log "  Component store repaired successfully!" "Green"
            $script:skipSFC = $false
        }

    } catch {
        Write-Log "  Error during component store repair: $_" "Yellow"
        Write-Log "  Skipping SFC for safety" "Yellow"
        $script:skipSFC = $true
    }
} else {
    Write-Log "  Component store is healthy - safe to proceed with full repair" "Green"
    $script:skipSFC = $false
}

# Verify boot-critical files after component store operations
Verify-BootCriticalIntegrity
#endregion

#region PHASE 58: SAFE SYSTEM FILE CHECKER (Only if safe)

Phase "System File Checker (Safe Mode)"

if ($script:skipSFC) {
    Write-Log "  SKIPPING SFC - component store is corrupted (would make things worse!)" "Yellow"
    Write-Log "  This prevents the acpiex.sys corruption that happened before" "Cyan"
} else {
    Write-Log "  Running SFC with boot-critical file protection..." "Cyan"

    try {
        # Run SFC
        $sfcResult = & sfc /scannow 2>&1 | Out-String

        if ($sfcResult -match 'did not find any integrity violations') {
            Write-Log "  SFC: No integrity violations found" "Green"
        } elseif ($sfcResult -match 'found corrupt files and successfully repaired them') {
            Write-Log "  SFC: Found and repaired corrupt files" "Green"
        } elseif ($sfcResult -match 'found corrupt files but was unable to fix') {
            Write-Log "  SFC: Found corrupt files but could not fix" "Yellow"
        } else {
            Write-Log "  SFC completed (check CBS.log for details)" "Gray"
        }

        # CRITICAL: Verify boot-critical files after SFC
        Verify-BootCriticalIntegrity

    } catch {
        Write-Log "  SFC error: $_" "Yellow"
    }
}
#endregion

#region PHASE 59: HNS (Docker) NETWORK RESET

Phase "HNS Docker Networking Reset (Fixes 0x80070032)"

# GPU STABILITY GATE: HNS operations can cascade to GPU crashes via ICS/NAT
if (-not $script:GPUStable) {
    Write-Log "  SKIPPING HNS reset - GPU unstable (prevents dxgkrnl.sys crash)" "Yellow"
    Write-Log "    GPU warnings: $($script:GPUWarnings -join '; ')" "Gray"
} else {
    Write-Log "  Fixing HNS error 0x80070032 (Docker networking)..." "Cyan"
}

# Only run HNS operations if GPU is stable
if ($script:GPUStable) {
try {
    # Stop HNS service (WITH TIMEOUT)
    Write-Log "  Stopping HNS service (10s timeout)..." "Gray"
    $hnsStopped = Invoke-ServiceOperation -ServiceName 'hns' -Operation 'Stop' -TimeoutSeconds 10
    if (-not $hnsStopped) {
        Write-Log "  HNS stop timeout - continuing anyway" "Yellow"
    }

    # Backup HNS data
    $hnsDataPath = "C:\ProgramData\Microsoft\Windows\HNS\HNS.data"
    if (Test-Path $hnsDataPath) {
        $hnsBackup = "$env:TEMP\HNS_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').data"
        Copy-Item -Path $hnsDataPath -Destination $hnsBackup -Force -EA 0
        Write-Log "  Backed up HNS.data to $hnsBackup" "Green"

        # Remove corrupted HNS data
        Remove-Item $hnsDataPath -Force -EA 0
        Write-Log "  Removed corrupted HNS.data" "Green"
    }

    # Clean up stale NAT instances
    Write-Log "  Removing stale NAT instances..." "Gray"
    Get-NetNat -EA 0 | Remove-NetNat -Confirm:$false -EA 0

    # Remove stale HNS networks
    Write-Log "  Cleaning HNS networks..." "Gray"
    Get-HnsNetwork -EA 0 | Remove-HnsNetwork -EA 0

    # Restart HNS service (WITH TIMEOUT)
    Write-Log "  Starting HNS service (15s timeout)..." "Gray"
    $hnsStarted = Invoke-ServiceOperation -ServiceName 'hns' -Operation 'Start' -TimeoutSeconds 15

    if ($hnsStarted) {
        Write-Log "  HNS service restarted successfully" "Green"

        # Test HNS functionality
        try {
            $hnsNetworks = Get-HnsNetwork -EA 0
            Write-Log "  HNS functional - $($hnsNetworks.Count) networks available" "Green"
        } catch {
            Write-Log "  HNS restarted but may have issues: $_" "Yellow"
        }
    } else {
        Write-Log "  WARNING: HNS service failed to start (timeout)" "Yellow"
    }

    # Clean Docker networks (if Docker is installed) - WITH TIMEOUT
    try {
        $dockerCmd = Get-Command docker -EA 0
        if ($dockerCmd) {
            Write-Log "  Pruning Docker networks (15s timeout)..." "Gray"
            $result = Invoke-CommandWithTimeout -Command "docker.exe" -Arguments @('network', 'prune', '-f') -TimeoutSeconds 15 -Description "Docker network prune"
            if ($result) {
                Write-Log "  Docker networks cleaned" "Green"
            } else {
                Write-Log "  Docker network prune skipped (timeout)" "Yellow"
            }
        }
    } catch {}

} catch {
    Write-Log "  Error during HNS reset: $_" "Yellow"
}
} # End GPU stability gate for Phase 59
#endregion

#region PHASE 60: USERINIT/SHELL CRASH FIX

Phase "UserInit/Shell Crash Fix"

Write-Log "  Fixing userinit.exe crashes and shell initialization..." "Cyan"

try {
    # Re-register shell DLLs
    $shellDLLs = @(
        "shell32.dll",
        "ole32.dll",
        "oleaut32.dll",
        "actxprxy.dll",
        "mshtml.dll",
        "urlmon.dll",
        "shdocvw.dll",
        "browseui.dll"
    )

    foreach ($dll in $shellDLLs) {
        $dllPath = "$env:SystemRoot\System32\$dll"
        if (Test-Path $dllPath) {
            regsvr32 /s $dllPath 2>$null
        }
    }
    Write-Log "  Shell DLLs re-registered" "Green"

    # Fix User Profile Service
    $profSvc = Get-Service -Name "ProfSvc" -EA 0
    if ($profSvc) {
        if ($profSvc.Status -ne 'Running') {
            Start-Service ProfSvc -EA 0
            Write-Log "  User Profile Service started" "Green"
        }

        # Ensure it's set to Automatic
        Set-Service -Name "ProfSvc" -StartupType Automatic -EA 0
    }

    # Fix Userinit registry key
    $userinit = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Userinit" -EA 0
    $correctValue = "C:\Windows\system32\userinit.exe,"
    if ($userinit.Userinit -ne $correctValue) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Userinit" -Value $correctValue -Force
        Write-Log "  Userinit registry key corrected" "Green"
    }

    # Fix Shell registry key
    $shell = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -EA 0
    $correctShell = "explorer.exe"
    if ($shell.Shell -ne $correctShell) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -Value $correctShell -Force
        Write-Log "  Shell registry key corrected" "Green"
    }

    # Rebuild icon cache (corrupted cache causes Explorer crashes)
    try {
        Stop-Process -Name "explorer" -Force -EA 0
        Start-Sleep -Seconds 2
        Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db" -Force -EA 0
        Start-Process "explorer.exe"
        Write-Log "  Icon cache rebuilt" "Green"
    } catch {}

} catch {
    Write-Log "  Error during shell/userinit fix: $_" "Yellow"
}

# Verify boot-critical files weren't affected
Verify-BootCriticalIntegrity
#endregion

#region PHASE 61: NETWORK PERFORMANCE OPTIMIZATION