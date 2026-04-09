# Master Orchestrator - Run ALL System Fixes in Sequence
# Integrates: CPU, GPU, RAM, Power/Thermal, BSOD, HNS/Docker fixes
# Date: 2025-12-12

param(
    [switch]$SkipBackup = $false,
    [switch]$Verbose = $false
)

# ============================================================================
# INITIALIZATION
# ============================================================================

$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

$masterLog = "F:\Downloads\fix\master_orchestrator.log"
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesDir = Join-Path $baseDir "modules"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $masterLog -Value $entry -Force -EA 0
    Write-Host $entry -ForegroundColor Cyan
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

Write-Host "`n" -ForegroundColor White
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  WINDOWS 11 COMPLETE SYSTEM FIX ORCHESTRATOR v1.0" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Master Orchestrator Started" "START"

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script REQUIRES Administrator privileges!" -ForegroundColor Red
    Write-Log "Admin check FAILED - aborting" "ERROR"
    exit 1
}
Write-Log "Admin privileges: VERIFIED" "OK"

# Create logs directory
if (-not (Test-Path "F:\Downloads\fix")) {
    New-Item -Path "F:\Downloads\fix" -ItemType Directory -Force -EA 0 | Out-Null
    Write-Log "Created logs directory: F:\Downloads\fix" "OK"
}

# Check modules exist
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
    if (-not (Test-Path $modulePath)) {
        $missingModules += $module
        Write-Log "Module NOT found: $module" "ERROR"
    } else {
        Write-Log "Module found: $module" "OK"
    }
}

if ($missingModules.Count -gt 0) {
    Write-Host "ERROR: Missing $($missingModules.Count) required modules!" -ForegroundColor Red
    Write-Host "Missing: $($missingModules -join ', ')" -ForegroundColor Red
    exit 1
}

# ============================================================================
# SYSTEM BACKUP
# ============================================================================

if (-not $SkipBackup) {
    Write-Log "Creating system backup/restore point..." "START"

    try {
        # Create system restore point
        if ((Get-ComputerRestorePoint -EA 0 | Measure-Object).Count -lt 10) {
            Write-Log "Creating system restore point (current: < 10 points)" "INFO"
            Checkpoint-Computer -Description "Before System Optimization Fixes" -RestorePointType "Modify_Settings" -EA 0 | Out-Null
            Write-Log "System restore point created" "OK"
        } else {
            Write-Log "System restore points already exist (skipping)" "OK"
        }

        # Backup registry
        Write-Log "Backing up critical registry keys..." "INFO"
        $regBackupPath = "F:\Downloads\fix\registry_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"

        # Export HKEY_LOCAL_MACHINE\SYSTEM key
        reg export HKLM\SYSTEM "$regBackupPath" /y 2>&1 | Out-Null
        Write-Log "Registry backup created: $regBackupPath" "OK"

    } catch {
        Write-Log "Backup warning (non-critical): $_" "WARN"
    }
}

# ============================================================================
# EXECUTION PHASE - RUN ALL FIXES IN SEQUENCE
# ============================================================================

Write-Host "`n" -ForegroundColor White
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  EXECUTING SYSTEM FIXES (6 PHASES)" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host ""

$fixScripts = @(
    @{ Name = "CPU Performance"; File = "fix_cpu_performance.ps1"; Phase = 1 },
    @{ Name = "GPU Performance"; File = "fix_gpu_performance.ps1"; Phase = 2 },
    @{ Name = "RAM/Memory"; File = "fix_ram_memory.ps1"; Phase = 3 },
    @{ Name = "Power/Thermal"; File = "fix_power_thermal.ps1"; Phase = 4 },
    @{ Name = "BSOD/Crash"; File = "fix_bsod_crashes.ps1"; Phase = 5 },
    @{ Name = "HNS/Docker"; File = "fix_hns_docker.ps1"; Phase = 6 }
)

$completedFixes = 0
$failedFixes = 0

