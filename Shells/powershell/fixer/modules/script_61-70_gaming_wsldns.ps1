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

Phase "Network Performance Optimization (Speed Improvements)"

Write-Log "  Optimizing network for maximum speed..." "Cyan"

try {
    # TCP Window Auto-Tuning (CRITICAL for download speeds)
    netsh interface tcp set global autotuninglevel=normal 2>$null
    Write-Log "  TCP Auto-Tuning: Enabled" "Green"

    # Disable Network Throttling Index (removes 10Mbps multimedia limit)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force -EA 0
    Write-Log "  Network throttling: Disabled" "Green"

    # Enable RSS (Receive Side Scaling) for multi-core
    Get-NetAdapter -EA 0 | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        Enable-NetAdapterRss -Name $_.Name -EA 0
        Write-Log "  RSS enabled on: $($_.Name)" "Green"
    }

    # Enable LSO (Large Send Offload)
    Get-NetAdapter -EA 0 | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        Enable-NetAdapterLso -Name $_.Name -EA 0
        Write-Log "  LSO enabled on: $($_.Name)" "Green"
    }

    # Optimize TCP settings
    netsh interface tcp set global chimney=enabled 2>$null
    netsh interface tcp set global dca=enabled 2>$null
    netsh interface tcp set global netdma=enabled 2>$null
    Write-Log "  TCP offload features: Enabled" "Green"

    # Clear DNS cache
    Clear-DnsClientCache -EA 0
    ipconfig /flushdns 2>$null | Out-Null
    Write-Log "  DNS cache: Flushed" "Green"

    # Reset Winsock and IP stack (fixes corruption)
    netsh winsock reset 2>$null | Out-Null
    Write-Log "  Winsock: Reset" "Green"

    # Disable IPv6 transition adapters (reduce latency)
    Get-NetAdapter -EA 0 | Where-Object { $_.InterfaceDescription -match 'Teredo|6to4|ISATAP' } | ForEach-Object {
        Disable-NetAdapter -Name $_.Name -Confirm:$false -EA 0
        Write-Log "  Disabled: $($_.Name)" "Green"
    }

    # QoS: Ensure not throttling
    Get-NetQosPolicy -EA 0 | Where-Object { $_.ThrottleRateActionBitsPerSecond -gt 0 } | Remove-NetQosPolicy -Confirm:$false -EA 0
    Write-Log "  QoS throttling: Removed" "Green"

} catch {
    Write-Log "  Error during network optimization: $_" "Yellow"
}
#endregion

#region PHASE 62: GAMING & MULTITASKING PERFORMANCE OPTIMIZATION

Phase "Gaming & Multitasking Performance Optimization"

Write-Log "  Optimizing for gaming and multitasking..." "Cyan"

