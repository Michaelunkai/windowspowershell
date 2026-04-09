# Create organized hierarchy for backup content

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "===== Creating Backup Content Hierarchy ====="
Write-Output ""

$base = 'F:\study\devops\backup'

# Define hierarchy structure
$dirs = @(
    # Database backups
    'Database',
    'Database\PostgreSQL',
    'Database\MySQL',
    'Database\MongoDB',
    'Database\SQLite',
    'Database\Other',

    # System backups
    'System',
    'System\Windows',
    'System\Linux',
    'System\MacOS',
    'System\VM_Snapshots',
    'System\Recovery_Points',

    # Application backups
    'Applications',
    'Applications\CLI_Tools',
    'Applications\MCP_Servers',
    'Applications\DevOps_Tools',
    'Applications\Other',

    # Code/Project backups
    'Projects',
    'Projects\DotNET',
    'Projects\Python',
    'Projects\JavaScript',
    'Projects\Other',

    # Configuration backups
    'Configs',
    'Configs\AHK',
    'Configs\PowerShell',
    'Configs\Ansible',
    'Configs\Docker',
    'Configs\Other',

    # Archive storage
    'Archives',
    'Archives\Web_Archives',
    'Archives\Media_Archives',
    'Archives\Document_Archives',

    # Filesystem backups
    'Filesystem',
    'Filesystem\FSArchiver',
    'Filesystem\Drivers',
    'Filesystem\Other',

    # Documentation
    'Documentation'
)

foreach ($dir in $dirs) {
    $fullPath = Join-Path $base $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Output "Created: $dir"
    } else {
        Write-Output "Exists: $dir"
    }
}

Write-Output ""
Write-Output "===== Hierarchy Creation Complete ====="
Write-Output "Total directories: $($dirs.Count)"
