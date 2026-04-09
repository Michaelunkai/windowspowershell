# Find all portfolio-worthy projects in F:\study\

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "===== Searching for Portfolio-Worthy Projects ====="
Write-Output ""

# Define project indicators
$projectIndicators = @(
    'package.json',  # Node.js projects
    'requirements.txt',  # Python projects
    'Cargo.toml',  # Rust projects
    'go.mod',  # Go projects
    'pom.xml',  # Java Maven projects
    'build.gradle',  # Java Gradle projects
    'Gemfile',  # Ruby projects
    'composer.json',  # PHP projects
    '.csproj',  # C# projects
    'Dockerfile',  # Containerized projects
    'docker-compose.yml',  # Multi-container projects
    'README.md'  # Documented projects
)

# Search for project directories
$projectDirs = @()

foreach ($indicator in $projectIndicators) {
    $found = Get-ChildItem -Path 'F:\study\' -Recurse -Filter $indicator -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.FullName -notmatch 'node_modules|\.git|venv|__pycache__|target|dist|build' }

    foreach ($file in $found) {
        $projectDir = $file.Directory.FullName
        if ($projectDirs -notcontains $projectDir) {
            $projectDirs += $projectDir
        }
    }
}

Write-Output "Found $($projectDirs.Count) potential project directories:"
Write-Output ""

# Categorize projects
$categorized = @{
    'Web_Development' = @()
    'Backend_API' = @()
    'DevOps_Infrastructure' = @()
    'Automation_Scripting' = @()
    'Security_Tools' = @()
    'Data_Analytics' = @()
    'Other' = @()
}

foreach ($dir in $projectDirs) {
    $dirName = Split-Path $dir -Leaf
    $hasPackageJson = Test-Path (Join-Path $dir 'package.json')
    $hasRequirements = Test-Path (Join-Path $dir 'requirements.txt')
    $hasDockerfile = Test-Path (Join-Path $dir 'Dockerfile')
    $hasDockerCompose = Test-Path (Join-Path $dir 'docker-compose.yml')

    # Count files to determine project size
    $fileCount = (Get-ChildItem -Path $dir -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.FullName -notmatch 'node_modules|\.git|venv' }).Count

    $projectInfo = @{
        'Path' = $dir
        'Name' = $dirName
        'Files' = $fileCount
        'HasPackageJson' = $hasPackageJson
        'HasRequirements' = $hasRequirements
        'HasDocker' = $hasDockerfile
        'HasDockerCompose' = $hasDockerCompose
    }

    # Categorize based on content and name
    if ($dir -match 'frontend|react|vue|angular|website|web-app' -or ($hasPackageJson -and $dir -match 'client|ui')) {
        $categorized['Web_Development'] += $projectInfo
    }
    elseif ($dir -match 'backend|api|server' -or ($hasRequirements -and $dir -match 'flask|django|fastapi')) {
        $categorized['Backend_API'] += $projectInfo
    }
    elseif ($dir -match 'devops|infrastructure|deploy|docker|kubernetes|terraform|ansible' -or $hasDockerCompose) {
        $categorized['DevOps_Infrastructure'] += $projectInfo
    }
    elseif ($dir -match 'automation|script|tool|utility') {
        $categorized['Automation_Scripting'] += $projectInfo
    }
    elseif ($dir -match 'security|hack|pentest|exploit') {
        $categorized['Security_Tools'] += $projectInfo
    }
    elseif ($dir -match 'data|analytics|ml|ai|analysis') {
        $categorized['Data_Analytics'] += $projectInfo
    }
    else {
        $categorized['Other'] += $projectInfo
    }
}

# Display categorized projects
foreach ($category in $categorized.Keys | Sort-Object) {
    $projects = $categorized[$category]
    if ($projects.Count -gt 0) {
        Write-Output "===== $category ($($projects.Count) projects) ====="
        foreach ($project in $projects | Sort-Object -Property Files -Descending) {
            Write-Output "$($project.Name): $($project.Files) files"
            Write-Output "  Path: $($project.Path)"
            if ($project.HasPackageJson) { Write-Output "  - Node.js project" }
            if ($project.HasRequirements) { Write-Output "  - Python project" }
            if ($project.HasDocker) { Write-Output "  - Dockerized" }
            if ($project.HasDockerCompose) { Write-Output "  - Docker Compose" }
            Write-Output ""
        }
    }
}

Write-Output ""
Write-Output "===== Summary ====="
Write-Output "Total projects found: $($projectDirs.Count)"
foreach ($category in $categorized.Keys | Sort-Object) {
    $count = $categorized[$category].Count
    Write-Output "${category}: $count"
}
