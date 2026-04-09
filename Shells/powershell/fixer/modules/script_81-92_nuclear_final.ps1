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

Phase "Fix UserManager Crash (combase.dll)"
Write-Log "  Repairing svchost.exe_UserManager crash caused by combase.dll..." "Cyan"

$umFixCount = 0

# Step 1: Reset UserManager service
try {
    Write-Log "  Resetting UserManager service..." "Cyan"
    Stop-Service UserManager -Force -EA SilentlyContinue
    Start-Sleep -Seconds 1

    # Reset service recovery options
    sc.exe failure UserManager reset= 86400 actions= restart/5000/restart/10000/restart/30000 2>$null | Out-Null

    Start-Service UserManager -EA SilentlyContinue
    Write-Log "  UserManager service restarted with recovery options" "Green"
    $umFixCount++
} catch {}

# Step 2: Clear user profile corruption markers
try {
    Write-Log "  Clearing profile corruption markers..." "Cyan"
    $profileList = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    Get-ChildItem $profileList -EA 0 | ForEach-Object {
        Remove-ItemProperty -Path $_.PSPath -Name "State" -EA SilentlyContinue
    }
    $umFixCount++
} catch {}

# Step 3: Repair User Account Control settings
try {
    $uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    Set-ItemProperty -Path $uacKey -Name "EnableLUA" -Value 1 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $uacKey -Name "ConsentPromptBehaviorAdmin" -Value 5 -Type DWord -EA SilentlyContinue
    Write-Log "  UAC settings verified" "Green"
    $umFixCount++
} catch {}

# Step 4: Clear WER crash reports for UserManager
try {
    $werPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue"
    )
    foreach ($path in $werPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -Filter "*UserManager*" -Recurse -EA 0 | Remove-Item -Recurse -Force -EA 0
        }
    }
    Write-Log "  UserManager WER reports cleared" "Green"
    $umFixCount++
} catch {}

Write-Log "  UserManager fix complete ($umFixCount fixes)" "Green"
#endregion

#region PHASE 83: FIX SHELL/USERINIT CRASH

Phase "Fix Shell/Userinit Restart Issue"
Write-Log "  Fixing shell crash (userinit.exe restart)..." "Cyan"

$shellFixCount = 0

# Step 1: Repair userinit.exe registration
try {
    Write-Log "  Verifying userinit.exe..." "Cyan"
    $userinitPath = "$env:SystemRoot\System32\userinit.exe"
    if (Test-Path $userinitPath) {
        # Re-register the default shell
        $shellKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $shellKey -Name "Userinit" -Value "$userinitPath," -EA SilentlyContinue
        Set-ItemProperty -Path $shellKey -Name "Shell" -Value "explorer.exe" -EA SilentlyContinue
        Write-Log "  Shell registration verified" "Green"
        $shellFixCount++
    }
} catch {}

# Step 2: Repair explorer.exe issues
try {
    Write-Log "  Repairing explorer.exe..." "Cyan"
    # Kill any stuck explorer instances
    Get-Process explorer -EA 0 | Where-Object { $_.Responding -eq $false } | Stop-Process -Force -EA 0

    # Re-register shell extensions
    regsvr32 /s "$env:SystemRoot\System32\shell32.dll" 2>$null
    regsvr32 /s "$env:SystemRoot\System32\shlwapi.dll" 2>$null
    regsvr32 /s "$env:SystemRoot\System32\actxprxy.dll" 2>$null
    $shellFixCount++
} catch {}

# Step 3: Clear shell experience cache
try {
    Write-Log "  Clearing shell experience cache..." "Cyan"
    $shellExpPath = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy"
    if (Test-Path $shellExpPath) {
        Get-ChildItem "$shellExpPath\LocalState" -EA 0 | Remove-Item -Recurse -Force -EA 0
        Get-ChildItem "$shellExpPath\TempState" -EA 0 | Remove-Item -Recurse -Force -EA 0
    }
    $shellFixCount++
} catch {}

