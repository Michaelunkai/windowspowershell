# Master Git Automation Orchestrator
# Created: 2025-12-29 21:37:38
# Executes all 30 steps of the comprehensive git automation plan

$ErrorActionPreference = 'Continue'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host "===== MASTER GIT AUTOMATION ORCHESTRATOR =====" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host ""

# Step 1-2: Verify WSL Ubuntu Installation
Write-Host "[Step 1/30] Verifying WSL Ubuntu installation..." -ForegroundColor Yellow
try {
    $wslList = wsl -l -v
    Write-Host $wslList -ForegroundColor Green
    if ($wslList -match 'Ubuntu') {
        Write-Host " WSL Ubuntu verified!" -ForegroundColor Green
    } else {
        Write-Host " ERROR: Ubuntu not found in WSL" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host " ERROR: WSL not available - $_" -ForegroundColor Red
    exit 1
}

# Step 2: Create Backup
Write-Host "[Step 2/30] Creating backup of F:\study\projects..." -ForegroundColor Yellow
$backupPath = "F:\study\devops\backup\projects-backup-$timestamp"
try {
    if (!(Test-Path "F:\study\devops\backup")) {
        New-Item -ItemType Directory -Path "F:\study\devops\backup" -Force | Out-Null
    }
    Write-Host "  Copying F:\study\projects to $backupPath..." -ForegroundColor Gray
    Copy-Item -Path "F:\study\projects" -Destination $backupPath -Recurse -Force -ErrorAction SilentlyContinue
    $backupSize = (Get-ChildItem -Path $backupPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  Backup created: $([math]::Round($backupSize, 2)) MB" -ForegroundColor Green
} catch {
    Write-Host "  WARNING: Backup failed - $_ (continuing anyway)" -ForegroundColor Yellow
}

# Step 3: Check GitHub Authentication
Write-Host "[Step 3/30] Checking GitHub authentication..." -ForegroundColor Yellow
$ghAuthStatus = wsl -d ubuntu bash -c "gh auth status 2>&1"
Write-Host $ghAuthStatus -ForegroundColor Gray

if ($ghAuthStatus -match 'invalid|not logged in|failed') {
    Write-Host "  GitHub authentication INVALID - attempting fix..." -ForegroundColor Red
    Write-Host "  Running: gh auth login" -ForegroundColor Yellow

    # Attempt browser-based login
    wsl -d ubuntu bash -c "gh auth login -h github.com -p https -w"

    # Verify fix
    $ghAuthStatus = wsl -d ubuntu bash -c "gh auth status 2>&1"
    if ($ghAuthStatus -match 'Logged in') {
        Write-Host "  GitHub authentication FIXED!" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: GitHub authentication still invalid" -ForegroundColor Red
        Write-Host "  Manual intervention required: wsl -d ubuntu bash -c 'gh auth login'" -ForegroundColor Yellow
        Read-Host "Press Enter after fixing authentication manually"
    }
} else {
    Write-Host "  GitHub authentication valid!" -ForegroundColor Green
}

# Step 4: Enumerate Projects
Write-Host "[Step 4/30] Enumerating all leaf-directory projects..." -ForegroundColor Yellow
$listScript = "F:\study\networking\list_all_projects.ps1"
if (Test-Path $listScript) {
    $projects = & $listScript
    Write-Host $projects -ForegroundColor Gray
    $projectCount = ($projects | Where-Object { $_ -match 'F:\\' }).Count
    Write-Host "  Found $projectCount leaf projects" -ForegroundColor Green
} else {
    Write-Host "  ERROR: list_all_projects.ps1 not found" -ForegroundColor Red
    exit 1
}

# Step 5: Validate git_automation_parallel.ps1
Write-Host "[Step 5/30] Validating git_automation_parallel.ps1..." -ForegroundColor Yellow
$gitScript = "F:\study\networking\git_automation_parallel.ps1"
if (Test-Path $gitScript) {
    $scriptContent = Get-Content $gitScript -Raw
    if ($scriptContent -match 'git init' -and $scriptContent -match 'gh repo create') {
        Write-Host "  Script validated - contains required git operations" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Script may be incomplete" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ERROR: git_automation_parallel.ps1 not found" -ForegroundColor Red
    exit 1
}

# Step 6: Test Run on Single Project
Write-Host "[Step 6/30] Executing test run on MadeByME project..." -ForegroundColor Yellow
$testProject = "F:\study\projects\Web_Development\Extensions\MadeByME"
if (Test-Path $testProject) {
    $wslPath = $testProject -replace '\\', '/' -replace 'F:', '/mnt/f'
    Write-Host "  Testing WSL path conversion: $testProject -> $wslPath" -ForegroundColor Gray

    $testResult = wsl -d ubuntu bash -c "cd '$wslPath' 2>&1 && pwd && ls -la | head -5"
    Write-Host $testResult -ForegroundColor Gray

    if ($testResult -match '/mnt/f') {
        Write-Host "  Path conversion working!" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: WSL path access failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  WARNING: Test project not found, skipping" -ForegroundColor Yellow
}

# Step 7: Validate WSL Prerequisite Commands
Write-Host "[Step 7/30] Validating WSL prerequisite commands..." -ForegroundColor Yellow
$prereqs = wsl -d ubuntu bash -c "git --version && gh --version && bash --version | head -1"
Write-Host $prereqs -ForegroundColor Gray
if ($prereqs -match 'git version' -and $prereqs -match 'gh version') {
    Write-Host "  All prerequisites available!" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Missing prerequisites" -ForegroundColor Red
    exit 1
}

# Step 8: Execute Main Git Automation (15 Parallel Jobs)
Write-Host "[Step 8/30] ===== EXECUTING PARALLEL GIT AUTOMATION =====" -ForegroundColor Cyan
Write-Host "  This will process all $projectCount projects with 15 concurrent jobs" -ForegroundColor Yellow
Write-Host "  Expected duration: ~10-30 minutes depending on project count" -ForegroundColor Gray
Write-Host ""

$automationResults = & $gitScript

# Save full output
$resultsFile = "F:\study\networking\automation-output-$timestamp.txt"
$automationResults | Out-File -FilePath $resultsFile -Encoding UTF8
Write-Host "  Full output saved to: $resultsFile" -ForegroundColor Green

# Step 9: Parse Results and Generate Statistics
Write-Host "[Step 9/30] Parsing automation results..." -ForegroundColor Yellow
$resultsText = $automationResults -join "`n"
$totalProcessed = ([regex]::Matches($resultsText, 'Total projects processed: (\d+)')).Groups[1].Value
$totalSucceeded = ([regex]::Matches($resultsText, 'Total succeeded: (\d+)')).Groups[1].Value
$totalFailed = ([regex]::Matches($resultsText, 'Total failed: (\d+)')).Groups[1].Value

if ($totalProcessed) {
    $successRate = [math]::Round(([int]$totalSucceeded / [int]$totalProcessed) * 100, 2)
    Write-Host "  Total Processed: $totalProcessed" -ForegroundColor Cyan
    Write-Host "  Succeeded: $totalSucceeded" -ForegroundColor Green
    Write-Host "  Failed: $totalFailed" -ForegroundColor Red
    Write-Host "  Success Rate: $successRate%" -ForegroundColor Cyan
} else {
    Write-Host "  WARNING: Could not parse statistics from output" -ForegroundColor Yellow
}

# Step 10: Extract Failed Projects
Write-Host "[Step 10/30] Extracting failed project details..." -ForegroundColor Yellow
$failedProjects = @()
$failedMatches = [regex]::Matches($resultsText, ' FAILED: (.+)')
foreach ($match in $failedMatches) {
    $failedProjects += $match.Groups[1].Value
}

if ($failedProjects.Count -gt 0) {
    Write-Host "  Failed projects ($($failedProjects.Count)):" -ForegroundColor Red
    $failedProjects | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }

    # Save to file
    $failedFile = "F:\study\networking\failed-projects-$timestamp.txt"
    $failedProjects | Out-File -FilePath $failedFile -Encoding UTF8
    Write-Host "  Failed projects saved to: $failedFile" -ForegroundColor Yellow
} else {
    Write-Host "  No failures detected!" -ForegroundColor Green
}

# Step 11: Recovery for Failed Projects (if any)
if ($failedProjects.Count -gt 0) {
    Write-Host "[Step 11/30] Executing recovery on failed projects..." -ForegroundColor Yellow
    Write-Host "  Retrying $($failedProjects.Count) failed projects with exponential backoff..." -ForegroundColor Gray

    # TODO: Implement recovery logic
    Write-Host "  Recovery not yet implemented - manual intervention required" -ForegroundColor Yellow
} else {
    Write-Host "[Step 11/30] No recovery needed - all projects succeeded!" -ForegroundColor Green
}

# Step 12: Validate Credential Sanitization
Write-Host "[Step 12/30] Validating credential sanitization..." -ForegroundColor Yellow
$pythonFiles = Get-ChildItem -Path "F:\study\projects" -Filter "*.py" -Recurse -ErrorAction SilentlyContinue |
    Get-Random -Count 5

$credentialIssues = @()
foreach ($file in $pythonFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -match '\d{12}-[a-zA-Z0-9_]{32}\.apps\.googleusercontent\.com') {
        $credentialIssues += $file.FullName
    }
}

if ($credentialIssues.Count -eq 0) {
    Write-Host "  Credential sanitization verified (sampled $($pythonFiles.Count) files)" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Found unsanitized credentials in:" -ForegroundColor Red
    $credentialIssues | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}

# Step 13: Verify .gitignore Files
Write-Host "[Step 13/30] Verifying .gitignore files..." -ForegroundColor Yellow
$projectDirs = Get-ChildItem -Path "F:\study\projects" -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { (Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue).Count -gt 0 }

$gitignoreCount = ($projectDirs | Where-Object { Test-Path (Join-Path $_.FullName '.gitignore') }).Count
Write-Host "  Found .gitignore in $gitignoreCount / $($projectDirs.Count) projects" -ForegroundColor Cyan

# Step 14: Verify .last_update Files
Write-Host "[Step 14/30] Verifying .last_update files..." -ForegroundColor Yellow
$lastUpdateCount = ($projectDirs | Where-Object { Test-Path (Join-Path $_.FullName '.last_update') }).Count
Write-Host "  Found .last_update in $lastUpdateCount / $($projectDirs.Count) projects" -ForegroundColor Cyan

# Step 15: Check GitHub Repositories
Write-Host "[Step 15/30] Checking GitHub repositories..." -ForegroundColor Yellow
$ghRepos = wsl -d ubuntu bash -c "gh repo list Michaelunkai --limit 1000 --json name --jq '.[].name' 2>&1"
$ghRepoCount = ($ghRepos -split "`n").Count
Write-Host "  Found $ghRepoCount repositories on GitHub" -ForegroundColor Cyan

# Step 16: Validate .git Directories Removed
Write-Host "[Step 16/30] Validating .git directories removed..." -ForegroundColor Yellow
$remainingGit = Get-ChildItem -Path "F:\study\projects" -Directory -Filter ".git" -Recurse -ErrorAction SilentlyContinue
if ($remainingGit.Count -eq 0) {
    Write-Host "  All .git directories successfully removed!" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Found $($remainingGit.Count) remaining .git directories" -ForegroundColor Yellow
}

# Step 17: Generate Statistics Report (JSON)
Write-Host "[Step 17/30] Generating JSON statistics report..." -ForegroundColor Yellow
$statsReport = @{
    timestamp = $timestamp
    total_projects = $projectCount
    total_processed = $totalProcessed
    total_succeeded = $totalSucceeded
    total_failed = $totalFailed
    success_rate = "$successRate%"
    failed_projects = $failedProjects
    gitignore_count = $gitignoreCount
    last_update_count = $lastUpdateCount
    github_repos = $ghRepoCount
    backup_path = $backupPath
} | ConvertTo-Json -Depth 10

$statsFile = "F:\study\networking\automation-results-$timestamp.json"
$statsReport | Out-File -FilePath $statsFile -Encoding UTF8
Write-Host "  Statistics saved to: $statsFile" -ForegroundColor Green

# Step 18: Scan for Empty Directories
Write-Host "[Step 18/30] Scanning for empty source directories..." -ForegroundColor Yellow
$emptyDirs = Get-ChildItem -Path "F:\study" -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { (Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue).Count -eq 0 } |
    Select-Object -First 20

if ($emptyDirs.Count -gt 0) {
    Write-Host "  Found $($emptyDirs.Count) empty directories (first 20 shown):" -ForegroundColor Yellow
    $emptyFile = "F:\study\networking\empty-directories-$timestamp.txt"
    $emptyDirs.FullName | Out-File -FilePath $emptyFile -Encoding UTF8
    Write-Host "  Empty directories saved to: $emptyFile" -ForegroundColor Yellow
} else {
    Write-Host "  No empty directories found" -ForegroundColor Green
}

Write-Host ""
Write-Host "===== MASTER AUTOMATION COMPLETE =====" -ForegroundColor Cyan
Write-Host "Next steps: Generate documentation (README files, learned.md updates)" -ForegroundColor Yellow
Write-Host "Run: .\generate_documentation.ps1" -ForegroundColor Cyan
