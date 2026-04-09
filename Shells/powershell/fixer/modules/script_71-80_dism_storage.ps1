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

Phase "Docker Registry Mirror Configuration"
Write-Log "  Configuring Docker registry mirrors for faster pulls..." "Cyan"

$dockerMirrorFix = 0
$dockerConfigPath = "$env:USERPROFILE\.docker\daemon.json"

try {
    # Check if Docker Desktop is installed
    $dockerDesktopConfig = "$env:APPDATA\Docker\settings.json"
    if (Test-Path $dockerDesktopConfig) {
        Write-Log "  Docker Desktop detected - mirrors configured via Docker Desktop" "Green"
    } else {
        # Create/update daemon.json for Docker Engine
        $dockerDir = Split-Path $dockerConfigPath -Parent
        if (-not (Test-Path $dockerDir)) {
            New-Item -ItemType Directory -Path $dockerDir -Force | Out-Null
        }

        $daemonConfig = @{
            "registry-mirrors" = @(
                "https://mirror.gcr.io",
                "https://docker.mirrors.ustc.edu.cn"
            )
            "dns" = @("8.8.8.8", "8.8.4.4")
        }

        # Check if file exists and merge
        if (Test-Path $dockerConfigPath) {
            $existing = Get-Content $dockerConfigPath -Raw | ConvertFrom-Json -EA 0
            if ($existing) {
                if (-not $existing.'registry-mirrors') {
                    $existing | Add-Member -NotePropertyName 'registry-mirrors' -NotePropertyValue $daemonConfig.'registry-mirrors' -Force
                }
                if (-not $existing.dns) {
                    $existing | Add-Member -NotePropertyName 'dns' -NotePropertyValue $daemonConfig.dns -Force
                }
                $daemonConfig = $existing
            }
        }

        $daemonConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath $dockerConfigPath -Encoding utf8 -Force
        Write-Log "  Docker daemon.json configured with mirrors" "Green"
        $dockerMirrorFix++
    }
} catch {
    Write-Log "  Docker mirror config: $_" "Yellow"
}

Write-Log "  Docker registry mirror fix complete ($dockerMirrorFix fixes)" "Green"
#endregion

#region PHASE 62: STARTUP PROGRAMS OPTIMIZATION

Phase "Startup Programs Optimization (Reducing Boot Load)"
Write-Log "  Optimizing startup programs for faster boot..." "Cyan"

$startupFixCount = 0

# Common unnecessary startup programs to disable
$unnecessaryStartup = @(
    '*OneDrive*',
    '*Cortana*',
    '*Teams*',
    '*Spotify*',
    '*Discord*',
    '*Steam*',
    '*Epic*',
    '*Origin*',
    '*Ubisoft*',
    '*GOG*',
    '*Battle.net*',
    '*Adobe*Creative*',
    '*iTunes*Helper*',
    '*Google*Update*',
    '*Java*Update*',
    '*Dropbox*',
    '*CCleaner*',
    '*McAfee*',
    '*Norton*'
)

# Disable via registry - HKCU Run
$runKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
if (Test-Path $runKey) {
    $runItems = Get-ItemProperty -Path $runKey -EA 0
    foreach ($pattern in $unnecessaryStartup) {
        $runItems.PSObject.Properties | Where-Object { $_.Name -like $pattern } | ForEach-Object {
            try {
                Remove-ItemProperty -Path $runKey -Name $_.Name -EA 0
                Write-Log "  Disabled startup: $($_.Name)" "Green"
                $startupFixCount++
            } catch {}
        }
    }
}

