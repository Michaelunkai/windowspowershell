# Fix Docker --progress Flag Errors (Permanent Solution)
# Removes invalid --progress flags from docker pull/push commands
# Run this on ANY script that has "unknown flag: --progress" errors

param(
    [Parameter(Mandatory=$false)]
    [string]$FilePath = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$ScanAll = $false
)

Write-Host "=== DOCKER --progress FLAG FIXER ===" -ForegroundColor Cyan
Write-Host ""

# Function to fix a single file
function Fix-DockerScript {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Host "  [SKIP] File not found: $Path" -ForegroundColor Yellow
        return $false
    }
    
    $content = Get-Content $Path -Raw
    $originalContent = $content
    
    # Remove --progress=plain from docker pull
    $content = $content -replace 'docker pull --progress[= ][\w]+ ', 'docker pull '
    $content = $content -replace 'docker pull --progress[= ][\w]+', 'docker pull'
    
    # Remove --progress=plain from docker push
    $content = $content -replace 'docker push --progress[= ][\w]+ ', 'docker push '
    $content = $content -replace 'docker push --progress[= ][\w]+', 'docker push'
    
    # Remove --progress=plain from docker run
    $content = $content -replace 'docker run --progress[= ][\w]+ ', 'docker run '
    $content = $content -replace 'docker run --progress[= ][\w]+', 'docker run'
    
    if ($content -ne $originalContent) {
        Set-Content -Path $Path -Value $content -NoNewline
        Write-Host "  [FIXED] $Path" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [OK] No changes needed: $Path" -ForegroundColor Gray
        return $false
    }
}

# Main logic
if ($ScanAll) {
    # Scan common locations for Docker scripts
    Write-Host "[SCAN] Searching for Docker scripts..." -ForegroundColor Yellow
    Write-Host ""
    
    $searchPaths = @(
        "F:\Downloads\*.bat",
        "F:\study\containers\docker\scripts\*.bat",
        "F:\study\containers\docker\scripts\*.ps1",
        "C:\Users\micha\Desktop\*.bat"
    )
    
    $fixedCount = 0
    $totalCount = 0
    
    foreach ($pattern in $searchPaths) {
        $files = Get-ChildItem $pattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $totalCount++
            if (Fix-DockerScript $file.FullName) {
                $fixedCount++
            }
        }
    }
    
    Write-Host ""
    Write-Host "=== SCAN COMPLETE ===" -ForegroundColor Cyan
    Write-Host "Scanned: $totalCount files" -ForegroundColor White
    Write-Host "Fixed: $fixedCount files" -ForegroundColor Green
    
} elseif ($FilePath) {
    # Fix specific file
    Write-Host "[FIX] Processing: $FilePath" -ForegroundColor Yellow
    Write-Host ""
    
    if (Fix-DockerScript $FilePath) {
        Write-Host ""
        Write-Host "=== FIXED ===" -ForegroundColor Green
        Write-Host "File has been corrected. Re-run your script now." -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "=== NO CHANGES ===" -ForegroundColor Yellow
        Write-Host "File was already correct or doesn't contain docker commands." -ForegroundColor White
    }
    
} else {
    # No parameters - show help
    Write-Host "[INFO] Fix Docker scripts with invalid --progress flags" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  .\fix-docker-progress-errors.ps1 -FilePath 'path\to\script.bat'" -ForegroundColor White
    Write-Host "  .\fix-docker-progress-errors.ps1 -ScanAll" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  # Fix a specific script:" -ForegroundColor Gray
    Write-Host "  .\fix-docker-progress-errors.ps1 -FilePath 'F:\Downloads\run_games.bat'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Scan and fix all scripts automatically:" -ForegroundColor Gray
    Write-Host "  .\fix-docker-progress-errors.ps1 -ScanAll" -ForegroundColor White
    Write-Host ""
    Write-Host "What it fixes:" -ForegroundColor Cyan
    Write-Host "  - Removes --progress from 'docker pull' (not supported)" -ForegroundColor White
    Write-Host "  - Removes --progress from 'docker push' (not supported)" -ForegroundColor White
    Write-Host "  - Removes --progress from 'docker run' (not supported)" -ForegroundColor White
    Write-Host "  - Keeps --progress in 'docker build' (supported)" -ForegroundColor White
    Write-Host ""
}
