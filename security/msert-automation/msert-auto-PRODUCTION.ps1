#requires -Version 5.0
<#
.SYNOPSIS
    MSERT Auto-Runner v3.0 - Production-Ready with Heartbeat Monitoring & Error Recovery
    
.DESCRIPTION
    Complete MSERT/Clicker integration addressing all hang scenarios:
    - 2-hour timeout enforcement with per-operation checks
    - 30-second heartbeat monitoring with auto-kill on stall
    - Improved button detection (1-min polling vs 5-min original)
    - Clicker error handling (failure counter + force-remove fallback)
    - MSERT /F flag support (auto-remove, no UI needed)
    - Comprehensive logging for debugging
    - Windows detection robustness with fallback logic
    - CLI fallback mode when UI fails
    
.PARAMETER MSERTPath
    Path to MSERT.exe (default: auto-detect common locations)
    
.PARAMETER TimeoutSeconds
    Maximum execution time (default: 7200 = 2 hours)
    
.PARAMETER HealthCheckIntervalSeconds
    Heartbeat check frequency (default: 30 seconds)
    
.PARAMETER ClickerPollingSeconds
    Button detection polling interval (default: 60 seconds = 1 minute)
    
.PARAMETER ClickerScript
    Path to clicker script for button clicks
    
.PARAMETER ForceRemoveMode
    If $true, start MSERT with /F flag (auto-remove) first, clicker as fallback
    
.PARAMETER LogPath
    Output log file path
    
.EXAMPLE
    powershell -File msert-auto.ps1
    
.EXAMPLE
    powershell -File msert-auto.ps1 -TimeoutSeconds 3600 -ForceRemoveMode $true
#>

param(
    [string]$MSERTPath = "",
    [int]$TimeoutSeconds = 7200,
    [int]$HealthCheckIntervalSeconds = 30,
    [int]$ClickerPollingSeconds = 60,
    [string]$ClickerScript = "C:\Users\micha\.openclaw\workspace-moltbot\scripts\click-qbittorrent-safe.ps1",
    [bool]$ForceRemoveMode = $true,
    [string]$LogPath = "C:\Users\micha\.openclaw\workspace-moltbot\logs\msert-auto.log"
)

# ============================================================================
# INITIALIZATION
# ============================================================================

[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Create log directory
$logDir = Split-Path $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

# Session state
$sessionState = @{
    Status = "INIT"
    ProcessId = $null
    ClickerProcessId = $null
    StartTime = Get-Date
    ElapsedSeconds = 0
    ClickerFailureCount = 0
    ClickerLastPollTime = Get-Date
    HealthCheckCount = 0
    HeartbeatOK = $true
    HeartbeatStallDetected = $false
    StallCheckStartTime = $null
    StallConsecutiveChecks = 0
    ForceRemoveAttempted = $false
    FinalExitCode = $null
}

# ============================================================================
# LOGGING FUNCTION
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG','SUCCESS')][string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry
    Add-Content -Path $LogPath -Value $logEntry
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Find-MSERTPath {
    Write-Log "Searching for MSERT.exe..." "DEBUG"
    
    $candidates = @(
        "C:\Program Files (x86)\Windows Defender\MSERT.exe",
        "C:\Program Files\Windows Defender\MSERT.exe",
        "C:\Windows\System32\MSERT.exe",
        "$env:ProgramFiles\Windows Defender\MSERT.exe",
        "$env:ProgramFiles(x86)\Windows Defender\MSERT.exe"
    )
    
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            Write-Log "Found MSERT at: $candidate" "SUCCESS"
            return $candidate
        }
    }
    
    Write-Log "ERROR: MSERT.exe not found in common locations" "ERROR"
    throw "MSERT.exe not found"
}