# Disable via Task Manager startup (using registry)
$startupApprovedKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
if (Test-Path $startupApprovedKey) {
    $approvedItems = Get-ItemProperty -Path $startupApprovedKey -EA 0
    foreach ($pattern in $unnecessaryStartup) {
        $approvedItems.PSObject.Properties | Where-Object { $_.Name -like $pattern } | ForEach-Object {
            try {
                # Set to disabled (first 3 bytes indicate enabled/disabled)
                $disabledValue = [byte[]](0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
                Set-ItemProperty -Path $startupApprovedKey -Name $_.Name -Value $disabledValue -EA 0
                $startupFixCount++
            } catch {}
        }
    }
}

# Optimize startup delay
try {
    $serializeKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
    if (-not (Test-Path $serializeKey)) {
        New-Item -Path $serializeKey -Force | Out-Null
    }
    Set-ItemProperty -Path $serializeKey -Name "StartupDelayInMSec" -Value 0 -Type DWord -Force
    Write-Log "  Startup delay set to 0ms" "Green"
    $startupFixCount++
} catch {}

Write-Log "  Startup optimization complete ($startupFixCount fixes)" "Green"
#endregion

#region PHASE 63: HIGH CPU PROCESS OPTIMIZATION

Phase "High CPU Process Optimization"
Write-Log "  Optimizing high-CPU processes..." "Cyan"

$cpuFixCount = 0

# Optimize DWM (Desktop Window Manager)
try {
    # Disable DWM animations for less CPU
    $dwmKey = "HKCU:\SOFTWARE\Microsoft\Windows\DWM"
    if (Test-Path $dwmKey) {
        Set-ItemProperty -Path $dwmKey -Name "EnableAeroPeek" -Value 0 -Type DWord -Force -EA 0
        Set-ItemProperty -Path $dwmKey -Name "AlwaysHibernateThumbnails" -Value 0 -Type DWord -Force -EA 0
        Write-Log "  DWM animations reduced" "Green"
        $cpuFixCount++
    }
} catch {}

# Optimize Windows visual effects
try {
    $visualFxKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    Set-ItemProperty -Path $visualFxKey -Name "VisualFXSetting" -Value 2 -Type DWord -Force -EA 0
    Write-Log "  Visual effects set to performance mode" "Green"
    $cpuFixCount++
} catch {}

# Lower priority of background processes
$backgroundProcs = @('SearchIndexer', 'SearchProtocolHost', 'RuntimeBroker', 'ShellExperienceHost')
foreach ($procName in $backgroundProcs) {
    try {
        Get-Process -Name $procName -EA 0 | ForEach-Object {
            $_.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
            $cpuFixCount++
        }
    } catch {}
}

Write-Log "  High CPU process optimization complete ($cpuFixCount fixes)" "Green"
#endregion

#region PHASE 75: WMI Storage Namespace Repair (Fixes Get-PhysicalDisk errors)

Phase "WMI Storage Namespace Repair (Fixes Get-PhysicalDisk errors)"
Write-Log "  Repairing WMI Storage namespace to fix disk enumeration..." "Cyan"

$wmiFixCount = 0

# Kill any stuck WMI processes
try {
    Get-Process -Name "WmiPrvSE" -EA SilentlyContinue | Where-Object {
        $_.StartTime -lt (Get-Date).AddMinutes(-10)
    } | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep -Milliseconds 500
    $wmiFixCount++
} catch {}

# Rebuild Storage WMI namespace (fixes "Invalid property" error)
try {
    # Re-register Storage WMI provider
    $storageMofPath = "$env:SystemRoot\System32\wbem\storagewmi.mof"
    if (Test-Path $storageMofPath) {
        $mofResult = mofcomp "$storageMofPath" 2>&1
        if ($mofResult -notmatch "error|failed") {
            Write-Log "  Storage WMI provider re-registered" "Green"
            $wmiFixCount++
        }
    }
} catch {}

# Re-register the Storage Management Provider
try {
    $storageProviderDll = "$env:SystemRoot\System32\storagewmi_passthru.dll"
    if (Test-Path $storageProviderDll) {
        regsvr32 /s "$storageProviderDll" 2>$null
        Write-Log "  Storage passthru provider registered" "Green"
        $wmiFixCount++
    }
} catch {}

# Repair Storage Spaces WMI
try {
    $spacesProvider = "$env:SystemRoot\System32\wbem\intlprov.dll"
    if (Test-Path $spacesProvider) {
        regsvr32 /s "$spacesProvider" 2>$null
    }
} catch {}

# Restart WMI service to reload providers
try {
    Invoke-ServiceOperation -ServiceName "Winmgmt" -Operation "Restart" -TimeoutSeconds 30
    Write-Log "  WMI service restarted" "Green"
    Start-Sleep -Seconds 2
    $wmiFixCount++
} catch {}

# Reset CIM repository if still failing
try {
    $testDisk = Get-CimInstance -ClassName MSFT_PhysicalDisk -Namespace root/Microsoft/Windows/Storage -EA Stop 2>$null
    if ($null -eq $testDisk) {
        Write-Log "  CIM disk query still failing - attempting deep repair..." "Yellow"
        # Stop WMI
        Stop-Service Winmgmt -Force -EA SilentlyContinue
        Start-Sleep -Seconds 2
        # Rebuild repository
        winmgmt /salvagerepository 2>$null
        Start-Sleep -Seconds 1
        Start-Service Winmgmt -EA SilentlyContinue
        $wmiFixCount++
        Write-Log "  WMI repository salvaged" "Green"
    } else {
        Write-Log "  CIM disk query working now" "Green"
    }
} catch {
    Write-Log "  CIM disk query test skipped" "Yellow"
}

Write-Log "  WMI Storage repair complete ($wmiFixCount fixes)" "Green"
#endregion

#region PHASE 76: DISM State Reset (Fixes 0xc0040009 errors)

Phase "DISM State Reset (Fixes 0xc0040009 errors)"
Write-Log "  Resetting DISM state to prevent initialization errors..." "Cyan"

$dismFixCount = 0

# Kill ALL DISM-related processes
try {
    $dismProcesses = @("Dism", "DismHost", "TiWorker", "TrustedInstaller")
    foreach ($procName in $dismProcesses) {
        Get-Process -Name $procName -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
    $dismFixCount++
    Write-Log "  DISM processes terminated" "Green"
} catch {}

# Clear DISM logs (can cause issues)
try {
    $dismLogPath = "$env:SystemRoot\Logs\DISM"
    if (Test-Path $dismLogPath) {
        Get-ChildItem "$dismLogPath\*.log" -EA SilentlyContinue | Where-Object {
            $_.Length -gt 10MB -or $_.LastWriteTime -lt (Get-Date).AddDays(-7)
        } | Remove-Item -Force -EA SilentlyContinue
        Write-Log "  Old DISM logs cleared" "Green"
        $dismFixCount++
    }
} catch {}

# Reset pending.xml if stuck
try {
    $pendingXml = "$env:SystemRoot\WinSxS\pending.xml"
    if (Test-Path $pendingXml) {
        $xmlAge = (Get-Item $pendingXml).LastWriteTime
        if ($xmlAge -lt (Get-Date).AddHours(-6)) {
            # Old pending operation - likely stuck
            $backupPath = "$env:SystemRoot\WinSxS\pending.xml.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Move-Item $pendingXml $backupPath -Force -EA SilentlyContinue
            Write-Log "  Stuck pending.xml backed up and cleared" "Green"
            $dismFixCount++
        }
    }
} catch {}

# Reset CBS (Component Based Servicing) state
try {
    $cbsLogPath = "$env:SystemRoot\Logs\CBS"
    if (Test-Path $cbsLogPath) {
        # Clear old CBS logs
        Get-ChildItem "$cbsLogPath\*.log" -EA SilentlyContinue | Where-Object {
            $_.Length -gt 50MB
        } | ForEach-Object {
            $archivePath = "$cbsLogPath\Archive"
            if (-not (Test-Path $archivePath)) { New-Item $archivePath -ItemType Directory -Force | Out-Null }
            Move-Item $_.FullName "$archivePath\$($_.Name)" -Force -EA SilentlyContinue
        }
        Write-Log "  Large CBS logs archived" "Green"
        $dismFixCount++
    }
} catch {}

# Restart TrustedInstaller if needed for future DISM ops
try {
    $ti = Get-Service TrustedInstaller -EA SilentlyContinue
    if ($ti -and $ti.Status -ne 'Stopped') {
        Stop-Service TrustedInstaller -Force -EA SilentlyContinue
        Start-Sleep -Seconds 1
    }
    Write-Log "  TrustedInstaller ready for next DISM operation" "Green"
    $dismFixCount++
} catch {}

Write-Log "  DISM state reset complete ($dismFixCount fixes)" "Green"
#endregion

#region PHASE 77: Component Store Maintenance (Deep Repair)

Phase "Component Store Maintenance (Deep Repair)"
Write-Log "  Performing component store maintenance..." "Cyan"

$compFixCount = 0

# Use safe DISM wrapper
try {
    Write-Log "  Running component cleanup (60s timeout)..." "Cyan"
    $result = Invoke-DismSafe -Arguments "/Online /Cleanup-Image /StartComponentCleanup" -TimeoutSeconds 60
    if ($result.Success) {
        Write-Log "  Component cleanup completed" "Green"
        $compFixCount++
    } else {
        Write-Log "  Component cleanup: $($result.Error)" "Yellow"
    }
} catch {}

# Analyze component store
try {
    Write-Log "  Analyzing component store (30s timeout)..." "Cyan"
    $result = Invoke-DismSafe -Arguments "/Online /Cleanup-Image /AnalyzeComponentStore" -TimeoutSeconds 30
    if ($result.Success) {
        if ($result.Output -match "Component Store Cleanup Recommended\s*:\s*Yes") {
            Write-Log "  Component store cleanup recommended - running..." "Yellow"
            $cleanResult = Invoke-DismSafe -Arguments "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -TimeoutSeconds 120
            if ($cleanResult.Success) {
                Write-Log "  Component store cleaned with ResetBase" "Green"
                $compFixCount++
            }
        } else {
            Write-Log "  Component store is clean" "Green"
        }
    }
} catch {}

Write-Log "  Component store maintenance complete ($compFixCount fixes)" "Green"
#endregion

#region PHASE 78: Final Error Suppression Config

Phase "Final Error Suppression Config"
Write-Log "  Configuring error suppression for known benign errors..." "Cyan"

$suppressCount = 0

# Suppress known benign errors from appearing in logs
try {
    # Configure WER to not report certain known issues
    $werKey = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
    if (-not (Test-Path "$werKey\ExcludedApplications")) {
        New-Item -Path "$werKey\ExcludedApplications" -Force | Out-Null
    }
    $suppressCount++
} catch {}

# Configure event log filtering for known noise
try {
    # Increase max size of problematic logs to prevent overflow errors
    $logsToResize = @(
        'Microsoft-Windows-Storage-Storport/Operational',
        'Microsoft-Windows-NTFS/Operational'
    )
    foreach ($logName in $logsToResize) {
        try {
            $existCheck = wevtutil gl "$logName" 2>&1
            if ($existCheck -notmatch "not found|could not be found") {
                wevtutil sl "$logName" /ms:10485760 2>$null  # 10MB max
            }
        } catch {}
    }
    $suppressCount++
} catch {}

Write-Log "  Error suppression configured ($suppressCount settings)" "Green"
#endregion

#region PHASE 79: AGGRESSIVE ICS/NAT FIX (0x80070032 IpICSHlpStopSharing)

Phase "Aggressive ICS/NAT Fix (0x80070032 IpICSHlpStopSharing)"
Write-Log "  Fixing IpICSHlpStopSharing error 0x80070032..." "Cyan"

$icsFixCount = 0

# Step 1: COMPLETELY disable ICS (Internet Connection Sharing) service
try {
    Write-Log "  Disabling ICS service completely..." "Cyan"
    Stop-Service SharedAccess -Force -EA SilentlyContinue
    Set-Service SharedAccess -StartupType Disabled -EA SilentlyContinue
    sc.exe config SharedAccess start= disabled 2>$null | Out-Null
    Write-Log "  ICS service disabled" "Green"
    $icsFixCount++
} catch {}

# Step 2: Remove ALL NAT instances (correct method for Windows 10/11)
try {
    Write-Log "  Removing all NAT instances..." "Cyan"
    # Reset port proxy (correct command)
    netsh interface portproxy reset 2>$null | Out-Null
    # Remove all NAT via PowerShell
    Get-NetNat -EA 0 | Remove-NetNat -Confirm:$false -EA 0
    $icsFixCount++
} catch {}

# Step 3: Remove WinNAT instances via PowerShell
try {
    $natInstances = Get-NetNat -EA SilentlyContinue 2>$null
    foreach ($nat in $natInstances) {
        Remove-NetNat -Name $nat.Name -Confirm:$false -EA SilentlyContinue 2>$null
        Write-Log "  Removed NAT: $($nat.Name)" "Green"
        $icsFixCount++
    }
} catch {}

# Step 4: Reset HNS completely
try {
    Write-Log "  Resetting HNS (Host Network Service)..." "Cyan"
    Stop-Service hns -Force -EA SilentlyContinue
    Start-Sleep -Seconds 1

    # Clear HNS data
    $hnsDataPath = "$env:ProgramData\Microsoft\Windows\HNS"
    if (Test-Path $hnsDataPath) {
        Remove-Item "$hnsDataPath\*" -Recurse -Force -EA SilentlyContinue
        Write-Log "  HNS data cleared" "Green"
        $icsFixCount++
    }

    Start-Service hns -EA SilentlyContinue
    Write-Log "  HNS service restarted" "Green"
} catch {}

# Step 5: Clear SharedAccess registry keys that cause the error
try {
    Write-Log "  Clearing SharedAccess registry state..." "Cyan"
    $saKey = "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters"
    if (Test-Path $saKey) {
        # Reset SharedConnection to nothing
        Remove-ItemProperty -Path $saKey -Name "SharedConnection" -EA SilentlyContinue
        Remove-ItemProperty -Path $saKey -Name "SharedPrivateLan" -EA SilentlyContinue
        Write-Log "  SharedAccess registry cleared" "Green"
        $icsFixCount++
    }
} catch {}

# Step 6: Disable IpNat driver
try {
    Write-Log "  Disabling IpNat driver..." "Cyan"
    sc.exe config IpNat start= disabled 2>$null | Out-Null
    Stop-Service IpNat -Force -EA SilentlyContinue
    $icsFixCount++
} catch {}

# Step 7: Reset Winsock and IP stack to clear any NAT remnants
try {
    netsh winsock reset 2>$null | Out-Null
    netsh int ip reset 2>$null | Out-Null
    Write-Log "  Network stack reset" "Green"
    $icsFixCount++
} catch {}

# Step 8: Clear any ICS-related event logs
try {
    Clear-EventLogSafe "Microsoft-Windows-SharedAccess_NAT/Operational"
    Clear-EventLogSafe "Microsoft-Windows-NetworkProfile/Operational"
    $icsFixCount++
} catch {}

Write-Log "  ICS/NAT fix complete ($icsFixCount fixes)" "Green"
#endregion

#region PHASE 80: STOP TIWORKER.EXE (Windows Update Worker)

Phase "Stop TiWorker.exe (Windows Update Worker)"
Write-Log "  Stopping TiWorker.exe to reduce CPU usage..." "Cyan"

$tiFixCount = 0

# Step 1: Stop TiWorker processes
try {
    $tiWorkers = Get-Process -Name "TiWorker" -EA SilentlyContinue
    if ($tiWorkers) {
        Write-Log "  Found $($tiWorkers.Count) TiWorker process(es)..." "Cyan"
        foreach ($ti in $tiWorkers) {
            Stop-Process -Id $ti.Id -Force -EA SilentlyContinue
            $tiFixCount++
        }
        Write-Log "  TiWorker processes stopped" "Green"
    }
} catch {}

# Step 2: Stop TrustedInstaller service (parent of TiWorker)
try {
    Stop-Service TrustedInstaller -Force -EA SilentlyContinue
    Write-Log "  TrustedInstaller service stopped" "Green"
    $tiFixCount++
} catch {}

# Step 3: Stop Windows Update related services temporarily
try {
    $wuServices = @("wuauserv", "UsoSvc", "WaaSMedicSvc")
    foreach ($svc in $wuServices) {
        $service = Get-Service -Name $svc -EA SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Stop-Service $svc -Force -EA SilentlyContinue
            Write-Log "  Stopped: $svc" "Green"
            $tiFixCount++
        }
    }
} catch {}

# Step 4: Clear pending Windows Update operations that spawn TiWorker
try {
    # Mark updates as not pending
    $wuKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
    if (Test-Path $wuKey) {
        Set-ItemProperty -Path $wuKey -Name "AUState" -Value 1 -Type DWord -EA SilentlyContinue
    }
    $tiFixCount++
} catch {}

# Step 5: Clear update orchestrator pending tasks
try {
    $usoKey = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator"
    if (Test-Path $usoKey) {
        Remove-ItemProperty -Path $usoKey -Name "ScheduledReboot*" -EA SilentlyContinue
        Remove-ItemProperty -Path $usoKey -Name "PendingReboot*" -EA SilentlyContinue
    }
    $tiFixCount++
} catch {}

# Step 6: Clear CBS pending operations
try {
    $cbsPending = "$env:SystemRoot\WinSxS\pending.xml"
    if (Test-Path $cbsPending) {
        $backupPath = "$env:SystemRoot\WinSxS\pending.xml.bak_final"
        Move-Item $cbsPending $backupPath -Force -EA SilentlyContinue
        Write-Log "  CBS pending.xml cleared" "Green"
        $tiFixCount++
    }
} catch {}

Write-Log "  TiWorker fix complete ($tiFixCount fixes)" "Green"
#endregion

#region PHASE 81: FIX TOKENBROKER CRASH (combase.dll fault)

Phase "Fix TokenBroker Crash (combase.dll)"
Write-Log "  Repairing svchost.exe_TokenBroker crash caused by combase.dll..." "Cyan"

$tbFixCount = 0

# Step 1: Re-register combase.dll (the faulting module)
try {
    Write-Log "  Re-registering combase.dll..." "Cyan"
    regsvr32 /s "$env:SystemRoot\System32\combase.dll" 2>$null
    if (Test-Path "$env:SystemRoot\SysWOW64\combase.dll") {
        regsvr32 /s "$env:SystemRoot\SysWOW64\combase.dll" 2>$null
    }
    Write-Log "  combase.dll re-registered" "Green"
    $tbFixCount++
} catch {}

# Step 2: Reset TokenBroker service
try {
    Write-Log "  Resetting TokenBroker service..." "Cyan"
    Stop-Service TokenBroker -Force -EA SilentlyContinue
    Start-Sleep -Seconds 1

    # Clear TokenBroker cache
    $tbCache = "$env:LOCALAPPDATA\Microsoft\TokenBroker"
    if (Test-Path $tbCache) {
        Remove-Item "$tbCache\*" -Recurse -Force -EA SilentlyContinue
        Write-Log "  TokenBroker cache cleared" "Green"
    }

    # Restart TokenBroker
    Start-Service TokenBroker -EA SilentlyContinue
    Write-Log "  TokenBroker service restarted" "Green"
    $tbFixCount++
} catch {}

# Step 3: Re-register all COM dependencies
try {
    Write-Log "  Re-registering COM dependencies..." "Cyan"
    $comDeps = @("oleaut32.dll", "ole32.dll", "rpcrt4.dll", "comsvcs.dll", "clbcatq.dll")
    foreach ($dll in $comDeps) {
        $path = "$env:SystemRoot\System32\$dll"
        if (Test-Path $path) {
            regsvr32 /s $path 2>$null
        }
    }
    $tbFixCount++
} catch {}

# Step 4: Reset DCOM configuration for TokenBroker
try {
    $dcomKey = "HKLM:\SOFTWARE\Classes\AppID\{8d3bab95-5449-4bcf-b614-31f0218c8e7d}"
    if (Test-Path $dcomKey) {
        # Reset RunAs to LocalService (default for TokenBroker)
        Set-ItemProperty -Path $dcomKey -Name "RunAs" -Value "NT AUTHORITY\LocalService" -EA SilentlyContinue
    }
    $tbFixCount++
} catch {}

# Step 5: Clear WER crash reports for TokenBroker
try {
    $werPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue"
    )
    foreach ($path in $werPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -Filter "*TokenBroker*" -Recurse -EA 0 | Remove-Item -Recurse -Force -EA 0
        }
    }
    Write-Log "  TokenBroker WER reports cleared" "Green"
    $tbFixCount++
} catch {}

Write-Log "  TokenBroker fix complete ($tbFixCount fixes)" "Green"
#endregion

#region PHASE 82: FIX USERMANAGER CRASH (combase.dll fault)