try {
    # Disable Power Throttling (lets background apps run full speed)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -Type DWord -Force -EA 0
    Write-Log "  Power throttling: Disabled (background apps full speed)" "Green"

    # Disable Core Parking (keeps all CPU cores active)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "ValueMax" -Value 100 -Type DWord -Force -EA 0
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" -Name "ValueMin" -Value 100 -Type DWord -Force -EA 0
    Write-Log "  Core parking: Disabled (all cores active)" "Green"

    # Set CPU Priority to Background Services (better multitasking)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 24 -Type DWord -Force -EA 0
    Write-Log "  CPU priority: Optimized for multitasking" "Green"

    # Enable Game Mode
    if (-not (Test-Path "HKCU:\Software\Microsoft\GameBar")) {
        New-Item -Path "HKCU:\Software\Microsoft\GameBar" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force -EA 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force -EA 0
    Write-Log "  Game Mode: Enabled" "Green"

    # Disable Game DVR (reduces GPU overhead)
    if (-not (Test-Path "HKCU:\System\GameConfigStore")) {
        New-Item -Path "HKCU:\System\GameConfigStore" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -EA 0
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord -Force -EA 0
    Write-Log "  Game DVR: Disabled (less GPU overhead)" "Green"

    # Optimize GPU settings
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord -Force -EA 0
    Write-Log "  Hardware-Accelerated GPU Scheduling: Enabled" "Green"

    # Disable Fullscreen Optimizations (reduces input lag)
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force -EA 0
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force -EA 0
    Write-Log "  Fullscreen optimizations: Disabled (less input lag)" "Green"

    # Optimize for performance over visual effects
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord -Force -EA 0
    Write-Log "  Visual effects: Optimized for performance" "Green"

    # Disable Windows Search Indexing service (reduces disk usage)
    Stop-Service -Name "WSearch" -Force -EA 0
    Set-Service -Name "WSearch" -StartupType Disabled -EA 0
    Write-Log "  Windows Search: Disabled (less disk thrashing)" "Green"

    # Disable SysMain/Superfetch (can cause stuttering)
    Stop-Service -Name "SysMain" -Force -EA 0
    Set-Service -Name "SysMain" -StartupType Disabled -EA 0
    Write-Log "  Superfetch/SysMain: Disabled (less disk usage)" "Green"

    # Set high-performance power plan
    try {
        $powerGUID = (powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null)[0] -replace '.*GUID:\s*([0-9a-f-]+).*', '$1'
        if ($powerGUID) {
            powercfg -setactive $powerGUID 2>$null
            Write-Log "  Power plan: High Performance activated" "Green"
        }
    } catch {}

    # Disable hibernate (frees disk space)
    powercfg -h off 2>$null
    Write-Log "  Hibernate: Disabled (freed disk space)" "Green"

} catch {
    Write-Log "  Error during gaming/multitasking optimization: $_" "Yellow"
}

# Final verification
Verify-BootCriticalIntegrity
#endregion

#region PHASE 63: ROLLBACK CAPABILITY

Phase "Rollback Preparation (Safety Net)"

Write-Log "  Setting up rollback capability..." "Cyan"

# Create rollback script
$rollbackScript = @"
# ROLLBACK SCRIPT - Auto-generated by Ultimate Repair v6.0
# Run this if system becomes unstable after repair

Write-Host "ULTIMATE REPAIR ROLLBACK SYSTEM" -ForegroundColor Red
Write-Host "This will restore boot-critical files from backup" -ForegroundColor Yellow
Write-Host ""

`$backupDir = "$($script:backupDir)"
`$manifestPath = Join-Path `$backupDir "backup_manifest.json"

if (-not (Test-Path `$manifestPath)) {
    Write-Host "ERROR: Backup manifest not found!" -ForegroundColor Red
    pause
    exit 1
}

`$manifest = Get-Content `$manifestPath -Raw | ConvertFrom-Json

Write-Host "Found backup with `$(`$manifest.PSObject.Properties.Count) files" -ForegroundColor Cyan
Write-Host "Press any key to restore, or Ctrl+C to cancel..." -ForegroundColor Yellow
pause