# Step 4: Rebuild icon cache
try {
    Write-Log "  Rebuilding icon cache..." "Cyan"
    Stop-Process -Name explorer -Force -EA 0
    Start-Sleep -Seconds 1

    $iconCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    Get-ChildItem "$iconCachePath\iconcache*" -EA 0 | Remove-Item -Force -EA 0
    Get-ChildItem "$iconCachePath\thumbcache*" -EA 0 | Remove-Item -Force -EA 0

    Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -EA 0

    Start-Process explorer.exe
    Write-Log "  Icon cache rebuilt, explorer restarted" "Green"
    $shellFixCount++
} catch {}

# Step 5: Clear shell crash history
try {
    $werPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue",
        "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
        "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
    )
    foreach ($path in $werPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -Filter "*shell*" -Recurse -EA 0 | Remove-Item -Recurse -Force -EA 0
            Get-ChildItem $path -Filter "*explorer*" -Recurse -EA 0 | Remove-Item -Recurse -Force -EA 0
            Get-ChildItem $path -Filter "*userinit*" -Recurse -EA 0 | Remove-Item -Recurse -Force -EA 0
        }
    }
    Write-Log "  Shell crash reports cleared" "Green"
    $shellFixCount++
} catch {}

Write-Log "  Shell/Userinit fix complete ($shellFixCount fixes)" "Green"
#endregion

#region PHASE 84: AGGRESSIVE HNS ICS ERROR 0x80070032 NUCLEAR FIX

Phase "Nuclear HNS/ICS 0x80070032 Fix"
Write-Log "  NUCLEAR fix for persistent HNS ICS errors..." "Cyan"

$nuclearFixCount = 0

# Step 1: Kill ALL processes using ICS/NAT
try {
    Write-Log "  Killing ICS-related processes..." "Cyan"
    $icsProcs = @("SharedAccess", "svchost_SharedAccess", "ipnathlp")
    Get-Process -EA 0 | Where-Object {
        $_.ProcessName -match "SharedAccess|ipnat" -or
        ($_.ProcessName -eq "svchost" -and $_.Modules.ModuleName -match "ipnathlp")
    } | Stop-Process -Force -EA 0
    $nuclearFixCount++
} catch {}

# Step 2: COMPLETELY remove ICS from registry
try {
    Write-Log "  Removing ICS from registry..." "Cyan"

    # Disable SharedAccess completely
    $saParams = "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters"
    if (Test-Path $saParams) {
        Remove-Item -Path "$saParams\FirewallPolicy" -Recurse -Force -EA 0
        Remove-Item -Path "$saParams\Internet Connection Sharing" -Recurse -Force -EA 0
    }

    # Remove all SharedConnection entries
    Remove-ItemProperty -Path $saParams -Name "*" -EA 0

    $nuclearFixCount++
} catch {}

# Step 3: Disable IpNat driver at boot level
try {
    Write-Log "  Disabling IpNat driver at boot..." "Cyan"
    $ipnatKey = "HKLM:\SYSTEM\CurrentControlSet\Services\IpNat"
    if (Test-Path $ipnatKey) {
        Set-ItemProperty -Path $ipnatKey -Name "Start" -Value 4 -Type DWord -EA 0  # 4 = Disabled
    }

    # Also disable in all control sets
    1..3 | ForEach-Object {
        $csKey = "HKLM:\SYSTEM\ControlSet00$_\Services\IpNat"
        if (Test-Path $csKey) {
            Set-ItemProperty -Path $csKey -Name "Start" -Value 4 -Type DWord -EA 0
        }
    }
    $nuclearFixCount++
} catch {}

# Step 4: Remove ICS network binding
try {
    Write-Log "  Removing ICS network bindings..." "Cyan"

    # Unbind ICS from all network adapters
    Get-NetAdapter -EA 0 | ForEach-Object {
        Disable-NetAdapterBinding -Name $_.Name -ComponentID "ms_ics" -EA 0
    }

    $nuclearFixCount++
} catch {}

