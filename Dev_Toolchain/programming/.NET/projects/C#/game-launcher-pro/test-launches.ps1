# Test game launches
$cli = "F:\study\Dev_Toolchain\programming\.NET\projects\C#\game-launcher-pro\GameLauncherPro.CLI\bin\Release\net9.0\GameLauncherPro.CLI.exe"

Write-Output "Testing game launches..."
Write-Output ""

$games = @(
    "Bayonetta",
    "Sonic Frontiers",
    "Metal Gear Rising Revengeance"
)

foreach ($game in $games) {
    Write-Output "Testing: $game"
    & $cli launch $game
    Start-Sleep -Seconds 2
    
    $process = Get-Process | Where-Object { $_.MainWindowTitle -like "*$game*" }
    if ($process) {
        Write-Output "  ✓ Launched successfully (PID: $($process.Id))"
        Stop-Process -Id $process.Id -Force
        Write-Output "  ✓ Closed"
    } else {
        Write-Output "  ✗ Failed to detect process"
    }
    Write-Output ""
}