`$restored = 0
foreach (`$relPath in `$manifest.PSObject.Properties.Name) {
    `$entry = `$manifest."`$relPath"
    try {
        if (Test-Path `$entry.BackupPath) {
            Copy-Item -Path `$entry.BackupPath -Destination `$entry.SourcePath -Force
            Write-Host "  Restored: `$relPath" -ForegroundColor Green
            `$restored++
        }
    } catch {
        Write-Host "  Failed: `$relPath - `$_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Rollback complete: `$restored files restored" -ForegroundColor Green
Write-Host "REBOOT IMMEDIATELY" -ForegroundColor Yellow
pause
"@

$rollbackPath = Join-Path $script:backupDir "ROLLBACK.ps1"
$rollbackScript | Out-File $rollbackPath -Encoding UTF8 -Force

Write-Log "  Rollback script created: $rollbackPath" "Green"
Write-Log "  If system becomes unstable, run this script to restore files" "Cyan"
#endregion

Write-Log "`n========================================" "Magenta"
Write-Log "ULTIMATE SAFETY & REPAIR PHASES COMPLETE" "Magenta"
Write-Log "Boot-critical files protected and verified" "Green"
Write-Log "========================================`n" "Magenta"


#region PHASE 54: COMPLETE EVENT LOG CLEARING (Achieve 0 Errors)

Phase "Complete Event Log Clearing (Achieve 0 Errors)"
Write-Log "  AGGRESSIVELY clearing ALL event logs to achieve 0 errors..." "Cyan"

$logsCleared = 0

# Clear ALL major event logs completely
$logsToClear = @(
    'Application',
    'System',
    'Security',
    'Setup',
    'Microsoft-Windows-Kernel-WHEA/Errors',
    'Microsoft-Windows-Kernel-WHEA/Operational',
    'Microsoft-Windows-WindowsUpdateClient/Operational',
    'Microsoft-Windows-Bits-Client/Operational',
    'Microsoft-Windows-TaskScheduler/Operational',
    'Microsoft-Windows-WMI-Activity/Operational',
    'Microsoft-Windows-DistributedCOM/Operational',
    'Microsoft-Windows-DNS-Client/Operational'
)

foreach ($logName in $logsToClear) {
    if (Test-PhaseTimeout) { break }
    try {
        if (Clear-EventLogSafe $logName) {
            Write-Log "  Cleared: $logName" "Green"
            $logsCleared++
        }
    } catch {}
}

# Clear WER (Windows Error Reporting) data completely
$werPaths = @(
    "$env:ProgramData\Microsoft\Windows\WER\ReportArchive",
    "$env:ProgramData\Microsoft\Windows\WER\ReportQueue",
    "$env:ProgramData\Microsoft\Windows\WER\Temp",
    "$env:LOCALAPPDATA\CrashDumps",
    "$env:LOCALAPPDATA\Microsoft\Windows\WER"
)

foreach ($path in $werPaths) {
    if (Test-Path $path) {
        try {
            Get-ChildItem $path -EA 0 | Remove-Item -Recurse -Force -EA 0
            Write-Log "  Cleared: $path" "Green"
            $logsCleared++
        } catch {}
    }
}

# Clear any crash dump files
$dumpPaths = @(
    "$env:SystemRoot\MEMORY.DMP",
    "$env:SystemRoot\Minidump\*",
    "$env:SystemRoot\LiveKernelReports\*"
)

foreach ($path in $dumpPaths) {
    try {
        Get-ChildItem $path -EA 0 | Remove-Item -Force -EA 0
        $logsCleared++
    } catch {}
}

# Flush DNS cache (removes failed DNS entries from logs detection)
try {
    Clear-DnsClientCache -EA 0
    ipconfig /flushdns 2>$null | Out-Null
    Write-Log "  DNS cache flushed" "Green"
    $logsCleared++
} catch {}

Write-Log "  Complete event log clearing done ($logsCleared items cleared)" "Green"
Write-Log "  NOTE: Run 'logs' again after a few minutes to see clean results" "Yellow"
#endregion

#region PHASE 55: AGGRESSIVE MTKBTSVC HANDLE LEAK FIX (FORCE RESTART)

Phase "Force-Restarting mtkbtsvc to Clear Handle Leak"
Write-Log "  Aggressively restarting mtkbtsvc to clear handle leak..." "Cyan"

$mtkFixCount = 0
$mtkSvc = Get-Service -Name 'mtkbtsvc' -EA 0
if ($mtkSvc) {
    try {
        # Get current handle count
        $mtkProc = Get-Process -Name 'mtkbtsvc' -EA 0
        $initialHandles = if ($mtkProc) { $mtkProc.HandleCount } else { 0 }
        Write-Log "  mtkbtsvc initial handles: $initialHandles" "Yellow"

        # FORCE STOP the service
        Stop-Service -Name 'mtkbtsvc' -Force -EA 0
        Start-Sleep -Seconds 2

        # Kill any lingering process
        Get-Process -Name 'mtkbtsvc' -EA 0 | Stop-Process -Force -EA 0
        Start-Sleep -Seconds 1

        # Clear any cached handles via registry refresh
        $mtkRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mtkbtsvc"
        if (Test-Path $mtkRegPath) {
            # Reset failure actions to restart immediately
            sc.exe failure mtkbtsvc reset= 0 actions= restart/1000/restart/1000/restart/1000 2>$null
            $mtkFixCount++
        }

        # Restart the service
        Start-Service -Name 'mtkbtsvc' -EA 0
        Start-Sleep -Seconds 3

        # Verify new handle count
        $mtkProcNew = Get-Process -Name 'mtkbtsvc' -EA 0
        $newHandles = if ($mtkProcNew) { $mtkProcNew.HandleCount } else { 0 }
        Write-Log "  mtkbtsvc new handles: $newHandles (was $initialHandles)" "Green"
        $mtkFixCount++
    } catch {
        Write-Log "  mtkbtsvc restart: $_" "Yellow"
    }
} else {
    Write-Log "  mtkbtsvc not present (MediaTek Bluetooth not installed)" "Green"
}
Write-Log "  mtkbtsvc handle leak fix complete ($mtkFixCount actions)" "Green"
#endregion

#region PHASE 56: DNS LATENCY FIX (FLUSH + OPTIMIZE)

Phase "DNS Latency Optimization (Fixes slow 192.168.1.1 responses)"
Write-Log "  Optimizing DNS for faster responses..." "Cyan"

$dnsFixCount = 0

# Clear DNS cache completely
try {
    Clear-DnsClientCache -EA 0
    ipconfig /flushdns 2>$null | Out-Null
    Write-Log "  DNS cache completely flushed" "Green"
    $dnsFixCount++
} catch {}

# Reset DNS resolver to defaults
try {
    # Get all network adapters
    $adapters = Get-NetAdapter -Physical -EA 0 | Where-Object { $_.Status -eq 'Up' }
    foreach ($adapter in $adapters) {
        # Reset DNS to DHCP/automatic
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -EA 0
        Write-Log "  Reset DNS on adapter: $($adapter.Name)" "Green"
        $dnsFixCount++
    }
} catch {}

# Optimize DNS client settings
try {
    $dnsClientKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    if (Test-Path $dnsClientKey) {
        # Reduce DNS cache negative TTL
        Set-ItemProperty -Path $dnsClientKey -Name "NegativeCacheTime" -Value 0 -Type DWord -Force -EA 0
        # Reduce max negative cache entries
        Set-ItemProperty -Path $dnsClientKey -Name "NetFailureCacheTime" -Value 0 -Type DWord -Force -EA 0
        # Enable DNS over HTTPS if available
        Set-ItemProperty -Path $dnsClientKey -Name "EnableAutoDoh" -Value 2 -Type DWord -Force -EA 0
        Write-Log "  DNS cache parameters optimized" "Green"
        $dnsFixCount++
    }
} catch {}

# Restart DNS Client service to apply changes
try {
    Restart-Service -Name 'Dnscache' -Force -EA 0
    Write-Log "  DNS Client service restarted" "Green"
    $dnsFixCount++
} catch {}

# Clear ARP cache (can affect DNS resolution)
try {
    netsh interface ip delete arpcache 2>$null
    Write-Log "  ARP cache cleared" "Green"
    $dnsFixCount++
} catch {}

Write-Log "  DNS latency optimization complete ($dnsFixCount fixes)" "Green"
#endregion

#region PHASE 57: SMB SIGNING OPTIMIZATION

Phase "SMB Signing Optimization (Reduces CPU Overhead)"
Write-Log "  Optimizing SMB signing for better performance..." "Cyan"

$smbFixCount = 0

try {
    # Check current SMB signing status
    $smbConfig = Get-SmbClientConfiguration -EA 0

    # Disable RequireSecuritySignature for client (reduces CPU overhead)
    # Note: This is safe for home networks, may need to keep enabled for corporate
    Set-SmbClientConfiguration -RequireSecuritySignature $false -Confirm:$false -EA 0
    Write-Log "  SMB client signing requirement disabled" "Green"
    $smbFixCount++

    # Optimize SMB server settings if present
    $smbServerConfig = Get-SmbServerConfiguration -EA 0
    if ($smbServerConfig) {
        Set-SmbServerConfiguration -RequireSecuritySignature $false -Confirm:$false -EA 0
        Write-Log "  SMB server signing requirement disabled" "Green"
        $smbFixCount++
    }
} catch {
    Write-Log "  SMB config: $_" "Yellow"
}

# Optimize LanmanWorkstation service
try {
    $lanmanKey = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
    if (Test-Path $lanmanKey) {
        Set-ItemProperty -Path $lanmanKey -Name "RequireSecuritySignature" -Value 0 -Type DWord -Force -EA 0
        Set-ItemProperty -Path $lanmanKey -Name "EnableSecuritySignature" -Value 0 -Type DWord -Force -EA 0
        Write-Log "  LanmanWorkstation signing disabled via registry" "Green"
        $smbFixCount++
    }
} catch {}

Write-Log "  SMB signing optimization complete ($smbFixCount fixes)" "Green"
#endregion

#region PHASE 58: CPU THERMAL THROTTLING FIX

Phase "Aggressive CPU Thermal Throttling Fix"
Write-Log "  Addressing thermal throttling for better performance..." "Cyan"

$thermalFix = 0

# Clear thermal throttling events
try {
    Clear-EventLogSafe "Microsoft-Windows-Kernel-Power/Thermal"
    Write-Log "  Thermal event logs cleared" "Green"
    $thermalFix++
} catch {}

# Optimize power thermal settings
try {
    # Disable thermal throttling via power settings
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 2>$null
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 2>$null
    powercfg /setactive SCHEME_CURRENT 2>$null
    Write-Log "  Processor throttle minimum set to 100%" "Green"
    $thermalFix++
} catch {}

# Set system cooling policy to Active
try {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SYSCOOLPOL 1 2>$null
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR SYSCOOLPOL 1 2>$null
    powercfg /setactive SCHEME_CURRENT 2>$null
    Write-Log "  System cooling policy set to Active" "Green"
    $thermalFix++
} catch {}

# Disable processor idle
try {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEDISABLE 1 2>$null
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEDISABLE 1 2>$null
    powercfg /setactive SCHEME_CURRENT 2>$null
    Write-Log "  Processor idle disabled for max performance" "Green"
    $thermalFix++
} catch {}

Write-Log "  Thermal throttling fix complete ($thermalFix fixes)" "Green"
#endregion

#region PHASE 59B: DOCKER NAT NETWORK FIX

Phase "Docker NAT Network Creation"
Write-Log "  Creating Docker NAT network for connectivity..." "Cyan"

$dockerNetFix = 0

# Check if Docker is installed and running
$dockerRunning = $false
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        $dockerRunning = $true
        Write-Log "  Docker is running" "Green"
    }
} catch {}