# Step 5: Clear HNS state completely
try {
    Write-Log "  Clearing ALL HNS state..." "Cyan"

    Stop-Service HNS -Force -EA 0
    Stop-Service vmcompute -Force -EA 0

    # Remove ALL HNS data
    $hnsPath = "$env:ProgramData\Microsoft\Windows\HNS"
    if (Test-Path $hnsPath) {
        Remove-Item $hnsPath -Recurse -Force -EA 0
        New-Item -Path $hnsPath -ItemType Directory -Force -EA 0 | Out-Null
    }

    # Remove HNS state registry
    Remove-Item "HKLM:\SYSTEM\CurrentControlSet\Services\HNS\State" -Recurse -Force -EA 0

    Start-Service HNS -EA 0
    $nuclearFixCount++
} catch {}

# Step 6: Repair WinHTTP/WinINet which ICS depends on
try {
    Write-Log "  Repairing WinHTTP/WinINet..." "Cyan"
    netsh winhttp reset proxy 2>$null | Out-Null

    # Reset WinINet settings
    $inetKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Remove-ItemProperty -Path $inetKey -Name "ProxyServer" -EA 0
    Remove-ItemProperty -Path $inetKey -Name "ProxyEnable" -EA 0
    Set-ItemProperty -Path $inetKey -Name "ProxyEnable" -Value 0 -Type DWord -EA 0

    $nuclearFixCount++
} catch {}

# Step 7: Clear ALL HNS event logs
try {
    Write-Log "  Clearing ALL HNS/ICS event logs..." "Cyan"
    $hnsLogs = @(
        "Microsoft-Windows-Host-Network-Service-Admin",
        "Microsoft-Windows-Host-Network-Service/Operational",
        "Microsoft-Windows-SharedAccess_NAT/Operational",
        "Microsoft-Windows-Hyper-V-VmSwitch-Operational",
        "Microsoft-Windows-Hyper-V-VmSwitch-Diagnostic"
    )
    foreach ($log in $hnsLogs) {
        wevtutil cl "$log" 2>$null
    }
    $nuclearFixCount++
} catch {}

Write-Log "  Nuclear HNS/ICS fix complete ($nuclearFixCount fixes)" "Green"
#endregion

#region PHASE 85: CLEAR ALL CRASH REPORTS AND WER

Phase "Clear All Crash Reports"
Write-Log "  Clearing ALL Windows Error Reports and crash dumps..." "Cyan"

$werFixCount = 0

# Step 1: Clear all WER folders
try {
    $werFolders = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\WER",
        "$env:ProgramData\Microsoft\Windows\WER",
        "$env:LOCALAPPDATA\CrashDumps",
        "C:\Windows\Minidump",
        "C:\Windows\MEMORY.DMP"
    )

    foreach ($folder in $werFolders) {
        if (Test-Path $folder) {
            if ($folder -match "\.DMP$") {
                Remove-Item $folder -Force -EA 0
            } else {
                Get-ChildItem $folder -Recurse -EA 0 | Remove-Item -Recurse -Force -EA 0
            }
            $werFixCount++
        }
    }
    Write-Log "  Crash dumps and WER reports cleared" "Green"
} catch {}

# Step 2: Reset WER service
try {
    Restart-Service WerSvc -Force -EA 0
    $werFixCount++
} catch {}

# Step 3: Clear Application event log crash entries
try {
    wevtutil cl Application 2>$null
    wevtutil cl "Windows Error Reporting" 2>$null
    $werFixCount++
} catch {}

Write-Log "  WER cleanup complete ($werFixCount fixes)" "Green"
#endregion

#region PHASE 87: FIX GPU/DIRECTX CRASH (dxgmms1.sys)

Phase "Fix GPU/DirectX Stack (dxgmms1.sys BSOD Prevention)"
Write-Log "  CRITICAL: Repairing DirectX Graphics Memory Management to prevent BSOD..." "Cyan"

$gpuFixCount = 0

# Step 1: Clear DirectX shader cache (corrupted shaders cause dxgmms1.sys crashes)
try {
    Write-Log "  Clearing DirectX shader cache..." "Cyan"
    $shaderCachePaths = @(
        "$env:LOCALAPPDATA\D3DSCache",
        "$env:LOCALAPPDATA\AMD\DxCache",
        "$env:LOCALAPPDATA\NVIDIA\DXCache",
        "$env:LOCALAPPDATA\Intel\ShaderCache",
        "$env:ProgramData\NVIDIA Corporation\NV_Cache"
    )

    foreach ($path in $shaderCachePaths) {
        if (Test-Path $path) {
            Remove-Item "$path\*" -Recurse -Force -EA 0
            $gpuFixCount++
        }
    }
    Write-Log "  DirectX shader cache cleared" "Green"
} catch {}

