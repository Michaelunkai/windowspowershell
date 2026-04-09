Write-Host "[CHECKING] Waiting for Docker daemon to be fully ready..."

$maxAttempts = 12
$attemptCount = 0

while ($attemptCount -lt $maxAttempts) {
    $attemptCount++

    $result = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Docker is fully operational!"
        docker version
        exit 0
    }

    Write-Host "[WAIT] Attempt $attemptCount/$maxAttempts - Docker not ready yet, waiting 5 seconds..."
    Start-Sleep 5
}

Write-Host "[ERROR] Docker daemon failed to start after 60 seconds"
exit 1
