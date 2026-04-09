# tv-status.ps1 - Samsung TV Dashboard
# Mission: Samsung TV PowerShell Control System

$ConfigPath = "$PSScriptRoot\tv-config.json"

# Static TV info
$Model     = "UE50CU7100UXSQ"
$Firmware  = "T-KSU2ECDEUC-0080-2032.8"
$Serial    = "0KYH3HEW400178K"
$UniqueID  = "UN5IYNGNBQN4T"

# Load config
$IP  = "UNKNOWN"
$MAC = "UNKNOWN"
$Port = 8002
if (Test-Path $ConfigPath) {
    $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($cfg.IP)   { $IP   = $cfg.IP }
    if ($cfg.Port) { $Port = $cfg.Port }
    if ($cfg.MAC)  { $MAC  = $cfg.MAC }
}

# WS connectivity check
$WSState = "UNKNOWN"
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $ar  = $tcp.BeginConnect($IP, $Port, $null, $null)
    $ok  = $ar.AsyncWaitHandle.WaitOne(2000, $false)
    if ($ok -and $tcp.Connected) { $WSState = "REACHABLE" } else { $WSState = "UNREACHABLE" }
    $tcp.Close()
} catch { $WSState = "ERROR" }

# Token status
$TokenPath = "$PSScriptRoot\tv-token.txt"
if (Test-Path $TokenPath) {
    $tok = Get-Content $TokenPath -Raw
    $TokenStatus = if ($tok.Trim()) { "PRESENT" } else { "EMPTY" }
} else {
    $TokenStatus = "NOT FOUND"
}

# Print dashboard
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Samsung TV Status Dashboard" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ("  IP        : {0}:{1}" -f $IP, $Port)
Write-Host ("  MAC       : {0}" -f $MAC)
Write-Host ("  Model     : {0}" -f $Model)
Write-Host ("  Firmware  : {0}" -f $Firmware)
Write-Host ("  Serial    : {0}" -f $Serial)
Write-Host ("  UniqueID  : {0}" -f $UniqueID)
$wsColor = if ($WSState -eq "REACHABLE") { "Green" } else { "Red" }
Write-Host ("  WS State  : {0}" -f $WSState) -ForegroundColor $wsColor
$tokColor = if ($TokenStatus -eq "PRESENT") { "Green" } else { "Yellow" }
Write-Host ("  Token     : {0}" -f $TokenStatus) -ForegroundColor $tokColor
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