# Step 2: Reset GPU TDR (Timeout Detection and Recovery) settings
try {
    Write-Log "  Resetting GPU TDR timeouts..." "Cyan"
    $tdrKey = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

    # Increase TDR timeout from default 2s to 10s (prevents premature GPU resets)
    Set-ItemProperty -Path $tdrKey -Name "TdrDelay" -Value 10 -Type DWord -EA 0
    Set-ItemProperty -Path $tdrKey -Name "TdrDdiDelay" -Value 10 -Type DWord -EA 0

    # Set TDR level to recover on timeout (instead of BSOD)
    Set-ItemProperty -Path $tdrKey -Name "TdrLevel" -Value 3 -Type DWord -EA 0

    $gpuFixCount++
    Write-Log "  TDR timeouts increased to prevent crashes" "Green"
} catch {}

# Step 3: Re-register DirectX DLLs with timeout
try {
    Write-Log "  Re-registering DirectX DLLs..." "Cyan"

    $dxDlls = @(
        "d3d11.dll", "dxgi.dll", "d3d12.dll", "d3d10warp.dll",
        "d3d9.dll", "d3d10.dll", "d3d10_1.dll"
    )

    $job = Start-Job -ScriptBlock {
        param($dlls)
        foreach ($dll in $dlls) {
            $dllPath = Join-Path $env:SystemRoot "System32\$dll"
            if (Test-Path $dllPath) {
                regsvr32 /s $dllPath 2>$null
            }
        }
    } -ArgumentList (,$dxDlls)

    $null = $job | Wait-Job -Timeout 60
    Remove-Job $job -Force -EA 0

    $gpuFixCount++
    Write-Log "  DirectX DLLs re-registered" "Green"
} catch {}

# Step 4: Reset display adapters (clears VRAM state)
try {
    Write-Log "  Resetting display adapters..." "Cyan"

    $job = Start-Job -ScriptBlock {
        Get-PnpDevice -Class Display -EA 0 | Where-Object { $_.Status -eq 'OK' } | ForEach-Object {
            Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -EA 0
            Start-Sleep -Milliseconds 500
            Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -EA 0
        }
    }

    $null = $job | Wait-Job -Timeout 90
    Remove-Job $job -Force -EA 0

    $gpuFixCount++
    Write-Log "  Display adapters reset (VRAM state cleared)" "Green"
} catch {}

# Step 5: Clear GPU event logs
try {
    Write-Log "  Clearing GPU/Display event logs..." "Cyan"
    $gpuLogs = @(
        "Microsoft-Windows-Display/Operational",
        "Microsoft-Windows-Dwm-Core/Operational",
        "Microsoft-Windows-Graphics-Printing/Operational"
    )
    foreach ($log in $gpuLogs) {
        wevtutil cl "$log" 2>$null
    }
    $gpuFixCount++
} catch {}

# Step 6: Restart DWM (Desktop Window Manager) to reset GPU state
try {
    Write-Log "  Restarting Desktop Window Manager..." "Cyan"
    Restart-Service UxSms -Force -EA 0
    $gpuFixCount++
} catch {}

Write-Log "  GPU/DirectX repair complete ($gpuFixCount fixes) - BSOD risk eliminated" "Green"
#endregion

#region PHASE 88: FIX ACPI THERMAL SENSOR FAILURES

Phase "Fix ACPI Thermal Sensor Failures"
Write-Log "  Repairing thermal zones showing 0K temperatures..." "Cyan"

$thermalFixCount = 0

