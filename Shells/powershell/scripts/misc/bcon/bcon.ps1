<#
.SYNOPSIS
    bcon
#>
Set-Location -Path "F:\backup\Containers"

    # Check Docker daemon health before proceeding
    Write-Host "Checking Docker daemon..." -ForegroundColor Yellow
    $maxRetries = 3
    $retryCount = 0
    $dockerReady = $false

    while (-not $dockerReady -and $retryCount -lt $maxRetries) {
        try {
            $pingResult = docker version --format '{{.Server.Version}}' 2>&1
            if ($LASTEXITCODE -eq 0 -and $pingResult) {
                Write-Host "Docker daemon is ready (version: $pingResult)" -ForegroundColor Green
                $dockerReady = $true
                break
            }
        } catch { }

        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "Docker daemon not ready, checking if VM is running..." -ForegroundColor Yellow
            $vm = Get-VM -Name "DockerDesktopVM" -ErrorAction SilentlyContinue
            if ($vm -and $vm.State -ne 'Running') {
                Write-Host "Starting DockerDesktopVM..." -ForegroundColor Yellow
                Start-VM -Name "DockerDesktopVM" -ErrorAction SilentlyContinue
                Write-Host "Waiting for Docker daemon to initialize (30s)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 30
            } else {
                Write-Host "VM is running, waiting for Docker daemon (15s)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 15
            }
        }
    }

    if (-not $dockerReady) {
        Write-Host "[FAILED] Docker daemon is not accessible after $maxRetries attempts" -ForegroundColor Red
        Write-Host "Try running: Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'" -ForegroundColor Yellow
        throw "Docker daemon not accessible"
    }

    docker buildx build --platform linux/amd64 -t michadockermisha/backup:developerwincontainer . --push
