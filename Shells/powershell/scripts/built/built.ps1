<#
.SYNOPSIS
    built
#>
param($tag)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $cwd = (Get-Location).Path
    Write-Host "`n[DOCKER] BUILD + PUSH: $tag" -ForegroundColor Cyan
    Write-Host "Directory: $cwd" -ForegroundColor DarkGray
    Write-Host ("=" * 60) -ForegroundColor DarkGray

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
        Write-Host "`n[FAILED] Docker daemon is not accessible after $maxRetries attempts" -ForegroundColor Red
        Write-Host "Try running: Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'" -ForegroundColor Yellow
        throw "Docker daemon not accessible"
    }

    $env:DOCKER_BUILDKIT = "1"
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "docker"
    $pinfo.Arguments = "build --progress=plain --push -t $tag ."
    $pinfo.WorkingDirectory = $cwd
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null

    while (-not $p.HasExited) {
        while ($null -ne ($line = $p.StandardError.ReadLine())) {
            if ($line -match "^#\d+ \[") { Write-Host $line -ForegroundColor Yellow }
            elseif ($line -match "DONE|CACHED") { Write-Host $line -ForegroundColor Green }
            elseif ($line -match "ERROR|FAILED|error") { Write-Host $line -ForegroundColor Red }
            elseif ($line -match "pushing|exporting|manifest") { Write-Host $line -ForegroundColor Magenta }
            elseif ($line -match "^#\d+") { Write-Host $line -ForegroundColor DarkYellow }
            else { Write-Host $line }
        }
        Start-Sleep -Milliseconds 50
    }
    $p.WaitForExit()

    $sw.Stop()
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    if ($p.ExitCode -ne 0) {
        Write-Host "[FAILED] after $($sw.Elapsed.TotalSeconds.ToString('F1'))s" -ForegroundColor Red
        throw "Docker build/push failed"
    }
    Write-Host "[SUCCESS] $tag in $($sw.Elapsed.TotalSeconds.ToString('F1'))s" -ForegroundColor Green
