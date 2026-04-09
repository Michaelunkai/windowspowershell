# Scan all directories except python
$baseDir = "F:\study\Dev_Toolchain\programming"

Get-ChildItem -Path $baseDir -Directory | Where-Object { $_.Name -ne 'python' } | ForEach-Object {
    Write-Host "Folder: $($_.Name)" -ForegroundColor Cyan
    $fileCount = (Get-ChildItem -Path $_.FullName -File -Recurse -Depth 6 -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "  Total files (up to 6 layers): $fileCount"

    # Count subdirectories
    $dirCount = (Get-ChildItem -Path $_.FullName -Directory -Recurse -Depth 6 -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "  Total subdirectories: $dirCount"
    Write-Host ""
}

Write-Host "Scan complete!" -ForegroundColor Green