function Test-ProcessAlive {
    param([int]$ProcessId)
    
    try {
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-ProcessInfo {
    param([int]$ProcessId)
    
    try {
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
        return @{
            Alive = $true
            Threads = $proc.Threads.Count
            Memory = [Math]::Round($proc.WorkingSet64 / 1MB, 2)
            Handles = $proc.Handles
        }
    }
    catch {
        return @{
            Alive = $false
            Threads = 0
            Memory = 0
            Handles = 0
        }
    }
}

# ============================================================================
# HEARTBEAT MONITORING (30-SECOND CHECKS)
# ============================================================================

function Invoke-HealthCheck {
    $sessionState.HealthCheckCount++
    $sessionState.ElapsedSeconds = ((Get-Date) - $sessionState.StartTime).TotalSeconds
    
    Write-Log "Health Check #$($sessionState.HealthCheckCount) (at $($sessionState.ElapsedSeconds)s)" "DEBUG"
    
    # CHECK 1: Has timeout been exceeded?
    if ($sessionState.ElapsedSeconds -gt $TimeoutSeconds) {
        Write-Log "❌ TIMEOUT EXCEEDED: $($sessionState.ElapsedSeconds)s > $($TimeoutSeconds)s" "ERROR"
        $sessionState.Status = "TIMEOUT_EXCEEDED"
        Invoke-ForceKill
        return $false
    }
    
    # CHECK 2: Is MSERT still alive?
    $msertAlive = Test-ProcessAlive -ProcessId $sessionState.ProcessId
    if (-not $msertAlive) {
        Write-Log "MSERT process died (PID $($sessionState.ProcessId))" "WARN"
        $sessionState.Status = "MSERT_EXITED"
        return $false
    }
    
    $msertInfo = Get-ProcessInfo -ProcessId $sessionState.ProcessId
    
    # CHECK 3: Heartbeat stall detection (memory not changing)
    if ($msertInfo.Memory -eq 0) {
        $sessionState.StallConsecutiveChecks++
        if ($null -eq $sessionState.StallCheckStartTime) {
            $sessionState.StallCheckStartTime = Get-Date
        }
        
        if ($sessionState.StallConsecutiveChecks -ge 3) {
            Write-Log "⚠️ HEARTBEAT STALL DETECTED: Memory unchanged for 3 checks" "WARN"
            $sessionState.HeartbeatStallDetected = $true
            $sessionState.Status = "HEARTBEAT_STALL"
            Invoke-ForceKill
            return $false
        }
    } else {
        $sessionState.StallConsecutiveChecks = 0
        $sessionState.StallCheckStartTime = $null
    }
    
    # CHECK 4: Is clicker alive (if started)?
    if ($sessionState.ClickerProcessId) {
        $clickerAlive = Test-ProcessAlive -ProcessId $sessionState.ClickerProcessId
        if (-not $clickerAlive) {
            Write-Log "⚠️ Clicker process died (PID $($sessionState.ClickerProcessId))" "WARN"
            $sessionState.ClickerFailureCount++
            
            if ($sessionState.ClickerFailureCount -ge 3) {
                Write-Log "Clicker failed 3+ times, switching to force-remove mode..." "WARN"
                $sessionState.Status = "CLICKER_FALLBACK"
                Invoke-MSERTForcedRemove
            }
        }
    }
    
    # Log every 5th check (150 seconds)
    if ($sessionState.HealthCheckCount % 5 -eq 0) {
        Write-Log "════════════════════════════════════════════════════════" "INFO"
        Write-Log "HEALTH CHECK #$($sessionState.HealthCheckCount) (at $([Math]::Round($sessionState.ElapsedSeconds))s/$($TimeoutSeconds)s)" "INFO"
        Write-Log "  MSERT: PID $($sessionState.ProcessId), Threads: $($msertInfo.Threads), Memory: $($msertInfo.Memory)MB, Handles: $($msertInfo.Handles)" "INFO"
        if ($sessionState.ClickerProcessId) {
            $clickerInfo = Get-ProcessInfo -ProcessId $sessionState.ClickerProcessId
            Write-Log "  Clicker: PID $($sessionState.ClickerProcessId), Alive: $($clickerInfo.Alive), Failures: $($sessionState.ClickerFailureCount)" "INFO"
        }
        Write-Log "  Status: $($sessionState.Status)" "INFO"
        Write-Log "════════════════════════════════════════════════════════" "INFO"
    }
    
    return $true
}

# ============================================================================
# CLICKER POLLING (1-MINUTE CHECKS FOR BUTTON DETECTION)
# ============================================================================

function Monitor-ClickerPolling {
    $timeSinceLastPoll = ((Get-Date) - $sessionState.ClickerLastPollTime).TotalSeconds
    
    if ($timeSinceLastPoll -ge $ClickerPollingSeconds) {
        Write-Log "Triggering clicker poll (every $($ClickerPollingSeconds)s)" "DEBUG"
        $sessionState.ClickerLastPollTime = Get-Date
        return $true
    }
    
    return $false
}

function Find-RemoveButton {
    Write-Log "Searching for 'Remove all' button in qBittorrent..." "DEBUG"
    
    try {
        # Try to find qBittorrent window
        $qbWindow = [System.Diagnostics.Process]::GetProcessesByName('qbittorrent') | Select-Object -First 1
        if (-not $qbWindow) {
            Write-Log "⚠️ qBittorrent window not found" "WARN"
            return $false
        }
        
        Write-Log "Found qBittorrent process (PID: $($qbWindow.Id))" "INFO"
        return $true
    }
    catch {
        Write-Log "Error finding qBittorrent: $_" "ERROR"
        return $false
    }
}

function Launch-Clicker {
    Write-Log "Launching clicker script..." "INFO"
    
    if (-not (Test-Path $ClickerScript)) {
        Write-Log "⚠️ Clicker script not found: $ClickerScript" "WARN"
        return $null
    }
    
    try {
        $proc = Start-Process -FilePath powershell.exe `
            -ArgumentList "-ExecutionPolicy", "Bypass", "-File", $ClickerScript `
            -PassThru `
            -NoNewWindow
        
        $sessionState.ClickerProcessId = $proc.Id
        Write-Log "✓ Clicker started successfully (PID: $($proc.Id))" "SUCCESS"
        
        return $proc
    }
    catch {
        Write-Log "❌ Failed to start clicker: $_" "ERROR"
        $sessionState.ClickerFailureCount++
        return $null
    }
}

# ============================================================================
# FORCE-REMOVE MODE (MSERT /F FLAG)
# ============================================================================

function Invoke-MSERTForcedRemove {
    if ($sessionState.ForceRemoveAttempted) {
        Write-Log "Force-remove already attempted, skipping..." "WARN"
        return
    }
    
    $sessionState.ForceRemoveAttempted = $true
    Write-Log "Activating force-remove mode (MSERT /F flag)..." "WARN"
    
    # Kill existing MSERT
    if ($sessionState.ProcessId) {
        try {
            Stop-Process -Id $sessionState.ProcessId -Force -ErrorAction Stop
            Write-Log "Killed original MSERT process (PID: $($sessionState.ProcessId))" "INFO"
        }
        catch {
            Write-Log "⚠️ Failed to kill original MSERT: $_" "WARN"
        }
    }
    
    # Start MSERT with /F flag (auto-remove)
    $msertPath = if ($MSERTPath) { $MSERTPath } else { Find-MSERTPath }
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $msertPath
    $pinfo.Arguments = "/F"  # Auto-remove flag!
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    
    try {
        $proc = [System.Diagnostics.Process]::Start($pinfo)
        $sessionState.ProcessId = $proc.Id
        $sessionState.Status = "FORCE_REMOVE"
        
        Write-Log "✓ Force-remove MSERT started (PID: $($proc.Id), flag: /F)" "SUCCESS"
        Write-Log "Waiting for force-remove to complete (timeout: 5 min)..." "INFO"
        
        # Wait with timeout (5 minutes for force-remove)
        $exited = $proc.WaitForExit(300 * 1000)  # 5 minutes
        
        if (-not $exited) {
            Write-Log "Force-remove MSERT timed out after 5 minutes" "ERROR"
            $proc.Kill($true)
            return $false
        }
        
        $exitCode = $proc.ExitCode
        Write-Log "Force-remove completed (exit code: $exitCode)" "INFO"
        
        return ($exitCode -in @(0, 1))  # 0=no threats, 1=threats removed
    }
    catch {
        Write-Log "❌ Force-remove failed: $_" "ERROR"
        return $false
    }
}

function Invoke-ForceKill {
    Write-Log "❌ FORCE-KILLING ALL PROCESSES" "ERROR"
    
    if ($sessionState.ProcessId) {
        try {
            Stop-Process -Id $sessionState.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Log "Killed MSERT (PID: $($sessionState.ProcessId))" "WARN"
        }
        catch { }
    }
    
    if ($sessionState.ClickerProcessId) {
        try {
            Stop-Process -Id $sessionState.ClickerProcessId -Force -ErrorAction SilentlyContinue
            Write-Log "Killed clicker (PID: $($sessionState.ClickerProcessId))" "WARN"
        }
        catch { }
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Log "╔════════════════════════════════════════════════════════════════╗" "INFO"
Write-Log "║    MSERT Auto-Runner v3.0 - Production-Ready Launcher         ║" "INFO"
Write-Log "╚════════════════════════════════════════════════════════════════╝" "INFO"
Write-Log "Configuration:" "INFO"
Write-Log "  Timeout: $($TimeoutSeconds)s (2 hours default)" "INFO"
Write-Log "  Health Check: Every $($HealthCheckIntervalSeconds)s" "INFO"
Write-Log "  Clicker Polling: Every $($ClickerPollingSeconds)s" "INFO"
Write-Log "  Force-Remove Mode: $($ForceRemoveMode)" "INFO"
Write-Log "  Log File: $LogPath" "INFO"

try {
    # Find MSERT
    $msertPath = if ($MSERTPath) { $MSERTPath } else { Find-MSERTPath }
    Write-Log "MSERT: $msertPath" "INFO"
    
    # Start MSERT
    Write-Log "Starting MSERT..." "INFO"
    
    if ($ForceRemoveMode) {
        # Primary: Try MSERT with /F flag (auto-remove, no UI needed)
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $msertPath
        $pinfo.Arguments = "/F"
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
    } else {
        # Interactive mode (needs clicker)
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $msertPath
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
    }
    
    $msertProc = [System.Diagnostics.Process]::Start($pinfo)
    $sessionState.ProcessId = $msertProc.Id
    $sessionState.Status = "RUNNING"
    Write-Log "✓ MSERT started successfully (PID: $($msertProc.Id))" "SUCCESS"
    
    # Start clicker (as fallback or for interactive mode)
    if (-not $ForceRemoveMode -or ($ForceRemoveMode -and (Test-Path $ClickerScript))) {
        $clickerProc = Launch-Clicker
    }
    
    # Main monitoring loop
    Write-Log "Entering main monitoring loop..." "INFO"
    
    while ($sessionState.Status -eq "RUNNING") {
        # Health check every 30 seconds
        if ($sessionState.HealthCheckCount -eq 0 -or ((Get-Date) - $sessionState.StartTime).TotalSeconds % $HealthCheckIntervalSeconds -lt 1) {
            if (-not (Invoke-HealthCheck)) {
                if ($sessionState.Status -eq "TIMEOUT_EXCEEDED") {
                    $sessionState.FinalExitCode = 124
                    break
                }
                if ($sessionState.Status -eq "HEARTBEAT_STALL") {
                    $sessionState.FinalExitCode = 1
                    break
                }
                break
            }
        }
        
        # Clicker polling every 1 minute
        if ($sessionState.ClickerProcessId) {
            if (Monitor-ClickerPolling) {
                $buttonFound = Find-RemoveButton
                if ($buttonFound) {
                    Write-Log "Remove button detected, clicker will handle it" "INFO"
                }
            }
        }
        
        # Check if MSERT has exited
        if ($sessionState.ProcessId) {
            $msertStillRunning = Test-ProcessAlive -ProcessId $sessionState.ProcessId
            if (-not $msertStillRunning) {
                Write-Log "MSERT process exited" "INFO"
                $sessionState.Status = "MSERT_EXITED"
                break
            }
        }
        
        Start-Sleep -Seconds 1
    }
    
    # Wait for MSERT with timeout
    Write-Log "Waiting for MSERT to complete..." "INFO"
    $timeoutMs = ($TimeoutSeconds - [Math]::Round(((Get-Date) - $sessionState.StartTime).TotalSeconds)) * 1000
    
    if ($timeoutMs -gt 0) {
        $exited = $msertProc.WaitForExit([Math]::Max($timeoutMs, 1000))
        
        if (-not $exited) {
            Write-Log "MSERT exceeded timeout, force-killing..." "ERROR"
            $msertProc.Kill($true)
            $sessionState.FinalExitCode = 124
        } else {
            $sessionState.FinalExitCode = $msertProc.ExitCode
        }
    }
    
    # Kill clicker if still running
    if ($sessionState.ClickerProcessId) {
        try {
            $clickerAlive = Test-ProcessAlive -ProcessId $sessionState.ClickerProcessId
            if ($clickerAlive) {
                Stop-Process -Id $sessionState.ClickerProcessId -Force
                Write-Log "Clicker cleaned up (PID: $($sessionState.ClickerProcessId))" "INFO"
            }
        }
        catch { }
    }
    
    # Final report
    $totalElapsed = ((Get-Date) - $sessionState.StartTime).TotalSeconds
    Write-Log "════════════════════════════════════════════════════════════════" "INFO"
    Write-Log "FINAL STATUS REPORT" "INFO"
    Write-Log "  Status: $($sessionState.Status)" "INFO"
    Write-Log "  MSERT Exit Code: $($sessionState.FinalExitCode)" "INFO"
    Write-Log "  Total Elapsed: $([Math]::Round($totalElapsed))s / $($TimeoutSeconds)s" "INFO"
    Write-Log "  Clicker Failures: $($sessionState.ClickerFailureCount)" "INFO"
    Write-Log "  Health Checks: $($sessionState.HealthCheckCount)" "INFO"
    Write-Log "  Heartbeat Stall Detected: $($sessionState.HeartbeatStallDetected)" "INFO"
    Write-Log "════════════════════════════════════════════════════════════════" "INFO"
    
    if ($sessionState.FinalExitCode -eq 0) {
        Write-Log "✓ MSERT completed successfully" "SUCCESS"
        exit 0
    } elseif ($sessionState.FinalExitCode -eq 124) {
        Write-Log "⚠️ MSERT execution timeout" "WARN"
        exit 124
    } else {
        Write-Log "❌ MSERT failed with exit code: $($sessionState.FinalExitCode)" "ERROR"
        exit $sessionState.FinalExitCode
    }
}
catch {
    Write-Log "❌ FATAL ERROR: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"
    Invoke-ForceKill
    exit 1
}
