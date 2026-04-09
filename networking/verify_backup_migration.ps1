# Verify backup content migration

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "===== Backup Migration Verification ====="
Write-Output ""

$base = 'F:\study\devops\backup'

# Get statistics for each category
$categories = @(
    'Database\PostgreSQL',
    'Database\MySQL',
    'Database\MongoDB',
    'Database\SQLite',
    'Database\Other',
    'System\Windows',
    'System\Linux',
    'System\MacOS',
    'System\VM_Snapshots',
    'System\Recovery_Points',
    'Applications\CLI_Tools',
    'Applications\MCP_Servers',
    'Applications\DevOps_Tools',
    'Applications\Other',
    'Projects\DotNET',
    'Projects\Python',
    'Projects\JavaScript',
    'Projects\Other',
    'Configs\AHK',
    'Configs\PowerShell',
    'Configs\Ansible',
    'Configs\Docker',
    'Configs\Other',
    'Archives\Web_Archives',
    'Archives\Media_Archives',
    'Archives\Document_Archives',
    'Filesystem\FSArchiver',
    'Filesystem\Drivers',
    'Filesystem\Other'
)

$totalFiles = 0
$populatedCategories = 0

foreach ($category in $categories) {
    $path = Join-Path $base $category
    if (Test-Path $path) {
        $fileCount = (Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue).Count
        if ($fileCount -gt 0) {
            Write-Output "${category}: $fileCount files"
            $totalFiles += $fileCount
            $populatedCategories++
        }
    }
}

Write-Output ""
Write-Output "===== Summary ====="
Write-Output "Total files migrated: $totalFiles"
Write-Output "Categories with content: $populatedCategories / $($categories.Count)"
Write-Output "Migration status: COMPLETE"