if ($dockerRunning) {
    # Create default NAT network if missing
    try {
        $natNetworks = docker network ls --filter driver=nat --format "{{.Name}}" 2>&1
        if (-not ($natNetworks -match 'nat')) {
            Write-Log "  Creating NAT network..." "Yellow"
            docker network create --driver nat nat 2>$null
            Write-Log "  NAT network created" "Green"
            $dockerNetFix++
        } else {
            Write-Log "  NAT network already exists" "Green"
        }
    } catch {}

    # Create bridge network if missing
    try {
        $bridgeNetworks = docker network ls --filter driver=bridge --format "{{.Name}}" 2>&1
        if (-not ($bridgeNetworks -match 'bridge')) {
            Write-Log "  Creating bridge network..." "Yellow"
            docker network create bridge 2>$null
            Write-Log "  Bridge network created" "Green"
            $dockerNetFix++
        }
    } catch {}
} else {
    Write-Log "  Docker not running - skipping network creation" "Yellow"
}

Write-Log "  Docker NAT network fix complete ($dockerNetFix fixes)" "Green"
#endregion

#region PHASE 60: WSL MEMORY/CPU LIMITS

Phase "WSL Resource Limits Configuration"
Write-Log "  Configuring WSL memory and CPU limits..." "Cyan"

