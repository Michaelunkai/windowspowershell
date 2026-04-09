# Analyze content in /mnt/f/study/Security_Networking/security

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "===== Analyzing Security Directory Content ====="
Write-Output ""

$securityPath = 'F:\study\Security_Networking\security'

if (Test-Path $securityPath) {
    # Get directory structure
    $subdirs = Get-ChildItem -Path $securityPath -Directory -ErrorAction SilentlyContinue

    Write-Output "Found $($subdirs.Count) subdirectories in security folder:"
    Write-Output ""

    foreach ($dir in $subdirs) {
        $fileCount = (Get-ChildItem -Path $dir.FullName -File -Recurse -ErrorAction SilentlyContinue).Count
        $dirCount = (Get-ChildItem -Path $dir.FullName -Directory -Recurse -ErrorAction SilentlyContinue).Count
        Write-Output "$($dir.Name): $fileCount files, $dirCount subdirectories"
    }

    # Get root files
    $rootFiles = Get-ChildItem -Path $securityPath -File -ErrorAction SilentlyContinue
    Write-Output ""
    Write-Output "Root files: $($rootFiles.Count)"

    # Total statistics
    $totalFiles = (Get-ChildItem -Path $securityPath -File -Recurse -ErrorAction SilentlyContinue).Count
    $totalDirs = (Get-ChildItem -Path $securityPath -Directory -Recurse -ErrorAction SilentlyContinue).Count

    Write-Output ""
    Write-Output "===== Summary ====="
    Write-Output "Total files: $totalFiles"
    Write-Output "Total directories: $totalDirs"
} else {
    Write-Output "Security directory not found at: $securityPath"
}
