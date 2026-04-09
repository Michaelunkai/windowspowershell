# Check remaining content in source folders

$paths = @('F:\study\Security_Networking\Cisco', 'F:\study\Security_Networking\Hacking', 'F:\study\Security_Networking\security')

foreach ($p in $paths) {
    $fileCount = (Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue).Count
    $dirCount = (Get-ChildItem -Path $p -Directory -ErrorAction SilentlyContinue).Count
    Write-Output "$p - Files: $fileCount, Dirs: $dirCount"
}
