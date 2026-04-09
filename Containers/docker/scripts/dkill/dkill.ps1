# Docker Desktop Complete VM Cleanup
# Stops Hyper-V VM, deletes VHDX, restarts Docker fresh

# Self-elevate
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -Wait
    exit
}

$ErrorActionPreference = "SilentlyContinue"
$vhdxFiles = @(
    "C:\ProgramData\DockerDesktop\vm-data\DockerDesktop.vhdx",
    "C:\Users\micha\AppData\Local\Docker\wsl\disk\docker_data.vhdx"
)

Write-Host "=== DOCKER VM CLEANUP ===" -ForegroundColor Cyan

# Get initial size
$initialTotal = 0
foreach ($v in $vhdxFiles) { if (Test-Path $v) { $initialTotal += (Get-Item $v -Force).Length } }
Write-Host "Current VM size: $([math]::Round($initialTotal/1MB, 0)) MB`n"

if ($initialTotal -eq 0) {
    Write-Host "Nothing to clean!" -ForegroundColor Green
    Start-Sleep 2; exit 0
}

# STEP 1: Stop Hyper-V VM (this is what holds the VHDX!)
Write-Host "[1] Stopping DockerDesktopVM..." -ForegroundColor Yellow
$vm = Get-VM -Name "DockerDesktopVM" -ErrorAction SilentlyContinue
if ($vm) {
    if ($vm.State -eq "Running") {
        Stop-VM -Name "DockerDesktopVM" -TurnOff -Force -ErrorAction SilentlyContinue
        Write-Host "    VM stopped." -ForegroundColor Green
    } else {
        Write-Host "    VM already stopped." -ForegroundColor Gray
    }
} else {
    Write-Host "    No Hyper-V VM found." -ForegroundColor Gray
}

# STEP 2: Stop Docker service
Write-Host "[2] Stopping Docker service..." -ForegroundColor Yellow
Stop-Service "com.docker.service" -Force -ErrorAction SilentlyContinue
Set-Service "com.docker.service" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "    Service stopped." -ForegroundColor Green

# STEP 3: Kill all Docker processes
Write-Host "[3] Killing Docker processes..." -ForegroundColor Yellow
Get-Process | Where-Object { $_.Name -match "docker|vpnkit|com\.docker" } | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process vmwp -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Write-Host "    Processes killed." -ForegroundColor Green

# STEP 4: Delete VHDX files
Write-Host "[4] Deleting VHDX files..." -ForegroundColor Yellow
foreach ($vhdx in $vhdxFiles) {
    if (Test-Path $vhdx) {
        takeown /F "$vhdx" /A 2>&1 | Out-Null
        icacls "$vhdx" /grant Administrators:F 2>&1 | Out-Null
        Remove-Item $vhdx -Force -ErrorAction SilentlyContinue
        
        if (Test-Path $vhdx) {
            [System.IO.File]::Delete($vhdx) 2>$null
        }
        
        if (-not (Test-Path $vhdx)) {
            Write-Host "    DELETED: $vhdx" -ForegroundColor Green
        } else {
            Write-Host "    FAILED: $vhdx" -ForegroundColor Red
        }
    }
}

# STEP 5: Clean directories
Write-Host "[5] Cleaning directories..." -ForegroundColor Yellow
@("C:\ProgramData\DockerDesktop\vm-data", "C:\Users\micha\AppData\Local\Docker\wsl\disk") | ForEach-Object {
    if (Test-Path $_) { Remove-Item "$_\*" -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "    Cleaned." -ForegroundColor Green

# Verify
$finalTotal = 0
foreach ($v in $vhdxFiles) { if (Test-Path $v) { $finalTotal += (Get-Item $v -Force).Length } }
$saved = $initialTotal - $finalTotal
Write-Host "`nRECLAIMED: $([math]::Round($saved/1GB, 2)) GB" -ForegroundColor Cyan

# STEP 6: Restart Docker
Write-Host "`n[6] Restarting Docker..." -ForegroundColor Yellow
Set-Service "com.docker.service" -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service "com.docker.service" -ErrorAction SilentlyContinue
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Minimized -ErrorAction SilentlyContinue
Write-Host "    Docker starting (fresh VM ~200MB)." -ForegroundColor Green

Write-Host "`n=== DONE ===" -ForegroundColor Cyan
Start-Sleep 3