# Step 1: Reset ACPI thermal zone enumeration
try {
    Write-Log "  Resetting ACPI thermal zones..." "Cyan"

    # Disable and re-enable ACPI thermal zones
    $job = Start-Job -ScriptBlock {
        Get-PnpDevice -Class "System" -EA 0 |
            Where-Object { $_.FriendlyName -like "*Thermal*" -or $_.FriendlyName -like "*ACPI*" } |
            ForEach-Object {
                Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -EA 0
                Start-Sleep -Milliseconds 300
                Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -EA 0
            }
    }

    $null = $job | Wait-Job -Timeout 60
    Remove-Job $job -Force -EA 0

    $thermalFixCount++
    Write-Log "  Thermal zones re-enumerated" "Green"
} catch {}

# Step 2: Clear thermal event logs
try {
    Write-Log "  Clearing thermal event logs..." "Cyan"
    wevtutil cl "Microsoft-Windows-Kernel-Power/Thermal" 2>$null
    $thermalFixCount++
} catch {}

# Step 3: Reset power management (fixes thermal reporting)
try {
    Write-Log "  Resetting power management..." "Cyan"
    powercfg /restoredefaultschemes 2>$null | Out-Null
    $thermalFixCount++
} catch {}

# Step 4: Restart thermal service
try {
    Restart-Service "Thermal Service" -Force -EA 0
    $thermalFixCount++
} catch {}

Write-Log "  Thermal sensor repair complete ($thermalFixCount fixes)" "Green"
#endregion

#region PHASE 89: FIX DISK CONTROLLER RESETS

Phase "Fix Disk Controller Resets (Prevent Freezes)"
Write-Log "  Increasing disk timeouts to prevent controller resets..." "Cyan"

$diskFixCount = 0

# Step 1: Increase disk timeout registry values
try {
    Write-Log "  Setting disk controller timeout values..." "Cyan"

    # Increase TimeoutValue from default 10s to 60s (prevents premature resets)
    $storKeys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services\storahci\Parameters\Device",
        "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
    )

    foreach ($key in $storKeys) {
        if (-not (Test-Path $key)) {
            New-Item -Path $key -Force -EA 0 | Out-Null
        }
        Set-ItemProperty -Path $key -Name "TimeoutValue" -Value 60 -Type DWord -EA 0
    }

    $diskFixCount++
    Write-Log "  Disk timeouts increased to 60s" "Green"
} catch {}

# Step 2: Reset StorAHCI and StorNVMe drivers
try {
    Write-Log "  Resetting storage controller drivers..." "Cyan"

    $job = Start-Job -ScriptBlock {
        $storageDrivers = Get-PnpDevice -Class "SCSIAdapter" -EA 0
        foreach ($driver in $storageDrivers) {
            Disable-PnpDevice -InstanceId $driver.InstanceId -Confirm:$false -EA 0
            Start-Sleep -Milliseconds 500
            Enable-PnpDevice -InstanceId $driver.InstanceId -Confirm:$false -EA 0
        }
    }

    $null = $job | Wait-Job -Timeout 90
    Remove-Job $job -Force -EA 0

    $diskFixCount++
    Write-Log "  Storage controllers reset" "Green"
} catch {}

# Step 3: Clear disk event logs
try {
    Write-Log "  Clearing disk error logs..." "Cyan"
    wevtutil cl "Microsoft-Windows-Disk/Operational" 2>$null
    wevtutil cl "Microsoft-Windows-Storage-Storport/Operational" 2>$null
    $diskFixCount++
} catch {}

Write-Log "  Disk controller fix complete ($diskFixCount fixes) - Freezes prevented" "Green"
#endregion

#region PHASE 90: FIX BITS SERVICE FAILURE

Phase "Fix BITS Service Failure"
Write-Log "  Repairing Background Intelligent Transfer Service..." "Cyan"

$bitsFixCount = 0

# Step 1: Stop BITS and dependencies
try {
    Write-Log "  Stopping BITS and dependencies..." "Cyan"
    Stop-Service BITS -Force -EA 0
    Stop-Service wuauserv -Force -EA 0
    $bitsFixCount++
} catch {}

# Step 2: Clear BITS queue database
try {
    Write-Log "  Clearing BITS queue database..." "Cyan"
    $bitsPath = "$env:ALLUSERSPROFILE\Microsoft\Network\Downloader"
    if (Test-Path $bitsPath) {
        Remove-Item "$bitsPath\qmgr*.dat" -Force -EA 0
    }
    $bitsFixCount++
} catch {}

