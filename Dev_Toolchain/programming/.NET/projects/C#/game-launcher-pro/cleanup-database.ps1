# Clean up non-game entries
$dbPath = "$env:APPDATA\GameLauncherPro\games.json"
$games = Get-Content $dbPath -Raw | ConvertFrom-Json

# Filter out obvious non-games
$validGames = $games | Where-Object {
    $_.Name -notlike "*Playnite*" -and
    $_.Name -notlike "*electron*" -and
    $_.Name -notlike "*Ventoy*" -and
    $_.Name -notlike "*imdisk*" -and
    $_.Name -notlike "*Downloads" -and
    $_.ExecutablePath -notlike "*\Downloads\*" -and
    $_.ExecutablePath -notlike "*\ventoy\*"
}

Write-Output "Before: $($games.Count) games"
Write-Output "After: $($validGames.Count) games"

$validGames | ConvertTo-Json -Depth 10 | Set-Content $dbPath

Write-Output "`nCleaned up database!"
Write-Output "`nRemaining games:"
$validGames | ForEach-Object { Write-Output "  - $($_.Name)" }
