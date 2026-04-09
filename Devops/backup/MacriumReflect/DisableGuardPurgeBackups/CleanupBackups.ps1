# Macrium Reflect Backup Cleanup Script v3.0
# Disables Image Guardian, keeps most recent backup, deletes old backups, creates new backup
# Run as Administrator

$ErrorActionPreference = "Continue"
$LogFile = "F:\reflect_cleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$TargetPath = "F:\win11recovery"
$BackupExePath = "F:\backup\windowsapps\installed\reflect\mrauto.exe"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogFile -Value $logEntry
}

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "ERROR: Run as Administrator!"; exit 1 }

Write-Log "========== CLEANUP STARTED =========="

# Get all backup files
$allFiles = Get-ChildItem -Path $TargetPath -Filter "backup*" -File -ErrorAction SilentlyContinue

# Separate complete backups from temp/running files
$completeBackups = $allFiles | Where-Object { $_.Name -match '^backup_\d{8}_\d{6}-\d{2}-\d{2}\.mrimg$' } | Sort-Object LastWriteTime -Descending
$tempFiles = $allFiles | Where-Object { $_.Name -notmatch '^backup_\d{8}_\d{6}-\d{2}-\d{2}\.mrimg$' }

$totalSizeBefore = ($allFiles | Measure-Object -Property Length -Sum).Sum
Write-Log "Found $($allFiles.Count) backup files ($([math]::Round($totalSizeBefore/1GB,2)) GB)"
Write-Log "  - Complete backups: $($completeBackups.Count)"
Write-Log "  - Temp/running files: $($tempFiles.Count)"

foreach ($f in $allFiles) {
    Write-Log "  - $($f.FullName) ($([math]::Round($f.Length/1GB,2)) GB)"
}

if ($completeBackups.Count -eq 0) {
    Write-Log "No complete backup files found."
}

# Disable Image Guardian (with error handling for missing registry keys)
Write-Log "Disabling Image Guardian..."
Stop-Process -Name "ReflectUI","ReflectMonitor" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "MacriumService" -Force -ErrorAction SilentlyContinue

# Try to disable MIG (exists in registry)
try {
    if (Test-Path "HKLM:\SOFTWARE\Macrium\reflect\MIG") {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Macrium\reflect\MIG" -Name "Enabled" -Value 0 -ErrorAction Stop
        Write-Log "MIG disabled successfully"
    } else {
        Write-Log "MIG registry path not found (skipping)" "WARN"
    }
} catch {
    Write-Log "Failed to disable MIG: $($_.Exception.Message)" "WARN"
}

# ImageGuardian path doesn't exist, skip it
Write-Log "ImageGuardian registry path doesn't exist (skipping)"

Start-Service -Name "MacriumService" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Log "Image Guardian operations completed"

# Delete ALL existing backups (new one will be created at the end)
$deleted = 0
$failed = 0
$totalFreed = 0

if ($completeBackups.Count -gt 0) {
    Write-Log "Deleting ALL $($completeBackups.Count) existing backup(s)..."
    
    foreach ($f in $completeBackups) {
        try {
            Write-Log "Deleting: $($f.FullName)"
            $size = $f.Length
            Remove-Item -Path $f.FullName -Force -ErrorAction Stop
            $deleted++
            $totalFreed += $size
        } catch {
            Write-Log "FAILED: $($f.FullName) - $($_.Exception.Message)" "ERROR"
            $failed++
        }
    }
} else {
    Write-Log "No complete backups found to delete"
}

# Delete temp/running files
if ($tempFiles.Count -gt 0) {
    Write-Log "Deleting $($tempFiles.Count) temp/running file(s)..."
    foreach ($f in $tempFiles) {
        try {
            Write-Log "Deleting temp: $($f.FullName)"
            $size = $f.Length
            Remove-Item -Path $f.FullName -Force -ErrorAction Stop
            $deleted++
            $totalFreed += $size
        } catch {
            Write-Log "FAILED: $($f.FullName) - $($_.Exception.Message)" "ERROR"
            $failed++
        }
    }
}

# Verify
$remaining = Get-ChildItem -Path $TargetPath -Filter "backup*" -File -ErrorAction SilentlyContinue
Write-Log "Verification: $($remaining.Count) files remaining"

# Re-enable Image Guardian
Write-Log "Re-enabling Image Guardian..."
try {
    if (Test-Path "HKLM:\SOFTWARE\Macrium\reflect\MIG") {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Macrium\reflect\MIG" -Name "Enabled" -Value 1 -ErrorAction Stop
        Write-Log "MIG re-enabled successfully"
    }
} catch {
    Write-Log "Failed to re-enable MIG: $($_.Exception.Message)" "WARN"
}

# Summary
Write-Log "========== CLEANUP SUMMARY =========="
Write-Log "Files deleted: $deleted"
Write-Log "Files failed: $failed"
Write-Log "Space freed: $([math]::Round($totalFreed/1GB,2)) GB"
Write-Log "Remaining: $($remaining.Count)"
Write-Log "Log: $LogFile"

# Create new backup
Write-Log "========== CREATING NEW BACKUP =========="
$backupName = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Write-Log "Starting backup: $backupName"

try {
    if (Test-Path $BackupExePath) {
        & $BackupExePath -b $TargetPath $backupName C: --stealth --quiet
        Write-Log "Backup command executed successfully"
    } else {
        Write-Log "ERROR: Backup executable not found at $BackupExePath" "ERROR"
    }
} catch {
    Write-Log "ERROR: Failed to create backup - $($_.Exception.Message)" "ERROR"
}

Write-Log "========== COMPLETED =========="
