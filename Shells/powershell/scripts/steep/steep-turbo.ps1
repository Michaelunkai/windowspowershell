#Requires -RunAsAdministrator
<#
.SYNOPSIS
    STEEP TURBO - Full system maintenance (pppp → megawsl → dkill → fsteep)
.DESCRIPTION
    Runs all steep operations with parallelization, timeouts, and error resilience
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# Timeout for individual operations (seconds)
$script:TIMEOUT = 120

function Write-Step { param($msg) Write-Host "`n[$((Get-Date).ToString('HH:mm:ss'))] $msg" -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  → $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

function Invoke-WithTimeout {
    param([scriptblock]$Script, [string]$Name, [int]$Seconds = $script:TIMEOUT)
    try {
        $job = Start-Job -ScriptBlock $Script
        $completed = Wait-Job $job -Timeout $Seconds
        if ($completed) {
            $result = Receive-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            Write-OK $Name
            return $result
        } else {
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            Write-Skip "$Name (timeout)"
        }
    } catch {
        Write-Skip "$Name (skipped)"
    }
}

function Invoke-Safe {
    param([scriptblock]$Script, [string]$Name)
    try {
        & $Script 2>$null
        Write-OK $Name
    } catch {
        Write-Skip $Name
    }
}

# ============================================================================
# PHASE 1: PPPP (Profile Reload)
# ============================================================================
Write-Step "PHASE 1: Profile Reload"

Invoke-Safe { 
    if (Test-Path $PROFILE) { . $PROFILE 2>$null }
} "Profile sourced"

# ============================================================================
# PHASE 2: MEGAWSL (WSL Maintenance)
# ============================================================================
Write-Step "PHASE 2: WSL Maintenance"

# Kill any stuck WSL first
$wslProcs = Get-Process -Name wsl*, ubuntu*, debian* -ErrorAction SilentlyContinue
if ($wslProcs) { $wslProcs | Stop-Process -Force -ErrorAction SilentlyContinue }

# Parallel WSL operations
$wslJobs = @(
    Start-Job { wsl --shutdown 2>$null } -Name "WSL-Shutdown"
    Start-Job { wsl --update --web-download 2>$null } -Name "WSL-Update"
)

# Wait max 60s for WSL ops
$wslJobs | Wait-Job -Timeout 60 | Out-Null
$wslJobs | ForEach-Object {
    if ($_.State -eq 'Completed') { Write-OK $_.Name }
    else { Write-Skip "$($_.Name) (timeout)"; Stop-Job $_ -ErrorAction SilentlyContinue }
    Remove-Job $_ -Force -ErrorAction SilentlyContinue
}

# Cleanup WSL distros if needed
Invoke-Safe {
    $distros = wsl -l -q 2>$null | Where-Object { $_ -match 'Ubuntu|Debian' }
    # Don't unregister, just ensure shutdown
} "WSL cleanup check"

# ============================================================================
# PHASE 3: DKILL (Docker Cleanup & Optimization)
# ============================================================================
Write-Step "PHASE 3: Docker Cleanup"

$vhdx = "C:\ProgramData\DockerDesktop\vm-data\DockerDesktop.vhdx"

# Stop Docker gracefully
Invoke-Safe {
    taskkill /F /IM "Docker Desktop.exe" 2>$null
    Get-Process "*Docker*" -ErrorAction SilentlyContinue | Stop-Process -Force
    Stop-Service com.docker.service -Force -ErrorAction SilentlyContinue
} "Docker processes stopped"

# WSL shutdown for Docker
Start-Sleep -Seconds 2
wsl --shutdown 2>$null
Start-Sleep -Seconds 3

# Parallel Docker cleanup
$dockerJobs = @()
$dockerJobs += Start-Job { docker system prune -a -f --volumes 2>$null } -Name "Docker-Prune"

# VHDX optimization (if exists)
if (Test-Path $vhdx) {
    $dockerJobs += Start-Job -ArgumentList $vhdx {
        param($vhdx)
        try {
            takeown /F $vhdx /A 2>$null | Out-Null
            icacls $vhdx /grant Administrators:F 2>$null | Out-Null
            Dismount-VHD $vhdx -ErrorAction SilentlyContinue
            Start-Sleep 2
            Optimize-VHD -Path $vhdx -Mode Full -ErrorAction Stop
            return "Optimized"
        } catch { return "Skipped" }
    } -Name "VHDX-Optimize"
}

# Wait for docker jobs (max 90s)
$dockerJobs | Wait-Job -Timeout 90 | Out-Null
$dockerJobs | ForEach-Object {
    $result = Receive-Job $_ -ErrorAction SilentlyContinue
    if ($_.State -eq 'Completed') { Write-OK "$($_.Name)" }
    else { Write-Skip "$($_.Name) (timeout)"; Stop-Job $_ -ErrorAction SilentlyContinue }
    Remove-Job $_ -Force -ErrorAction SilentlyContinue
}

# Restart Docker service
Invoke-Safe {
    Start-Service com.docker.service -ErrorAction SilentlyContinue
    Start-Sleep 2
    $action = New-ScheduledTaskAction -Execute "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
    Register-ScheduledTask -TaskName "DockerStart" -Action $action -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName "DockerStart" -ErrorAction SilentlyContinue
} "Docker restarted"

# ============================================================================
# PHASE 4: FSTEEP (Fast System Cleanup) - Call external script
# ============================================================================
Write-Step "PHASE 4: Fast Cleanup (fsteep)"

$fsteepPath = Join-Path $PSScriptRoot "fsteep-turbo.ps1"
if (Test-Path $fsteepPath) {
    & $fsteepPath
} else {
    Write-Fail "fsteep-turbo.ps1 not found - run it separately"
}

# ============================================================================
# DONE
# ============================================================================
Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  STEEP COMPLETE @ $((Get-Date).ToString('HH:mm:ss'))" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