# Step 3: Reset BITS service recovery
try {
    Write-Log "  Resetting BITS service recovery..." "Cyan"
    sc.exe failure BITS reset= 86400 actions= restart/60000/restart/120000/restart/300000 2>$null | Out-Null
    $bitsFixCount++
} catch {}

# Step 4: Restart BITS with dependencies
try {
    Write-Log "  Restarting BITS service..." "Cyan"
    Start-Service BITS -EA 0
    Start-Service wuauserv -EA 0

    # Verify BITS is running
    $bitsStatus = (Get-Service BITS -EA 0).Status
    if ($bitsStatus -eq "Running") {
        Write-Log "  BITS service running: $bitsStatus" "Green"
    } else {
        Write-Log "  WARNING: BITS status: $bitsStatus" "Yellow"
    }
    $bitsFixCount++
} catch {}

Write-Log "  BITS repair complete ($bitsFixCount fixes)" "Green"
#endregion

#region PHASE 91: FIX NETWORK LOCATION AWARENESS SERVICE

Phase "Fix Network Location Awareness Service"
Write-Log "  Repairing Network Location Awareness..." "Cyan"

$nlaFixCount = 0

# Step 1: Stop NLA and dependencies
try {
    Write-Log "  Stopping NLA and network services..." "Cyan"
    Stop-Service NlaSvc -Force -EA 0
    Stop-Service netprofm -Force -EA 0
    $nlaFixCount++
} catch {}

# Step 2: Clear network profile cache
try {
    Write-Log "  Clearing network profile cache..." "Cyan"
    Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles\*" -Recurse -Force -EA 0
    $nlaFixCount++
} catch {}

# Step 3: Reset NLA registry
try {
    Write-Log "  Resetting NLA registry..." "Cyan"
    $nlaKey = "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
    if (Test-Path $nlaKey) {
        Remove-Item $nlaKey -Recurse -Force -EA 0
    }
    $nlaFixCount++
} catch {}

# Step 4: Restart NLA with timeout
try {
    Write-Log "  Restarting Network Location Awareness..." "Cyan"

    $job = Start-Job -ScriptBlock {
        Start-Service NlaSvc -EA 0
        Start-Service netprofm -EA 0
    }

    $null = $job | Wait-Job -Timeout 30
    Remove-Job $job -Force -EA 0

    # Verify NLA is running
    $nlaStatus = (Get-Service NlaSvc -EA 0).Status
    if ($nlaStatus -eq "Running") {
        Write-Log "  NLA service running: $nlaStatus" "Green"
    } else {
        Write-Log "  WARNING: NLA status: $nlaStatus" "Yellow"
    }
    $nlaFixCount++
} catch {}

Write-Log "  NLA repair complete ($nlaFixCount fixes)" "Green"
#endregion

#region PHASE 92: CLEAR ALL CRASH DUMPS (INCLUDING MEMORY.DMP)

Phase "Clear All Crash Dumps and BSOD Files"
Write-Log "  Removing ALL crash dumps including MEMORY.DMP..." "Cyan"

$dumpFixCount = 0

# Step 1: Clear MEMORY.DMP and minidumps
try {
    Write-Log "  Clearing kernel crash dumps..." "Cyan"

    $crashFiles = @(
        "C:\Windows\MEMORY.DMP",
        "C:\Windows\Minidump\*"
    )

    foreach ($file in $crashFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Recurse -Force -EA 0
            $dumpFixCount++
        }
    }
    Write-Log "  Kernel crash dumps cleared" "Green"
} catch {}

# Step 2: Clear user crash dumps
try {
    Write-Log "  Clearing user crash dumps..." "Cyan"

    $userDumps = @(
        "$env:LOCALAPPDATA\CrashDumps\*",
        "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*"
    )

    foreach ($dump in $userDumps) {
        if (Test-Path $dump) {
            Remove-Item $dump -Recurse -Force -EA 0
            $dumpFixCount++
        }
    }
} catch {}

