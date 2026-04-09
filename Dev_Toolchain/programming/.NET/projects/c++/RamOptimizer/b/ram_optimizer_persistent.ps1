# ram_optimizer_persistent.ps1 - Keeps ram_optimizer running permanently
# If the exe exits, it restarts automatically

$exePath = "F:\study\Dev_Toolchain\programming\.NET\projects\c++\RamOptimizer\B\ram_optimizer.exe"
$processName = "ram_optimizer"

while ($true) {
    # Check if already running
    $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
    
    if (-not $running) {
        # Start the optimizer
        Start-Process -FilePath $exePath -WindowStyle Hidden
        Write-Host "$(Get-Date): Started $processName"
    }
    
    # Wait before checking again (every 30 seconds)
    Start-Sleep -Seconds 30
}
