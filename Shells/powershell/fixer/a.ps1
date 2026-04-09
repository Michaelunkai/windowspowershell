# ============================================================================
# WINDOWS 11 COMPLETE SYSTEM REPAIR ORCHESTRATOR v2.0
# Master Script: a.ps1 (orchestrator)
# Purpose: Execute all targeted system fixes in sequence
# Date: 2025-12-12
# ============================================================================
# This is the master orchestrator that runs all 6 targeted fix scripts:
# 1. CPU Performance Fix (userinit crashes, throttling, core management)
# 2. GPU Performance Fix (TDR timeouts, frame drops, stuttering)
# 3. RAM/Memory Fix (pagefile exhaustion, memory leaks)
# 4. Power/Thermal Fix (thermal zones 0K, power hijacking, throttling)
# 5. BSOD/Crash Fix (crash dumps, WHEA, DPC watchdog)
# 6. HNS/Docker Fix (0x80070032 errors, networking, NAT)
# ============================================================================

param(
    [switch]$SkipBackup = $false,
    [switch]$Verbose = $false,
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

$masterLog = "F:\Downloads\fix\master_orchestrator.log"
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesDir = Join-Path $baseDir "modules"

# Create logs directory
if (-not (Test-Path "F:\Downloads\fix")) {
    New-Item -Path "F:\Downloads\fix" -ItemType Directory -Force -EA 0 | Out-Null
}

# ============================================================================
# LOGGING
# ============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $masterLog -Value $logEntry -Force -EA 0
    Write-Host $logEntry -ForegroundColor Cyan
}

function Write-Header {
    param([string]$Title, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor $Color
    Write-Host "  $Title" -ForegroundColor $Color
    Write-Host "======================================================================" -ForegroundColor $Color
    Write-Host ""
}

# ============================================================================
# PRE-FLIGHT
# ============================================================================

Write-Header "WINDOWS 11 COMPLETE SYSTEM REPAIR ORCHESTRATOR v2.0" "Cyan"

Write-Log "Master orchestrator started" "START"
Write-Log "Dry-Run mode: $DryRun" "INFO"

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script REQUIRES Administrator privileges!" -ForegroundColor Red
    Write-Log "Admin check FAILED" "ERROR"
    exit 1
}
Write-Log "Admin privileges: VERIFIED" "OK"

# Check modules
Write-Header "PRE-FLIGHT CHECKS" "Yellow"

$requiredModules = @(
    "fix_cpu_performance.ps1",
    "fix_gpu_performance.ps1",
    "fix_ram_memory.ps1",
    "fix_power_thermal.ps1",
    "fix_bsod_crashes.ps1",
    "fix_hns_docker.ps1"
)

$missingModules = @()
foreach ($module in $requiredModules) {
    $modulePath = Join-Path $modulesDir $module
    if (Test-Path $modulePath) {
        $size = [math]::Round((Get-Item $modulePath).Length / 1KB, 1)
        Write-Host "  [OK] $module (${size}KB)" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] $module NOT FOUND" -ForegroundColor Red
        $missingModules += $module
        Write-Log "Module NOT found: $module" "ERROR"
    }
}

if ($missingModules.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: Missing required modules - cannot continue!" -ForegroundColor Red
    Write-Log "Missing modules - aborting" "ERROR"
    exit 1
}

Write-Host ""
Write-Host "All required modules verified!" -ForegroundColor Green
Write-Log "All modules verified" "OK"

# ============================================================================
# BACKUP (if not skipped)
# ============================================================================

if (-not $SkipBackup -and -not $DryRun) {
    Write-Header "CREATING SYSTEM BACKUP" "Green"

    try {
        Write-Host "Creating system restore point..." -ForegroundColor Cyan
        Checkpoint-Computer -Description "Before Complete System Optimization Fixes" -RestorePointType "Modify_Settings" -EA 0 | Out-Null
        Write-Host "  System restore point created" -ForegroundColor Green
        Write-Log "Restore point created" "OK"

        Write-Host "Backing up registry..." -ForegroundColor Cyan
        $regBackupPath = "F:\Downloads\fix\registry_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
        reg export HKLM\SYSTEM "$regBackupPath" /y 2>&1 | Out-Null
        Write-Host "  Registry backup created: $regBackupPath" -ForegroundColor Green
        Write-Log "Registry backup created" "OK"

    } catch {
        Write-Host "  Warning: Backup failed (non-critical): $_" -ForegroundColor Yellow
        Write-Log "Backup warning: $_" "WARN"
    }
    Write-Host ""
}

# ============================================================================
# EXECUTE FIXES
# ============================================================================

Write-Header "EXECUTING SYSTEM FIXES (6 PHASES)" "Green"

$fixScripts = @(
    @{ Name = "CPU Performance"; File = "fix_cpu_performance.ps1"; Phase = 1; Description = "CPU throttling, userinit crashes, core management" },
    @{ Name = "GPU Performance"; File = "fix_gpu_performance.ps1"; Phase = 2; Description = "TDR timeouts, frame drops, stuttering" },
    @{ Name = "RAM/Memory"; File = "fix_ram_memory.ps1"; Phase = 3; Description = "Pagefile exhaustion, memory leaks" },
    @{ Name = "Power/Thermal"; File = "fix_power_thermal.ps1"; Phase = 4; Description = "Thermal 0K, power hijacking, throttling" },
    @{ Name = "BSOD/Crash"; File = "fix_bsod_crashes.ps1"; Phase = 5; Description = "Crash dumps, WHEA, DPC watchdog" },
    @{ Name = "HNS/Docker"; File = "fix_hns_docker.ps1"; Phase = 6; Description = "HNS 0x80070032, Docker networking, NAT" }
)