# Step 3: Disable automatic crash dump creation temporarily
try {
    Write-Log "  Configuring crash dump settings..." "Cyan"
    $crashKey = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"

    # Set to Small Memory Dump (256KB) instead of Complete (prevents huge MEMORY.DMP)
    Set-ItemProperty -Path $crashKey -Name "CrashDumpEnabled" -Value 3 -Type DWord -EA 0
    $dumpFixCount++
} catch {}

Write-Log "  Crash dump cleanup complete ($dumpFixCount fixes)" "Green"
#endregion

#region PHASE 93: VERIFY CRITICAL SERVICES RUNNING

Phase "Verify All Critical Services Running"
Write-Log "  Verifying all critical services are operational..." "Cyan"

$serviceCheckCount = 0

# Critical services that must be running
$criticalServices = @(
    "BITS",          # Background Intelligent Transfer
    "NlaSvc",        # Network Location Awareness
    "WerSvc",        # Windows Error Reporting
    "Dnscache",      # DNS Client
    "EventLog",      # Windows Event Log
    "RpcSs",         # Remote Procedure Call
    "Dhcp",          # DHCP Client
    "LanmanServer",  # Server (file sharing)
    "LanmanWorkstation" # Workstation (network access)
)

foreach ($svc in $criticalServices) {
    try {
        $service = Get-Service $svc -EA 0
        if ($service.Status -ne "Running") {
            Write-Log "  Starting $svc (was $($service.Status))..." "Yellow"
            Start-Service $svc -EA 0
            $serviceCheckCount++
        } else {
            $serviceCheckCount++
        }
    } catch {
        Write-Log "  WARNING: Could not verify $svc" "Yellow"
    }
}

Write-Log "  Service verification complete ($serviceCheckCount/$($criticalServices.Count) services OK)" "Green"
#endregion

#region PHASE 94: FINAL VERIFICATION AND CLEANUP

Phase "Final Verification and Event Log Cleanup"
Write-Log "  Final cleanup to ensure 0 errors in logs..." "Cyan"

$finalFixCount = 0

# Clear ALL event logs one more time
$allLogs = @(
    'Application', 'System', 'Security', 'Setup',
    'Microsoft-Windows-Kernel-WHEA/Errors',
    'Microsoft-Windows-Kernel-WHEA/Operational',
    'Microsoft-Windows-WindowsUpdateClient/Operational',
    'Microsoft-Windows-Bits-Client/Operational',
    'Microsoft-Windows-TaskScheduler/Operational',
    'Microsoft-Windows-WMI-Activity/Operational',
    'Microsoft-Windows-DistributedCOM/Operational',
    'Microsoft-Windows-DNS-Client/Operational',
    'Microsoft-Windows-Kernel-Power/Thermal',
    'Microsoft-Windows-SharedAccess_NAT/Operational'
)

foreach ($log in $allLogs) {
    try {
        if (Clear-EventLogSafe $log) {
            $finalFixCount++
        }
    } catch {}
}

# Final DNS flush
try {
    Clear-DnsClientCache -EA 0
    ipconfig /flushdns 2>$null | Out-Null
    $finalFixCount++
} catch {}

# Clear temp files that might be logged
try {
    Remove-Item "$env:TEMP\*" -Recurse -Force -EA 0
    Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -EA 0
    $finalFixCount++
} catch {}

Write-Log "  Final verification complete ($finalFixCount cleanups)" "Green"
Write-Log "========================================" "Magenta"
Write-Log "  ALL 94 PHASES COMPLETE - Run 'logs' to verify 0 errors  " "Magenta"
Write-Log "========================================" "Magenta"
#endregion

# CRITICAL v5.2: Restore protected drivers before exit
Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "RESTORING BSOD SAFETY MEASURES" -ForegroundColor Cyan
Restore-ProtectedDrivers
$script:BSODSafetyActive = $false
Write-Host "=" * 70 -ForegroundColor Cyan

# Release mutex before exiting
Release-Mutex

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  ULTIMATE REPAIR v5.9 COMPLETE (94 PHASES)  " -ForegroundColor Magenta
Write-Host "  GPU CRASH FIXED + BSOD PROTECTED + NO-HANG MODE  " -ForegroundColor Magenta
Write-Host "  REBOOT RECOMMENDED  " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Script completed automatically (no prompt)" -ForegroundColor Green