foreach ($fix in $fixScripts) {
    $scriptPath = Join-Path $modulesDir $fix.File
    $phaseName = "[$($fix.Phase)/6] $($fix.Name) Fix"

    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Yellow
    Write-Host "  $phaseName" -ForegroundColor Yellow
    Write-Host "=====================================================================" -ForegroundColor Yellow

    Write-Log "Executing Phase $($fix.Phase): $($fix.Name)" "PHASE"

    try {
        # Execute fix script
        & $scriptPath -Verbose:$Verbose -EA Continue

        Write-Log "Phase $($fix.Phase) COMPLETED: $($fix.Name)" "COMPLETE"
        $completedFixes++

        Write-Host ""
        Write-Host "  Status: COMPLETED" -ForegroundColor Green
        Write-Host ""

    } catch {
        Write-Log "Phase $($fix.Phase) FAILED: $($fix.Name) - $_" "ERROR"
        $failedFixes++

        Write-Host ""
        Write-Host "  Status: FAILED - $_" -ForegroundColor Red
        Write-Host ""
    }

    Start-Sleep -Seconds 2
}

# ============================================================================
# FINAL VERIFICATION & SUMMARY
# ============================================================================

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  EXECUTION SUMMARY" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Fixes Completed: $completedFixes / 6" -ForegroundColor $(if ($completedFixes -eq 6) { "Green" } else { "Yellow" })
Write-Host "Fixes Failed: $failedFixes / 6" -ForegroundColor $(if ($failedFixes -eq 0) { "Green" } else { "Red" })

Write-Log "Master orchestrator execution complete: $completedFixes/$($fixScripts.Count) successful" "SUMMARY"

# ============================================================================
# POST-EXECUTION RECOMMENDATIONS
# ============================================================================

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  NEXT STEPS" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host ""

$recommendations = @(
    "1. System Restart (RECOMMENDED)",
    "   - Restart computer to apply all kernel-level and pagefile changes",
    "   - Power off completely, wait 30s, then power on",
    "   - Boot time may be slightly longer on first boot",
    "",
    "2. Monitor System Behavior",
    "   - Watch for any crashes or errors over next 24 hours",
    "   - Check Event Viewer for any warning/error events",
    "   - Monitor system temperatures (no THERMAL events)",
    "   - Monitor CPU/GPU usage (no excessive throttling)",
    "",
    "3. Review Fix Logs",
    "   - F:\Downloads\fix\cpu_fix.log",
    "   - F:\Downloads\fix\gpu_fix.log",
    "   - F:\Downloads\fix\ram_fix.log",
    "   - F:\Downloads\fix\power_thermal_fix.log",
    "   - F:\Downloads\fix\bsod_crash_fix.log",
    "   - F:\Downloads\fix\hns_docker_fix.log",
    "   - F:\Downloads\fix\master_orchestrator.log",
    "",
    "4. Re-Run Diagnostics",
    "   - After restart, run: logs",
    "   - Compare results to initial scan (F:\study\shells\powershell\fixer\a.txt)",
    "   - Verify all CRITICAL issues are resolved",
    "",
    "5. If Problems Persist",
    "   - Restore from system restore point if major issues occur",
    "   - Review BSOD crash dumps (C:\Windows\Minidump)",
    "   - Check hardware health (thermals, RAM, storage)",
    "   - Consider BIOS update if available",
    "",
    "6. Performance Optimization",
    "   - Run gaming/workload tests to verify fixes",
    "   - Check GPU/CPU temperatures under load",
    "   - Verify Docker/HNS networking if used"
)

foreach ($rec in $recommendations) {
    Write-Host $rec -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  STATUS: $(if ($failedFixes -eq 0) { 'ALL FIXES COMPLETED' } else { 'COMPLETED WITH WARNINGS' })" -ForegroundColor $(if ($failedFixes -eq 0) { "Green" } else { "Yellow" })
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Master log: $masterLog" -ForegroundColor Yellow
Write-Host ""

Write-Log "=== ORCHESTRATOR EXECUTION FINISHED ===" "END"

if ($failedFixes -eq 0) {
    Write-Host "READY FOR SYSTEM RESTART" -ForegroundColor Green
} else {
    Write-Host "WARNING: Some fixes failed - review logs before restart" -ForegroundColor Yellow
}

exit 0
