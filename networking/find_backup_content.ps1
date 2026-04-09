# Find all backup and restore related content in F:\study\

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "===== Searching for Backup/Restore Related Directories ====="
Write-Output ""

# Search for directories with backup-related names
$backupDirs = Get-ChildItem -Path 'F:\study\' -Recurse -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'backup|restore|recovery|archive|snapshot|dump' }

Write-Output "Found $($backupDirs.Count) backup-related directories:"
Write-Output ""

foreach ($dir in $backupDirs) {
    $fileCount = (Get-ChildItem -Path $dir.FullName -File -Recurse -ErrorAction SilentlyContinue).Count
    Write-Output "$($dir.FullName) ($fileCount files)"
}

Write-Output ""
Write-Output "===== Searching for Backup/Restore Related Files ====="
Write-Output ""

# Search for common backup file extensions
$backupFiles = Get-ChildItem -Path 'F:\study\' -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '\.bak|\.backup|\.sql|\.dump|\.tar|\.gz|\.zip' -and $_.Directory.FullName -notmatch 'node_modules|\.git|venv' }

Write-Output "Found $($backupFiles.Count) backup files:"
Write-Output ""

# Group by directory
$backupFiles | Group-Object { $_.Directory.FullName } | ForEach-Object {
    Write-Output "$($_.Name): $($_.Count) files"
}

Write-Output ""
Write-Output "===== Summary ====="
Write-Output "Total backup directories: $($backupDirs.Count)"
Write-Output "Total backup files: $($backupFiles.Count)"
