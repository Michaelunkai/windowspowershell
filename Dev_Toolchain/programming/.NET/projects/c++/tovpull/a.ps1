# Configuration
$repos = @(
    "F:\tovplay\tovplay-frontend",
    "F:\tovplay\tovplay-backend"
)
$checkInterval = 5
$branches = @("main", "staging")

Write-Host "Starting auto-pull monitor" -ForegroundColor Green
Write-Host "Monitoring repositories:" -ForegroundColor Cyan
$repos | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
Write-Host "Check interval: $checkInterval seconds`n" -ForegroundColor Cyan

while ($true) {
    foreach ($repoPath in $repos) {
        if (-not (Test-Path $repoPath)) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Repository not found: $repoPath" -ForegroundColor Red
            continue
        }

        try {
            Set-Location $repoPath
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Checking $repoPath..." -ForegroundColor Gray
            
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
            Write-Host "Current branch: $currentBranch" -ForegroundColor Gray
            
            if ($branches -contains $currentBranch) {
                # Check for uncommitted changes
                Write-Host "Checking status..." -ForegroundColor Gray
                $status = git status --porcelain
                
                if ($status) {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Uncommitted changes detected:" -ForegroundColor Yellow
                    Write-Host $status -ForegroundColor Yellow
                    Write-Host "Stashing changes..." -ForegroundColor Yellow
                    git stash save "Auto-stash before pull $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                }
                
                Write-Host "Fetching from origin..." -ForegroundColor Gray
                git fetch origin
                
                $localCommit = git rev-parse HEAD
                $remoteCommit = git rev-parse origin/$currentBranch
                
                Write-Host "Local commit:  $localCommit" -ForegroundColor Gray
                Write-Host "Remote commit: $remoteCommit" -ForegroundColor Gray
                
                if ($localCommit -ne $remoteCommit) {
                    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] CHANGES DETECTED - PULLING" -ForegroundColor Green
                    
                    git pull origin $currentBranch --rebase
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] PULL COMPLETED SUCCESSFULLY" -ForegroundColor Green
                        
                        # Reapply stash if it exists
                        $stashList = git stash list
                        if ($stashList -and $status) {
                            Write-Host "Reapplying stashed changes..." -ForegroundColor Yellow
                            git stash pop
                        }
                    } else {
                        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] PULL FAILED - ABORTING" -ForegroundColor Red
                        git rebase --abort
                        if ($status) {
                            Write-Host "Restoring stashed changes..." -ForegroundColor Yellow
                            git stash pop
                        }
                    }
                } else {
                    Write-Host "No changes detected - up to date" -ForegroundColor Gray
                }
            } else {
                Write-Host "Not on monitored branch ($currentBranch) - skipping" -ForegroundColor Gray
            }
            
            Write-Host "---" -ForegroundColor DarkGray
            
        } catch {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $_" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
    
    Write-Host "`nWaiting $checkInterval seconds...`n" -ForegroundColor DarkGray
    Start-Sleep -Seconds $checkInterval
}