$completedFixes = 0
$failedFixes = 0
$phaseResults = @()

foreach ($fix in $fixScripts) {
    $scriptPath = Join-Path $modulesDir $fix.File
    $phaseName = "[$($fix.Phase)/6] $($fix.Name) Fix"

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Yellow
    Write-Host "  $phaseName" -ForegroundColor Yellow
    Write-Host "  $($fix.Description)" -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Log "Starting Phase $($fix.Phase): $($fix.Name)" "PHASE"

    if ($DryRun) {
        Write-Host "DRY-RUN: Would execute $($fix.File)" -ForegroundColor Magenta
        Write-Log "DRY-RUN: Skipped Phase $($fix.Phase)" "INFO"
        $completedFixes++
    } else {
        try {
            & $scriptPath -Verbose:$Verbose -EA Continue
            Write-Log "Phase $($fix.Phase) COMPLETED" "COMPLETE"
            $completedFixes++
            $phaseResults += @{ Phase = $($fix.Phase); Name = $($fix.Name); Status = "SUCCESS" }
            Write-Host ""
            Write-Host "  [OK] Phase $($fix.Phase) COMPLETED" -ForegroundColor Green
            Write-Host ""

        } catch {
            Write-Log "Phase $($fix.Phase) FAILED: $_" "ERROR"
            $failedFixes++
            $phaseResults += @{ Phase = $($fix.Phase); Name = $($fix.Name); Status = "FAILED"; Error = "$_" }
            Write-Host ""
            Write-Host "  [ERROR] Phase $($fix.Phase) FAILED" -ForegroundColor Red
            Write-Host ""
        }
    }

    Start-Sleep -Seconds 1
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Header "EXECUTION SUMMARY" "Cyan"

Write-Host "Fixes Completed: $completedFixes / $($fixScripts.Count)" -ForegroundColor $(if ($completedFixes -eq $fixScripts.Count) { "Green" } else { "Yellow" })
Write-Host "Fixes Failed: $failedFixes / $($fixScripts.Count)" -ForegroundColor $(if ($failedFixes -eq 0) { "Green" } else { "Red" })
Write-Host ""

Write-Log "Execution summary: $completedFixes/$($fixScripts.Count) successful" "SUMMARY"

foreach ($result in $phaseResults) {
    $statusColor = if ($result.Status -eq "SUCCESS") { "Green" } else { "Red" }
    $statusIcon = if ($result.Status -eq "SUCCESS") { "[OK]" } else { "[FAIL]" }
    Write-Host "  $statusIcon Phase $($result.Phase): $($result.Name)" -ForegroundColor $statusColor
}

# ============================================================================
# POST-EXECUTION
# ============================================================================

Write-Header "NEXT STEPS" "Green"

if ($DryRun) {
    Write-Host "DRY-RUN COMPLETE - No changes made." -ForegroundColor Magenta
    Write-Host ""
}

if ($failedFixes -eq 0) {
    Write-Host "All fixes completed successfully!" -ForegroundColor Green
    Write-Host ""
    $recommendations = @(
        "1. SYSTEM RESTART (RECOMMENDED)",
        "   Execute: restart-computer -Force",
        "   Or: shutdown /r /t 60 /c 'System optimization - restarting in 60s'",
        "",
        "2. FIRST BOOT AFTER RESTART",
        "   - Boot may take 30-60 seconds longer (normal)",
        "   - CPU/GPU may show high usage briefly (system settling)",
        "   - Wait 5-10 minutes before stress testing",
        "",
        "3. MONITOR SYSTEM (Next 24 Hours)",
        "   - No BSOD crashes",
        "   - No system freezes",
        "   - Thermal readings valid (not 0K)",
        "   - Power scheme locked to 'High Performance'",
        "",
        "4. REVIEW LOGS",
        "   Location: F:\Downloads\fix\",
        "   - master_orchestrator.log",
        "   - cpu_fix.log, gpu_fix.log, ram_fix.log",
        "   - power_thermal_fix.log, bsod_crash_fix.log, hns_docker_fix.log",
        "",
        "5. IF PROBLEMS OCCUR",
        "   - Restore from system restore point: rstrui.exe",
        "   - Check Event Viewer for errors",
        "   - Review BSOD dumps: C:\Windows\Minidump\"
    )

    foreach ($rec in $recommendations) {
        Write-Host $rec -ForegroundColor Cyan
    }
} else {
    Write-Host "WARNING: Some fixes failed - review logs before restarting." -ForegroundColor Yellow
}

Write-Host ""
Write-Header "STATUS: $(if ($failedFixes -eq 0) { 'ALL FIXES COMPLETED' } else { 'COMPLETED WITH WARNINGS' })" $(if ($failedFixes -eq 0) { "Green" } else { "Yellow" })

Write-Host "Master log: $masterLog" -ForegroundColor Yellow
Write-Host ""

Write-Log "=== ORCHESTRATOR EXECUTION FINISHED ===" "END"

if ($failedFixes -eq 0) {
    Write-Host "READY FOR SYSTEM RESTART" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILED - Review logs" -ForegroundColor Red
    exit 1
}
