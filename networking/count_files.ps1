$totalFiles = (Get-ChildItem 'F:\study\networking' -Recurse -File -ErrorAction SilentlyContinue).Count
$totalDirs = (Get-ChildItem 'F:\study\networking' -Recurse -Directory -ErrorAction SilentlyContinue).Count
Write-Output "Total Files: $totalFiles"
Write-Output "Total Directories: $totalDirs"
