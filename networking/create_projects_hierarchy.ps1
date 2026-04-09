# Create organized hierarchy for portfolio projects

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "===== Creating Projects Hierarchy ====="
Write-Output ""

$base = 'F:\study\projects'

# Define hierarchy structure based on discovered projects
$dirs = @(
    # Web Development
    'Web_Development',
    'Web_Development\Frontend',
    'Web_Development\Fullstack',
    'Web_Development\Extensions',
    'Web_Development\Documentation',

    # Backend & API
    'Backend_API',
    'Backend_API\Python_Flask',
    'Backend_API\Node_Express',
    'Backend_API\REST_APIs',
    'Backend_API\GraphQL',

    # DevOps & Infrastructure
    'DevOps_Infrastructure',
    'DevOps_Infrastructure\Docker',
    'DevOps_Infrastructure\Kubernetes',
    'DevOps_Infrastructure\CI_CD',
    'DevOps_Infrastructure\Monitoring',
    'DevOps_Infrastructure\GitOps',

    # Automation & Scripting
    'Automation_Scripting',
    'Automation_Scripting\PowerShell',
    'Automation_Scripting\Python_Scripts',
    'Automation_Scripting\System_Tools',
    'Automation_Scripting\Batch_Scripts',

    # Security Tools
    'Security_Tools',
    'Security_Tools\Penetration_Testing',
    'Security_Tools\Vulnerability_Scanning',
    'Security_Tools\Security_Automation',

    # Data & Analytics
    'Data_Analytics',
    'Data_Analytics\AI_ML',
    'Data_Analytics\Data_Processing',
    'Data_Analytics\Database_Tools',

    # Desktop Applications
    'Desktop_Apps',
    'Desktop_Apps\DotNET',
    'Desktop_Apps\C_Cpp',
    'Desktop_Apps\Python_GUI',

    # Mobile Applications
    'Mobile_Apps',
    'Mobile_Apps\Flutter',
    'Mobile_Apps\React_Native',

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
