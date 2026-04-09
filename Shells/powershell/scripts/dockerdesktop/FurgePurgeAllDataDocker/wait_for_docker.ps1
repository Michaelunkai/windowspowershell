Write-Host "[MONITORING] Waiting for Docker daemon to be fully ready..."
Write-Host "[INFO] Docker is creating a fresh VHDX - this takes 3-5 minutes on first boot"

$maxAttempts = 30  # 5 minutes
$attemptCount = 0

while ($attemptCount -lt $maxAttempts) {
    $attemptCount++
    $elapsed = $attemptCount * 10

    Write-Host "[ATTEMPT $attemptCount/$maxAttempts] ($elapsed seconds elapsed) Testing Docker..." -ForegroundColor Yellow

    $result = docker info 2>&1 | Out-String
    if ($result -match "Server Version") {
        Write-Host "`n[SUCCESS] Docker is FULLY OPERATIONAL!" -ForegroundColor Green
        Write-Host "=============================================="
        docker version
        Write-Host "=============================================="
        docker info | Select-Object -First 25
        exit 0
    }

    if ($attemptCount -lt $maxAttempts) {
        Write-Host "[WAIT] Docker not ready yet, waiting 10 seconds..." -ForegroundColor Cyan
        Start-Sleep 10
    }
}

Write-Host "`n[TIMEOUT] Docker daemon did not become ready after 5 minutes" -ForegroundColor Red
Write-Host "[INFO] Try manually opening Docker Desktop or run 'docker info' to check status"
exit 1
