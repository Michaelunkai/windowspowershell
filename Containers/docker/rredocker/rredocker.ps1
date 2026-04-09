<#
.SYNOPSIS
    rredocker
#>
# Clean up Docker first
    uni docker dockerd
    
    # Try winget install first
    Write-Host "Attempting Docker Desktop installation via winget..." -ForegroundColor Cyan
    $wingetResult = winget install -e --id Docker.DockerDesktop --force --accept-package-agreements --accept-source-agreements 2>&1
    
    # Check if Docker Desktop was installed
    if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
        Write-Host "Docker Desktop installed successfully!" -ForegroundColor Green
        sdesktop
        return
    }
    
    # Fallback: Direct download and install (winget sometimes fails with Newtonsoft.Json error)
    Write-Host "Winget failed, attempting direct download installation..." -ForegroundColor Yellow
    $tempDir = "C:\Temp"
    $installerPath = "$tempDir\DockerDesktopInstaller.exe"
    
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    Write-Host "Downloading Docker Desktop (this may take a few minutes)..." -ForegroundColor Cyan
    Start-BitsTransfer -Source 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe' -Destination $installerPath -Description 'Downloading Docker Desktop'
    
    if (Test-Path $installerPath) {
        Write-Host "Installing Docker Desktop..." -ForegroundColor Cyan
        $proc = Start-Process -FilePath $installerPath -ArgumentList 'install','--quiet','--accept-license' -Wait -PassThru
        
        if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
            Write-Host "Docker Desktop installed successfully!" -ForegroundColor Green
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            sdesktop
        } else {
            Write-Host "Installation may have failed. Exit code: $($proc.ExitCode)" -ForegroundColor Red
        }
    } else {
        Write-Host "Failed to download Docker Desktop installer" -ForegroundColor Red
    }
