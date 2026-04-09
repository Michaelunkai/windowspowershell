Write-Host "=== DOCKER DIAGNOSIS ===" -ForegroundColor Cyan

Write-Host "`n[1] Docker Processes:" -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -like '*Docker*'} | Format-Table ProcessName, Id, StartTime -AutoSize

Write-Host "`n[2] Docker Services:" -ForegroundColor Yellow
Get-Service | Where-Object {$_.Name -like '*docker*'} | Format-Table Name, Status, StartType -AutoSize

Write-Host "`n[3] VM Services:" -ForegroundColor Yellow
Get-Service | Where-Object {$_.Name -like 'vm*'} | Format-Table Name, Status, StartType -AutoSize

Write-Host "`n[4] VHDX File Status:" -ForegroundColor Yellow
$vhdxPath = "C:\ProgramData\DockerDesktop\vm-data\DockerDesktop.vhdx"
if (Test-Path $vhdxPath) {
    $size = (Get-Item $vhdxPath).Length / 1GB
    Write-Host "EXISTS: $vhdxPath ($([math]::Round($size, 2)) GB)" -ForegroundColor Green
} else {
    Write-Host "NOT FOUND: $vhdxPath" -ForegroundColor Red
}

Write-Host "`n[5] Docker Error Output:" -ForegroundColor Yellow
$dockerError = docker info 2>&1 | Out-String
Write-Host $dockerError

Write-Host "`n[6] Checking Docker Desktop UI:" -ForegroundColor Yellow
if (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue) {
    Write-Host "Docker Desktop.exe IS RUNNING" -ForegroundColor Green
} else {
    Write-Host "Docker Desktop.exe IS NOT RUNNING" -ForegroundColor Red
}
