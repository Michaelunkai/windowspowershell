# Sync All Study Folders Script
# Syncs all folders in F:\study up to 13 layers deep to Codeberg

param(
    [switch]$DryRun,
    [int]$MaxDepth = 13
)

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "   SYNC ALL STUDY FOLDERS TO CODEBERG" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# Get all folders in F:\study up to specified depth
Write-Host "Scanning F:\study for folders (depth: $MaxDepth)..." -ForegroundColor Yellow
$allFolders = Get-ChildItem -Path 'F:\study' -Directory -Recurse -Depth $MaxDepth -ErrorAction SilentlyContinue |
              Select-Object -ExpandProperty FullName |
              Sort-Object

$totalFolders = $allFolders.Count
Write-Host "Found $totalFolders folders to sync`n" -ForegroundColor Green

if ($DryRun) {
    Write-Host "DRY RUN MODE - No actual syncing will occur`n" -ForegroundColor Magenta
    $allFolders | Select-Object -First 20
    Write-Host "`n... and $($totalFolders - 20) more folders" -ForegroundColor DarkGray
    Write-Host "`nRun without -DryRun to perform actual sync" -ForegroundColor Yellow
    exit
}

# Track results
$results = [System.Collections.Concurrent.ConcurrentBag[PSObject]]::new()
$successCount = 0
$failCount = 0
$skipCount = 0
$current = 0

# Process each folder
foreach ($folder in $allFolders) {
    $current++
    $percent = [math]::Round(($current / $totalFolders) * 100, 1)

    Write-Host "`n[$current/$totalFolders - $percent%] " -NoNewline -ForegroundColor Cyan
    Write-Host $folder -ForegroundColor Yellow

    try {
        # Run bbbbn for this folder
        & "F:\study\shells\powershell\scripts\CodeBerg\codeberg-sync.ps1" -FolderPath $folder

        if ($LASTEXITCODE -eq 0 -or $?) {
            $results.Add([PSCustomObject]@{
                Folder = $folder
                Status = "SUCCESS"
                Error = ""
            })
            $successCount++
        } else {
            $results.Add([PSCustomObject]@{
                Folder = $folder
                Status = "FAILED"
                Error = "Exit code: $LASTEXITCODE"
            })
            $failCount++
        }
    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        $results.Add([PSCustomObject]@{
            Folder = $folder
            Status = "FAILED"
            Error = $_.Exception.Message
        })
        $failCount++
    }

    # Progress update every 100 folders
    if ($current % 100 -eq 0) {
        Write-Host "`nProgress: $successCount succeeded, $failCount failed, $skipCount skipped" -ForegroundColor Cyan
    }
}

# Final Summary
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "   SYNC COMPLETE - SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Total Folders: $totalFolders" -ForegroundColor White
Write-Host "Success: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host "Skipped: $skipCount" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Cyan

# Export results to file
$resultsFile = "F:\study\sync-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$results | Export-Csv -Path $resultsFile -NoTypeInformation -Encoding UTF8
Write-Host "Detailed results saved to: $resultsFile" -ForegroundColor Cyan

# Show failed folders if any
if ($failCount -gt 0) {
    Write-Host "`nFailed Folders:" -ForegroundColor Red
    $results | Where-Object Status -eq 'FAILED' | Format-Table -AutoSize
}
