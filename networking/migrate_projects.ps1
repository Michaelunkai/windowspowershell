# Migrate portfolio-worthy projects to organized hierarchy
# NOTE: This script COPIES projects (not moves) to preserve originals

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "===== Projects Migration ====="
Write-Output ""

$base = 'F:\study\projects'

# Define portfolio-worthy projects to migrate
# Format: Source -> Destination category
$projects = @{
    # Backend/API - Main project
    'F:\study\tovplay-backend' = 'Backend_API\Python_Flask\tovplay-backend'

    # Web Development - Extensions
    'F:\study\Browsers\extensions\MadeByME' = 'Web_Development\Extensions\MadeByME'
    'F:\study\Browsers\extensions\1337imdb' = 'Web_Development\Extensions\1337imdb'
    'F:\study\Browsers\extensions\Youtube-AdBlocker' = 'Web_Development\Extensions\Youtube-AdBlocker'

    # Web Development - Frontend
    'F:\study\Dev_Toolchain\programming\frontend\javascript\projects\claude-reddit-aggregator' = 'Web_Development\Frontend\claude-reddit-aggregator'
    'F:\study\AI_ML\speach2text\react' = 'Web_Development\Frontend\speech2text-react'

    # DevOps Infrastructure
    'F:\study\Service_Mesh_Orchestration\Orchestration\kubernetes\projects\GitopsWithArgoCD' = 'DevOps_Infrastructure\GitOps\ArgoCD'

    # Automation - PowerShell Tools
    'F:\study\Shells\powershell\scripts\CheckMemoryRamUsage\GUIAPP' = 'Automation_Scripting\PowerShell\MemoryMonitor'
    'F:\study\Shells\powershell\scripts\installRevoUninstallerPROAutomatically' = 'Automation_Scripting\PowerShell\RevoUninstaller-Automation'
    'F:\study\Shells\powershell\scripts\ReinstallAsusDrivers' = 'Automation_Scripting\PowerShell\AsusDrivers-Reinstaller'

    # Automation - Python Tools
    'F:\study\Dev_Toolchain\programming\python\apps\ForcePurgeFolderWin11' = 'Automation_Scripting\Python_Scripts\ForcePurgeFolder'
    'F:\study\Dev_Toolchain\programming\python\apps\RamOptimzer' = 'Automation_Scripting\Python_Scripts\RamOptimizer'
    'F:\study\Dev_Toolchain\programming\python\apps\Uninstaller' = 'Automation_Scripting\System_Tools\Uninstaller'
    'F:\study\Dev_Toolchain\programming\python\apps\laptopdrivers' = 'Automation_Scripting\System_Tools\LaptopDriverManager'
    'F:\study\Dev_Toolchain\programming\python\apps\qbittorrent_throttle' = 'Automation_Scripting\System_Tools\qBittorrent-Throttle'

    # Desktop Apps - C/C++
    'F:\study\Dev_Toolchain\programming\.NET\projects\c++\KillServices' = 'Desktop_Apps\C_Cpp\KillServices'
    'F:\study\Dev_Toolchain\programming\.NET\projects\c\Terminaluninstaller\C' = 'Desktop_Apps\C_Cpp\TerminalUninstaller'

    # Security Tools
    'F:\study\networking\Security\Hacking\Piracy' = 'Security_Tools\Security_Automation\Piracy-Tools'

    # Data Analytics - AI/ML
    'F:\study\AI_ML\AI_and_Machine_Learning\Artificial_Intelligence\prompts' = 'Data_Analytics\AI_ML\AI-Prompts'
    'F:\study\AI_ML\AI_and_Machine_Learning\Datascience\databases\GUITools' = 'Data_Analytics\Database_Tools\GUI-Tools'

    # Mobile Apps - Flutter
    'F:\study\Dev_Toolchain\programming\Flutter\flutter-firestore' = 'Mobile_Apps\Flutter\firebase-firestore-app'
}

# Execute migrations (COPY, not move)
$totalCopied = 0
$totalFailed = 0
$totalSkipped = 0

foreach ($source in $projects.Keys) {
    $destSubPath = $projects[$source]
    $destPath = Join-Path $base $destSubPath

    if (Test-Path $source) {
        Write-Output "Processing: $source"
        Write-Output "  Destination: $destSubPath"

        try {
            # Check if destination already exists
            if (Test-Path $destPath) {
                Write-Output "  Status: SKIPPED (already exists)"
                $totalSkipped++
            } else {
                # Create parent directory if needed
                $parentDir = Split-Path $destPath -Parent
                if (-not (Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }

                # Copy entire directory
                Copy-Item -Path $source -Destination $destPath -Recurse -Force -ErrorAction Stop

                # Count files in copied project
                $fileCount = (Get-ChildItem -Path $destPath -File -Recurse -ErrorAction SilentlyContinue).Count
                Write-Output "  Status: COPIED ($fileCount files)"
                $totalCopied++
            }
        } catch {
            Write-Output "  Status: FAILED - $($_.Exception.Message)"
            $totalFailed++
        }

        Write-Output ""
    } else {
        Write-Output "Source not found (skipped): $source"
        $totalSkipped++
        Write-Output ""
    }
}

Write-Output "===== Migration Summary ====="
Write-Output "Total projects copied: $totalCopied"
Write-Output "Total skipped: $totalSkipped"
Write-Output "Total failures: $totalFailed"
Write-Output ""
Write-Output "NOTE: Original projects remain in place (copied, not moved)"
