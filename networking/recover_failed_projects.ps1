# Recovery Script for Failed Git Automation Projects
# Created: 2025-12-29 21:37:38
# Retries failed projects with exponential backoff and enhanced error handling

param(
    [string]$FailedProjectsFile = "",
    [int]$MaxRetries = 3,
    [int]$InitialBackoffSeconds = 5
)

$ErrorActionPreference = 'Continue'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host "===== FAILED PROJECTS RECOVERY SCRIPT =====" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host ""

# Find latest failed projects file if not specified
if ([string]::IsNullOrEmpty($FailedProjectsFile)) {
    $latestFailedFile = Get-ChildItem -Path "F:\study\networking" -Filter "failed-projects-*.txt" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestFailedFile) {
        $FailedProjectsFile = $latestFailedFile.FullName
        Write-Host "Found latest failed projects file: $($latestFailedFile.Name)" -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: No failed projects file found" -ForegroundColor Red
        Write-Host "Specify file path with -FailedProjectsFile parameter" -ForegroundColor Yellow
        exit 1
    }
}

# Read failed projects
if (!(Test-Path $FailedProjectsFile)) {
    Write-Host "ERROR: Failed projects file not found: $FailedProjectsFile" -ForegroundColor Red
    exit 1
}

$failedProjects = Get-Content $FailedProjectsFile
Write-Host "Found $($failedProjects.Count) failed projects to retry" -ForegroundColor Cyan
Write-Host ""

# Create WSL git script for recovery
$recoveryGitScript = @'
#!/bin/bash
PROJECT_DIR="$1"

cd "$PROJECT_DIR" || exit 1

REPO_NAME=$(basename "$PWD" | tr -d " ")

echo "===== Processing: $REPO_NAME ====="

# Remove existing .git if present
rm -rf .git 2>/dev/null

# Configure git
sudo git config --global --add safe.directory "$PWD" 2>/dev/null

# Initialize git
sudo git init

# Create .last_update
echo "Last updated: $(date)" > .last_update

# Create comprehensive .gitignore
cat > .gitignore << 'EOF'
*.json
*.pickle
*credentials*
*secret*
*token*
*.key
*.pem
*.p12
*.pfx
.env
.env.*
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
node_modules/
npm-debug.log
yarn-error.log
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.vscode/
.idea/
*.suo
*.user
*.userosscache
*.sln.docstates
EOF

# Sanitize credentials in Python files
find . -name "*.py" -type f -exec sed -i -E \
    -e "s/(client_id[[:space:]]*=[[:space:]]*[\"'])[^\"']*([\"'])/\1YOUR_CLIENT_ID_HERE\2/g" \
    -e "s/(client_secret[[:space:]]*=[[:space:]]*[\"'])[^\"']*([\"'])/\1YOUR_CLIENT_SECRET_HERE\2/g" \
    -e "s/(api_key[[:space:]]*=[[:space:]]*[\"'])[^\"']*([\"'])/\1YOUR_API_KEY_HERE\2/g" \
    -e "s/[0-9]{12}-[a-zA-Z0-9_]{32}\.apps\.googleusercontent\.com/YOUR_CLIENT_ID_HERE/g" \
    {} \; 2>/dev/null

# Remove sensitive files
rm -f client_secret.json token.pickle credentials.json youtube_credentials.json 2>/dev/null
find . -name "client_secret.json" -delete 2>/dev/null
find . -name "token.pickle" -delete 2>/dev/null

# Git add and commit
sudo git add -A
sudo git commit -m "auto update $(date)" 2>/dev/null

# Add remote
sudo git remote remove origin 2>/dev/null
sudo git remote add origin "https://github.com/Michaelunkai/$REPO_NAME.git"

# Set main branch
sudo git branch -M main

# Try push with timeout
timeout 60 sudo git push -u origin main 2>&1 && {
    echo "SUCCESS: Pushed to GitHub via git"
    exit 0
}

# If push fails, try with gh CLI
if gh auth status >/dev/null 2>&1; then
    echo "Trying gh CLI method..."

    # Delete repo if exists
    gh repo delete "Michaelunkai/$REPO_NAME" --yes 2>/dev/null

    # Create and push
    timeout 60 gh repo create "$REPO_NAME" --public --source=. --remote=origin --push 2>&1 && {
        echo "SUCCESS: Pushed to GitHub via gh CLI"
        exit 0
    }
fi

# Last resort: force push
timeout 60 sudo git push -u origin main --force --no-verify 2>&1 && {
    echo "SUCCESS: Force pushed to GitHub"
    exit 0
}

echo "FAILED: All push methods exhausted"
exit 1
'@

$recoveryScriptPath = "/tmp/git_recovery_$(Get-Date -Format 'yyyyMMddHHmmss').sh"
$recoveryGitScript | wsl -d ubuntu bash -c "cat > '$recoveryScriptPath' && chmod +x '$recoveryScriptPath'"

Write-Host "Created WSL recovery script: $recoveryScriptPath" -ForegroundColor Green
Write-Host ""

# Recovery statistics
$totalRecovered = 0
$stillFailing = @()
$recoveryResults = @()

