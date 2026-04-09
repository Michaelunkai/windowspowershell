# Migrate backup and restore content to organized hierarchy

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "===== Backup Content Migration ====="
Write-Output ""

$base = 'F:\study\devops\backup'

# Define source to destination mappings
$migrations = @{
    # Database backups
    'F:\study\.claude\scripts' = @{
        'Filter' = '*.sql'
        'Dest' = 'Database\PostgreSQL'
    }
    'F:\study\.claude\archive\2024-12-sessions\sql-old' = @{
        'Filter' = '*.sql'
        'Dest' = 'Database\PostgreSQL'
    }

    # System backups - Windows restore point
    'F:\study\Platforms\windows\restore_point' = @{
        'Filter' = '*'
        'Dest' = 'System\Windows'
    }
    'F:\study\troubleshooting\recoverywin11' = @{
        'Filter' = '*'
        'Dest' = 'System\Windows'
    }
    'F:\study\Platforms\windows\lowlevel\.claude\Backups' = @{
        'Filter' = '*'
        'Dest' = 'System\Windows'
    }

    # System backups - VM snapshots
    'F:\study\Systems_Virtualization\virtualmachines\vm_snapshot' = @{
        'Filter' = '*'
        'Dest' = 'System\VM_Snapshots'
    }
    'F:\study\Systems_Virtualization\virtualmachines\vm_backup' = @{
        'Filter' = '*'
        'Dest' = 'System\VM_Snapshots'
    }
    'F:\study\Devops\backup\vm_backup' = @{
        'Filter' = '*'
        'Dest' = 'System\VM_Snapshots'
    }

    # Application backups - CLI tools
    'F:\study\AI_ML\AI_and_Machine_Learning\Artificial_Intelligence\MCP\claudecode\backups' = @{
        'Filter' = '*'
        'Dest' = 'Applications\CLI_Tools'
    }
    'F:\study\AI_ML\AI_and_Machine_Learning\Artificial_Intelligence\cli\claudecode\backup' = @{
        'Filter' = '*'
        'Dest' = 'Applications\CLI_Tools'
    }

    # Project backups - DotNET
    'F:\study\Dev_Toolchain\programming\.NET\projects\c\Terminaluninstaller\C\backup_20251225_154210' = @{
        'Filter' = '*'
        'Dest' = 'Projects\DotNET'
    }
    'F:\study\Dev_Toolchain\programming\.NET\restoreALLdotnetPathsDefault' = @{
        'Filter' = '*'
        'Dest' = 'Projects\DotNET'
    }

    # Python app backups
    'F:\study\Dev_Toolchain\programming\python\apps\laptopdrivers\driver_backups' = @{
        'Filter' = '*'
        'Dest' = 'Projects\Python'
    }

    # Configuration backups - AHK
    'F:\study\Platforms\windows\AutoHotkey\myMainAHK' = @{
        'Filter' = '*.bak'
        'Dest' = 'Configs\AHK'
    }

    # Configuration backups - PowerShell
    'F:\study\Shells\powershell\scripts\AfterReboot\FreeType\afterRestore' = @{
        'Filter' = '*'
        'Dest' = 'Configs\PowerShell'
    }
    'F:\study\Shells\powershell\fixer' = @{
        'Filter' = '*.bak'
        'Dest' = 'Configs\PowerShell'
    }

    # Configuration backups - Ansible
    'F:\study\Devops\Infrastructure_as_Code\ansible\playbooks\tovplay\updates\backups' = @{
        'Filter' = '*'
        'Dest' = 'Configs\Ansible'
    }
    'F:\study\Devops\Infrastructure_as_Code\ansible\playbooks\tovplay\updates' = @{
        'Filter' = '*.bak'
        'Dest' = 'Configs\Ansible'
    }

    # Configuration backups - Macrium Reflect
    'F:\study\Devops\backup\MacriumReflect\DisableGuardPurgeBackups' = @{
        'Filter' = '*'
        'Dest' = 'System\Windows'
    }

    # Archives - Web
    'F:\study\hosting\ArchiveBox' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Web_Archives'
    }
    'F:\study\Version_control\tovtech\push\archive' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Web_Archives'
    }

    # Archives - Media
    'F:\study\hosting\Image\jpeg-archive' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Media_Archives'
    }
    'F:\study\hosting\Image\picdump' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Media_Archives'
    }
    'F:\study\hosting\youtube\rtmpdump' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Media_Archives'
    }
    'F:\study\hosting\youtube\youtube-archive' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Media_Archives'
    }
    'F:\study\hosting\youtube\yt-archive-cli' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Media_Archives'
    }
    'F:\study\hosting\youtube\ytarchiver' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Media_Archives'
    }

    # Archives - Documents
    'F:\study\Docs_Research\Research\LabArchives' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Document_Archives'
    }
    'F:\study\.claude\archive' = @{
        'Filter' = '*'
        'Dest' = 'Archives\Document_Archives'
    }

    # Filesystem backups
    'F:\study\Storage_and_Filesystems\FilesystemManagement\fsarchiver' = @{
        'Filter' = '*'
        'Dest' = 'Filesystem\FSArchiver'
    }

    # Root backup files
    'F:\study\Devops\backup' = @{
        'Filter' = '*.*'
        'Dest' = 'System\Other'
    }
}

# Execute migrations
$totalMoved = 0
$totalFailed = 0

foreach ($source in $migrations.Keys) {
    if (Test-Path $source) {
        $config = $migrations[$source]
        $filter = $config.Filter
        $destSubPath = $config.Dest
        $destPath = Join-Path $base $destSubPath

        Write-Output "Processing: $source"
        Write-Output "  Destination: $destSubPath"

        # Get files to move
        $files = Get-ChildItem -Path $source -Filter $filter -File -ErrorAction SilentlyContinue

        if ($files.Count -gt 0) {
            Write-Output "  Found $($files.Count) files"

            foreach ($file in $files) {
                try {
                    $destFile = Join-Path $destPath $file.Name

                    # Check if file already exists at destination
                    if (Test-Path $destFile) {
                        Write-Output "    Skipped (exists): $($file.Name)"
                    } else {
                        Copy-Item -Path $file.FullName -Destination $destPath -ErrorAction Stop
                        Write-Output "    Moved: $($file.Name)"
                        $totalMoved++
                    }
                } catch {
                    Write-Output "    Failed: $($file.Name) - $($_.Exception.Message)"
                    $totalFailed++
                }
            }
        } else {
            Write-Output "  No files found matching filter: $filter"
        }

        Write-Output ""
    } else {
        Write-Output "Source not found (skipped): $source"
        Write-Output ""
    }
}

Write-Output "===== Migration Summary ====="
Write-Output "Total files moved: $totalMoved"
Write-Output "Total failures: $totalFailed"