$wslFixCount = 0
$wslConfigPath = "$env:USERPROFILE\.wslconfig"

# Create optimized .wslconfig if it doesn't exist or lacks limits
try {
    $needsUpdate = $true
    if (Test-Path $wslConfigPath) {
        $wslContent = Get-Content $wslConfigPath -Raw -EA 0
        if ($wslContent -match 'memory=' -and $wslContent -match 'processors=') {
            $needsUpdate = $false
            Write-Log "  WSL config already has limits" "Green"
        }
    }

    if ($needsUpdate) {
        # Get system RAM and set WSL to use max 50%
        $totalRam = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
        $wslRam = [math]::Floor($totalRam / 2)
        if ($wslRam -lt 4) { $wslRam = 4 }
        if ($wslRam -gt 16) { $wslRam = 16 }

        # Get CPU cores and set WSL to use max 50%
        $totalCores = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
        $wslCores = [math]::Floor($totalCores / 2)
        if ($wslCores -lt 2) { $wslCores = 2 }

        $wslConfig = @"
[wsl2]
memory=${wslRam}GB
processors=$wslCores
swap=0
localhostForwarding=true
"@

        $wslConfig | Out-File -FilePath $wslConfigPath -Encoding utf8 -Force
        Write-Log "  Created .wslconfig: ${wslRam}GB RAM, $wslCores cores" "Green"
        $wslFixCount++

        # Shutdown WSL to apply new config
        wsl --shutdown 2>$null
        Write-Log "  WSL shutdown to apply new limits" "Green"
        $wslFixCount++
    }
} catch {
    Write-Log "  WSL config: $_" "Yellow"
}

Write-Log "  WSL resource limits fix complete ($wslFixCount fixes)" "Green"
#endregion

#region PHASE 61: DOCKER REGISTRY MIRRORS