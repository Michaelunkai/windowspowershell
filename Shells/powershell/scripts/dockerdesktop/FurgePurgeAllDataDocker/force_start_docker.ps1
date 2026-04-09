Write-Host "[FORCE START] Launching Docker Desktop..." -ForegroundColor Green

# Kill any zombie Docker processes first
Get-Process | Where-Object {$_.ProcessName -like '*Docker*'} | ForEach-Object {
    Write-Host "[KILL] Stopping zombie process: $($_.ProcessName) (PID: $($_.Id))"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

Start-Sleep 2

# Start Docker Desktop with full window
Write-Host "[LAUNCH] Starting Docker Desktop.exe..."
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Normal

Write-Host "[WAIT] Waiting 10 seconds for Docker Desktop UI to initialize..."
Start-Sleep 10

# Check if process started
if (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue) {
    Write-Host "[SUCCESS] Docker Desktop.exe is now running!" -ForegroundColor Green

    Write-Host "`n[MONITORING] Waiting for VHDX file to be created..."
    $vhdxPath = "C:\ProgramData\DockerDesktop\vm-data\DockerDesktop.vhdx"

    for ($i = 1; $i -le 30; $i++) {
        if (Test-Path $vhdxPath) {
            $size = (Get-Item $vhdxPath).Length / 1GB
            Write-Host "[SUCCESS] VHDX file created! Size: $([math]::Round($size, 2)) GB" -ForegroundColor Green
            break
        }
        Write-Host "[WAIT] Attempt $i/30 - VHDX not created yet, waiting 10s..."
        Start-Sleep 10
    }

    Write-Host "`n[FINAL CHECK] Testing Docker daemon..."
    for ($j = 1; $j -le 24; $j++) {
        $result = docker info 2>&1 | Out-String
        if ($result -match "Server Version") {
            Write-Host "`n[SUCCESS] DOCKER IS FULLY OPERATIONAL!" -ForegroundColor Green
            Write-Host "=============================================="
            docker version
            Write-Host "=============================================="
            docker ps
            exit 0
        }
        Write-Host "[WAIT] Attempt $j/24 - Docker daemon not ready, waiting 10s..."
        Start-Sleep 10
    }

    Write-Host "[TIMEOUT] Docker daemon did not become ready" -ForegroundColor Red
} else {
    Write-Host "[ERROR] Docker Desktop.exe failed to start!" -ForegroundColor Red
    exit 1
}
