# MSERT Threat Cleaner - Auto-removes high-risk threats after scan
# Runs after MSERT completes to clean up any active Defender threats
# Safe: only removes Severe/High threats, logs everything, skips known false positives

param(
    [switch]$DryRun  # Use -DryRun to see what would be removed without actually removing
)

$LogFile = "$PSScriptRoot\removal-log.txt"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Write-Log {
    param($Message, $Color = "White")
    $LogLine = "[$Timestamp] $Message"
    Write-Host $LogLine -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $LogLine -ErrorAction SilentlyContinue
}

# Known false positives / intentional tools - skip these
$FalsePositives = @(
    "JackettUpdater.dll",       # Jackett torrent indexer - legitimate
    "jackett",                   # Jackett related
    "WeModPatcher",              # WeMod game trainer - intentional
    "PowerShell_profile.ps1",    # Your own PS profile - AMSI false positive
    "msert-auto.ps1",            # Our own script
    "RemoveDefender",            # Defender removal tools you put there intentionally
    "DefenderRemover",           # Same
    "DisableDefenderPolicies"    # Same
)

Write-Log "=== MSERT Threat Cleaner Started ===" "Cyan"

# Get all active (not-yet-cleaned) threats
# CurrentThreatExecutionStatusID: 1 = Active/Not Cleaned, 3 = Partially removed
$ActiveThreats = Get-MpThreat -ErrorAction SilentlyContinue | Where-Object {
    $_.ThreatSeverityID -ge 4  # 4=High, 5=Severe
}

$Detections = Get-MpThreatDetection -ErrorAction SilentlyContinue | Where-Object {
    $_.CurrentThreatExecutionStatusID -in @(1, 3)  # Active or partially removed
}

if (-not $ActiveThreats -and -not $Detections) {
    Write-Log "No active high-risk threats found. System clean." "Green"
    exit 0
}

Write-Log "Found $(@($ActiveThreats).Count) high-risk threats, $(@($Detections).Count) active detections" "Yellow"

$RemovedCount = 0
$SkippedCount = 0
$FailedCount = 0

# Process active threat detections
foreach ($Detection in $Detections) {
    foreach ($Resource in $Detection.Resources) {
        # Extract file path from resource string (format: "file:_C:\path\to\file")
        $FilePath = $Resource -replace '^file:_', '' -replace '^CmdLine:_.*', '' -replace '^amsi:_', '' -replace '^behavior:_.*', ''
        
        if ([string]::IsNullOrWhiteSpace($FilePath) -or $FilePath -notmatch '^[A-Za-z]:\\') {
            continue  # Skip non-file resources (CmdLine, behavior, amsi detections)
        }

        # Check if this is a known false positive
        $IsFalsePositive = $false
        foreach ($FP in $FalsePositives) {
            if ($FilePath -like "*$FP*") {
                $IsFalsePositive = $true
                break
            }
        }

        if ($IsFalsePositive) {
            Write-Log "SKIP (known tool): $FilePath" "DarkGray"
            $SkippedCount++
            continue
        }

        Write-Log "THREAT DETECTED: $FilePath" "Red"

        if ($DryRun) {
            Write-Log "  [DRY RUN] Would remove: $FilePath" "Yellow"
            $RemovedCount++
            continue
        }

        # Try to remove via Defender first (cleanest method)
        try {
            Remove-MpThreat -ErrorAction SilentlyContinue
            Write-Log "  [+] Defender remediation triggered" "Green"
        } catch {
            Write-Log "  [!] Defender removal failed: $_" "Yellow"
        }

        # Also delete the file directly if it exists
        if (Test-Path $FilePath) {
            try {
                # Try normal deletion first
                Remove-Item -Path $FilePath -Force -ErrorAction Stop
                Write-Log "  [+] File deleted: $FilePath" "Green"
                $RemovedCount++
            } catch {
                # File is locked - schedule for deletion on reboot
                Write-Log "  [!] File locked, scheduling deletion on reboot: $FilePath" "Yellow"
                try {
                    # Use MoveFileEx to schedule deletion
                    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class FileUtils {
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);
    public const int MOVEFILE_DELAY_UNTIL_REBOOT = 0x4;
}
"@
                    $Result = [FileUtils]::MoveFileEx($FilePath, $null, [FileUtils]::MOVEFILE_DELAY_UNTIL_REBOOT)
                    if ($Result) {
                        Write-Log "  [+] Scheduled for deletion on next reboot: $FilePath" "Yellow"
                        $RemovedCount++
                    } else {
                        Write-Log "  [X] Failed to schedule deletion: $FilePath" "Red"
                        $FailedCount++
                    }
                } catch {
                    Write-Log "  [X] Could not remove: $FilePath - $_" "Red"
                    $FailedCount++
                }
            }
        } else {
            Write-Log "  [i] File already gone (quarantined): $FilePath" "Green"
            $RemovedCount++
        }
    }
}

# Also handle Jackett specifically - add exclusion so it stops flagging it
$JackettDll = "C:\ProgramData\Jackett\JackettUpdater.dll"
if (Test-Path $JackettDll) {
    Write-Log "Adding Defender exclusion for Jackett (legitimate tool)..." "Cyan"
    if (-not $DryRun) {
        Add-MpPreference -ExclusionPath "C:\ProgramData\Jackett" -ErrorAction SilentlyContinue
        Write-Log "  [+] Exclusion added for C:\ProgramData\Jackett" "Green"
    } else {
        Write-Log "  [DRY RUN] Would add exclusion for C:\ProgramData\Jackett" "Yellow"
    }
}

Write-Log "=== Summary ===" "Cyan"
Write-Log "  Removed/Scheduled: $RemovedCount" "Green"
Write-Log "  Skipped (safe tools): $SkippedCount" "DarkGray"
Write-Log "  Failed: $FailedCount" $(if ($FailedCount -gt 0) { "Red" } else { "Green" })
Write-Log "  Log saved to: $LogFile" "White"

if ($RemovedCount -gt 0) {
    Write-Log "Threats cleaned. Next scan should show fewer detections." "Green"
} else {
    Write-Log "No files needed removal (already quarantined or no high-risk files)." "Green"
}