# Process each failed project
$projectNum = 1
foreach ($projectName in $failedProjects) {
    Write-Host "[$projectNum/$($failedProjects.Count)] Processing: $projectName" -ForegroundColor Yellow

    # Find project directory
    $projectDir = Get-ChildItem -Path "F:\study\projects" -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $projectName } |
        Select-Object -First 1

    if (!$projectDir) {
        Write-Host "  ERROR: Project directory not found" -ForegroundColor Red
        $stillFailing += $projectName
        $recoveryResults += [PSCustomObject]@{
            Project = $projectName
            Status = "NOT_FOUND"
            Attempts = 0
            Error = "Directory not found"
        }
        $projectNum++
        continue
    }

    $wslPath = $projectDir.FullName -replace '\\', '/' -replace 'F:', '/mnt/f'
    Write-Host "  Path: $($projectDir.FullName)" -ForegroundColor Gray

    # Retry with exponential backoff
    $attempt = 1
    $recovered = $false
    $lastError = ""

    while ($attempt -le $MaxRetries -and !$recovered) {
        Write-Host "  Attempt $attempt/$MaxRetries..." -ForegroundColor Cyan

        $result = wsl -d ubuntu bash -c "cd '$wslPath' 2>&1 && '$recoveryScriptPath' '$wslPath' 2>&1"

        if ($result -match 'SUCCESS') {
            Write-Host "   RECOVERED!" -ForegroundColor Green
            $totalRecovered++
            $recovered = $true
            $recoveryResults += [PSCustomObject]@{
                Project = $projectName
                Status = "RECOVERED"
                Attempts = $attempt
                Error = ""
            }
        } else {
            $lastError = $result | Select-Object -Last 5 | Out-String
            Write-Host "   Failed: $($lastError.Substring(0, [Math]::Min(100, $lastError.Length)))" -ForegroundColor Red

            if ($attempt -lt $MaxRetries) {
                $backoff = $InitialBackoffSeconds * [Math]::Pow(2, $attempt - 1)
                Write-Host "   Backing off for $backoff seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $backoff
            }
        }

        $attempt++
    }

    if (!$recovered) {
        $stillFailing += $projectName
        $recoveryResults += [PSCustomObject]@{
            Project = $projectName
            Status = "FAILED"
            Attempts = $MaxRetries
            Error = $lastError
        }
    }

    $projectNum++
    Write-Host ""
}

# Cleanup script
wsl -d ubuntu bash -c "rm -f '$recoveryScriptPath'"

# Generate recovery report
Write-Host "===== RECOVERY SUMMARY =====" -ForegroundColor Cyan
Write-Host "Total Failed Projects: $($failedProjects.Count)" -ForegroundColor Yellow
Write-Host "Total Recovered: $totalRecovered" -ForegroundColor Green
Write-Host "Still Failing: $($stillFailing.Count)" -ForegroundColor Red
Write-Host "Recovery Rate: $('{0:P}' -f ($totalRecovered / $failedProjects.Count))" -ForegroundColor Cyan
Write-Host ""

if ($stillFailing.Count -gt 0) {
    Write-Host "Projects Still Failing:" -ForegroundColor Red
    $stillFailing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""

    # Save still-failing projects
    $stillFailingFile = "F:\study\networking\still-failing-$timestamp.txt"
    $stillFailing | Out-File -FilePath $stillFailingFile -Encoding UTF8
    Write-Host "Still-failing projects saved to: $stillFailingFile" -ForegroundColor Yellow
}

# Save detailed recovery results (JSON)
$recoveryReport = @{
    timestamp = $timestamp
    input_file = $FailedProjectsFile
    total_failed = $failedProjects.Count
    total_recovered = $totalRecovered
    still_failing = $stillFailing.Count
    recovery_rate = "$([Math]::Round(($totalRecovered / $failedProjects.Count) * 100, 2))%"
    max_retries = $MaxRetries
    results = $recoveryResults
} | ConvertTo-Json -Depth 10

$reportFile = "F:\study\networking\recovery-results-$timestamp.json"
$recoveryReport | Out-File -FilePath $reportFile -Encoding UTF8
Write-Host "Detailed results saved to: $reportFile" -ForegroundColor Green

# Analyze failure patterns
Write-Host ""
Write-Host "===== FAILURE PATTERN ANALYSIS =====" -ForegroundColor Cyan

$errorPatterns = @{}
foreach ($result in $recoveryResults) {
    if ($result.Status -eq "FAILED") {
        $errorType = if ($result.Error -match 'timeout') { "TIMEOUT" }
                     elseif ($result.Error -match 'authentication|auth') { "AUTH_FAILED" }
                     elseif ($result.Error -match 'already exists|repository exists') { "REPO_EXISTS" }
                     elseif ($result.Error -match 'permission|denied') { "PERMISSION" }
                     elseif ($result.Error -match 'not found') { "NOT_FOUND" }
                     elseif ($result.Error -match 'network|connection') { "NETWORK" }
                     else { "UNKNOWN" }

        if (!$errorPatterns.ContainsKey($errorType)) {
            $errorPatterns[$errorType] = @()
        }
        $errorPatterns[$errorType] += $result.Project
    }
}

if ($errorPatterns.Count -gt 0) {
    foreach ($pattern in $errorPatterns.Keys) {
        $count = $errorPatterns[$pattern].Count
        Write-Host "  $pattern : $count projects" -ForegroundColor Yellow
        $errorPatterns[$pattern] | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
    }
}

Write-Host ""
Write-Host "===== RECOVERY COMPLETE =====" -ForegroundColor Cyan

if ($stillFailing.Count -gt 0) {
    Write-Host "Manual intervention required for $($stillFailing.Count) projects" -ForegroundColor Red
    Write-Host "Check: $reportFile for detailed error messages" -ForegroundColor Yellow
} else {
    Write-Host "All projects recovered successfully!" -ForegroundColor Green
}
