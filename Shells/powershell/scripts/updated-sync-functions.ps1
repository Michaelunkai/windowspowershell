# Updated Sync Functions for PowerShell Profile
# Copy these functions to your PowerShell profile

# Original bbbbn function (unchanged)
function bbbbn {
    & "F:\study\shells\powershell\scripts\CodeBerg\codeberg-sync.ps1" -FolderPath @args
}

# Updated bbbb function - syncs all study folders + original paths
function bbbb {
    Write-Host "`n=== BBBB: Quick Sync (Original Paths Only) ===" -ForegroundColor Cyan

    # Original paths
    $paths = @(
        "F:\backup\windowsapps\installed",
        "F:\backup\windowsapps\install",
        "F:\study",
        "F:\backup\windowsapps\profile",
        "F:\backup\linux\wsl",
        "F:\backup\windowsapps\Credentials",
        "F:\DevKit"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Host "`nSyncing: $path" -ForegroundColor Yellow
            Set-Location $path
            gitadd
        }
    }

    Write-Host "`n=== BBBB: Quick Sync Complete ===" -ForegroundColor Green
}

# Updated bbbbb function - syncs ALL study folders (4,971 folders)
function bbbbb {
    Write-Host "`n=== BBBBB: FULL SYNC (All Study Folders + Original Paths) ===" -ForegroundColor Cyan

    # Fix git ownership issues globally first (silent, fast)
    Write-Host "`n=== Fixing Git Ownership Issues ===" -ForegroundColor Cyan
    $basePaths = @(
        "F:\backup\windowsapps\install",
        "F:\backup\windowsapps\installed",
        "F:\study",
        "F:\backup\windowsapps\profile",
        "F:\backup\linux\wsl",
        "F:\backup\windowsapps\Credentials",
        "F:\DevKit"
    )

    # Fast parallel git config (all at once)
    $basePaths | Where-Object { Test-Path $_ } | ForEach-Object -Parallel {
        git config --global --add safe.directory $_ 2>$null
    } -ThrottleLimit 10
    Write-Host "OK Git ownership configured for base paths" -ForegroundColor Green

    # Option 1: Sync base paths with gitadd (original behavior)
    Write-Host "`n=== Syncing Base Paths (Original Method) ===" -ForegroundColor Cyan
    $i = 0
    foreach ($path in $basePaths) {
        $i++
        if (Test-Path $path) {
            Write-Host "`n[$i/$($basePaths.Count)] Syncing: $path" -ForegroundColor Yellow
            try {
                Set-Location $path
                gitadd
                Write-Host "SUCCESS: $path" -ForegroundColor Green
            } catch {
                Write-Host "ERROR: $_" -ForegroundColor Red
            }
        }
    }

    # Option 2: Sync ALL study folders to Codeberg (new behavior)
    Write-Host "`n=== Syncing ALL Study Folders to Codeberg ===" -ForegroundColor Cyan
    Write-Host "This will sync all 4,971 folders in F:\study to Codeberg..." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to cancel, or Enter to continue..." -ForegroundColor Yellow
    Read-Host

    # Run the comprehensive sync script
    & "F:\study\shells\powershell\scripts\sync-all-study-folders.ps1"

    Write-Host "`n=== BBBBB: FULL SYNC COMPLETE ===" -ForegroundColor Green
}

# New function: bbbbbb - sync only study folders (without confirmation)
function bbbbbb {
    Write-Host "`n=== BBBBBB: Study Folders Only (No Confirmation) ===" -ForegroundColor Cyan
    & "F:\study\shells\powershell\scripts\sync-all-study-folders.ps1"
}

# New function: bbbbb-dry - preview what would be synced
function bbbbb-dry {
    Write-Host "`n=== BBBBB DRY RUN: Preview Sync ===" -ForegroundColor Cyan
    & "F:\study\shells\powershell\scripts\sync-all-study-folders.ps1" -DryRun
}

Write-Host "`nSync Functions Loaded:" -ForegroundColor Green
Write-Host "  bbbbn [path]   - Sync single folder to Codeberg" -ForegroundColor White
Write-Host "  bbbb           - Quick sync (original 7 paths)" -ForegroundColor White
Write-Host "  bbbbb          - Full sync (original paths + ALL 4,971 study folders)" -ForegroundColor White
Write-Host "  bbbbbb         - Sync only study folders (no confirmation)" -ForegroundColor White
Write-Host "  bbbbb-dry      - Preview what would be synced" -ForegroundColor White
