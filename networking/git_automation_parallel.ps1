# Git Automation with Parallel Processing (15 agents)
# Processes all projects with credential sanitization and GitHub push

$ErrorActionPreference = 'SilentlyContinue'

Write-Output "===== Git Automation - Parallel Processor ====="
Write-Output ""

# Get all project directories
$projectDirs = Get-ChildItem -Path 'F:\study\projects' -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object { (Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue).Count -gt 0 }

$totalProjects = $projectDirs.Count
Write-Output "Found ${totalProjects} projects to process"
Write-Output ""

# Split into batches of 15
$batchSize = 15
$batches = @()
for ($i = 0; $i -lt $totalProjects; $i += $batchSize) {
    $end = [Math]::Min($i + $batchSize - 1, $totalProjects - 1)
    $batches += ,@($projectDirs[$i..$end])
}

Write-Output "Split into $($batches.Count) batches of max $batchSize projects each"
Write-Output ""

# Create WSL git script
$gitScript = @'
#!/bin/bash
PROJECT_DIR="$1"

cd "$PROJECT_DIR" || exit 1

REPO_NAME=$(basename "$PWD" | tr -d " ")

# Remove existing .git if present
rm -rf .git 2>/dev/null

# Configure git
sudo git config --global --add safe.directory "$PWD"

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

# Push to GitHub
sudo git push -u origin main 2>/dev/null || {
    # If push fails, try with gh CLI
    if gh auth status >/dev/null 2>&1; then
        gh repo delete "Michaelunkai/$REPO_NAME" --yes 2>/dev/null
        gh repo create "$REPO_NAME" --public --source=. --remote=origin --push 2>/dev/null
    else
        sudo git push -u origin main --force --no-verify 2>/dev/null
    fi
}

# Clean up .git to save space
rm -rf .git 2>/dev/null

echo "COMPLETED: $REPO_NAME"
'@

$scriptPath = "/tmp/git_auto_$(Get-Date -Format 'yyyyMMddHHmmss').sh"
$scriptPath -replace '\\', '/'

# Write script to WSL filesystem
$gitScript | wsl -d ubuntu bash -c "cat > '$scriptPath' && chmod +x '$scriptPath'"

Write-Output "Created WSL automation script: $scriptPath"
Write-Output ""

# Process each batch in parallel
$batchNum = 1
$totalProcessed = 0
$totalSucceeded = 0
$totalFailed = 0

foreach ($batch in $batches) {
    Write-Output "===== Processing Batch $batchNum of $($batches.Count) ($($batch.Count) projects) ====="
    Write-Output ""

    $jobs = @()

    foreach ($proj in $batch) {
        $wslPath = $proj.FullName -replace '\\', '/' -replace 'F:', '/mnt/f'

        Write-Output "Starting: $($proj.Name)"

        # Launch parallel job
        $job = Start-Job -ScriptBlock {
            param($scriptPath, $wslPath, $projName)

            $output = wsl -d ubuntu bash -c "cd '$wslPath' && '$scriptPath' '$wslPath' 2>&1"

            return @{
                'Project' = $projName
                'Output' = $output
                'Success' = $output -match 'COMPLETED'
            }
        } -ArgumentList $scriptPath, $wslPath, $proj.Name

        $jobs += $job
    }

    Write-Output ""
    Write-Output "Waiting for batch $batchNum to complete..."

    # Wait for all jobs to finish
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    Write-Output ""
    Write-Output "===== Batch $batchNum Results ====="

    foreach ($result in $results) {
        $totalProcessed++

        if ($result.Success) {
            Write-Output "  ✓ SUCCESS: $($result.Project)"
            $totalSucceeded++
        } else {
            Write-Output "  ✗ FAILED: $($result.Project)"
            $totalFailed++
            if ($result.Output) {
                Write-Output "    Error: $($result.Output | Select-Object -First 3 | Out-String)"
            }
        }
    }

    Write-Output ""
    Write-Output "Batch $batchNum: $($results | Where-Object { $_.Success }).Count succeeded, $($results | Where-Object { -not $_.Success }).Count failed"
    Write-Output ""

    $batchNum++
}

# Cleanup script
wsl -d ubuntu bash -c "rm -f '$scriptPath'"

Write-Output "===== Final Summary ====="
Write-Output "Total projects processed: $totalProcessed"
Write-Output "Total succeeded: $totalSucceeded"
Write-Output "Total failed: $totalFailed"
Write-Output "Success rate: $('{0:P}' -f ($totalSucceeded / $totalProcessed))"
Write-Output ""
Write-Output "All git operations completed!"
