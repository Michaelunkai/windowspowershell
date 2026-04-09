# Move remaining hacking content

$ErrorActionPreference = 'Continue'
$base = 'F:\study\networking'

Write-Output "===== Moving Additional Hacking Content ====="

# Get all remaining hacking subdirectories
$hackingPath = 'F:\study\Security_Networking\Hacking'
$targetPath = Join-Path $base 'Security\Hacking'

if (Test-Path $hackingPath) {
    $subdirs = Get-ChildItem -Path $hackingPath -Directory

    foreach ($subdir in $subdirs) {
        Write-Output "Moving Hacking\$($subdir.Name)"
        $destFolder = Join-Path $targetPath $subdir.Name

        if (-not (Test-Path $destFolder)) {
            New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
        }

        # Move all content from subdir to destination
        Get-ChildItem -Path $subdir.FullName -Recurse | ForEach-Object {
            try {
                Move-Item -Path $_.FullName -Destination $destFolder -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Output "  Warning: Could not move $($_.Name)"
            }
        }
    }

    # Move any remaining root files
    Get-ChildItem -Path $hackingPath -File | ForEach-Object {
        Write-Output "Moving Hacking root file: $($_.Name)"
        Move-Item -Path $_.FullName -Destination $targetPath -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ""
Write-Output "===== Cleanup ====="

# Remove empty directories
if (Test-Path $hackingPath) {
    $fileCount = (Get-ChildItem -Path $hackingPath -Recurse -File).Count
    if ($fileCount -eq 0) {
        Remove-Item -Path $hackingPath -Recurse -Force
        Write-Output "Removed empty Hacking directory"
    }
}

if (Test-Path 'F:\study\Security_Networking') {
    $fileCount = (Get-ChildItem -Path 'F:\study\Security_Networking' -Recurse -File).Count
    if ($fileCount -eq 0) {
        Remove-Item -Path 'F:\study\Security_Networking' -Recurse -Force
        Write-Output "Removed empty Security_Networking directory"
    }
}

Write-Output ""
Write-Output "Move operation complete!"
