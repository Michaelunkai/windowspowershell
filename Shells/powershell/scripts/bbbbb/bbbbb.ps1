<#
.SYNOPSIS
    bbbbb
#>
# Fix git ownership issues globally first (silent, fast)
    Write-Host "`n=== Fixing Git Ownership Issues ===" -ForegroundColor Cyan
    $paths = @(
        "F:\backup\windowsapps\install",
        "F:\backup\windowsapps\installed",
        "F:\study",
        "F:\backup\windowsapps\profile",
        "F:\backup\linux\wsl",
        "F:\backup\windowsapps\Credentials",
        "F:\DevKit"
    )

    # Fast git config (sequential for Windows PowerShell 5.1 compatibility)
    foreach ($p in $paths) {
        if (Test-Path $p) {
            git config --global --add safe.directory $p 2>$null
        }
    }
    Write-Host "OK Git ownership configured for all paths" -ForegroundColor Green

    # Sync each path with error handling and progress
    Write-Host "`n=== Starting Sync Operations ===" -ForegroundColor Cyan
    $results = @()

    # Sequential sync (git push requires sequential for reliability)
    $i = 0
    foreach ($path in $paths) {
        $i++
        if (Test-Path $path) {
            Write-Host "`n[$i/$($paths.Count)] Syncing: $path" -ForegroundColor Yellow
            try {
                bbbbn $path
                $results += [PSCustomObject]@{Path=$path; Status="SUCCESS"}
            } catch {
                Write-Host "ERROR: $_" -ForegroundColor Red
                $results += [PSCustomObject]@{Path=$path; Status="FAILED: $_"}
            }
        } else {
            Write-Host "`n[$i/$($paths.Count)] Skipping (not found): $path" -ForegroundColor DarkGray
            $results += [PSCustomObject]@{Path=$path; Status="NOT_FOUND"}
        }
    }

    # Summary
    Write-Host "`n=== Sync Summary ===" -ForegroundColor Cyan
    $results | Format-Table -AutoSize

    $success = ($results | Where-Object Status -like '*SUCCESS*').Count
    $failed = ($results | Where-Object Status -like '*FAILED*').Count
    $skipped = ($results | Where-Object Status -like '*NOT_FOUND*').Count

    Write-Host "`nTotal: $($paths.Count) | Success: $success | Failed: $failed | Skipped: $skipped" -ForegroundColor Cyan
