# tv-keepalive.ps1
# Samsung TV UE50CU7100UXSQ - WebSocket stability test (5 min, ping every 60s)
# PS v5 compatible - semicolons not &&

$configPath = "$PSScriptRoot\tv-config.json"
$config = Get-Content -Raw $configPath | ConvertFrom-Json
$tvIP = $config.IP
$logPath = "$PSScriptRoot\tv-keepalive-log.txt"

$uri = [System.Uri]("ws://" + $tvIP + ":8002/api/v2/channels/samsung.remote.control")
$ct = [System.Threading.CancellationToken]::None

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] tv-keepalive.ps1 started. Target: $uri" | Out-File $logPath -Encoding utf8

$ws = New-Object System.Net.WebSockets.ClientWebSocket

try {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Connecting WebSocket..." | Tee-Object -FilePath $logPath -Append | Write-Host
    $ws.ConnectAsync($uri, $ct).Wait(10000) | Out-Null

    $global:TVWebSocket = $ws

    $pingPayload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_LEFT","Option":"false","TypeOfRemote":"SendRemoteKey"}}'

    for ($minute = 1; $minute -le 5; $minute++) {
        $state = $ws.State.ToString()
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Minute $minute/5 - WebSocket.State = $state" | Tee-Object -FilePath $logPath -Append | Write-Host

        if ($state -eq 'Open') {
            try {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($pingPayload)
                $seg = [System.ArraySegment[byte]]::new($bytes)
                $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait(5000) | Out-Null
                "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Ping sent OK" | Tee-Object -FilePath $logPath -Append | Write-Host
            } catch {
                "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Ping FAILED: $_" | Tee-Object -FilePath $logPath -Append | Write-Host
            }
        } else {
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] WARNING: WebSocket not Open, skipping ping" | Tee-Object -FilePath $logPath -Append | Write-Host
        }

        if ($minute -lt 5) {
            Start-Sleep -Seconds 60
        }
    }

    $finalState = $ws.State.ToString()
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] FINAL - WebSocket.State = $finalState" | Tee-Object -FilePath $logPath -Append | Write-Host

    if ($finalState -eq 'Open') {
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] RESULT: PASS - WebSocket stayed Open for 5 minutes" | Tee-Object -FilePath $logPath -Append | Write-Host
    } else {
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] RESULT: FAIL - WebSocket state is $finalState after 5 minutes" | Tee-Object -FilePath $logPath -Append | Write-Host
    }

    $global:TVWebSocket = $ws
} catch {
    $errMsg = $_.ToString()
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: $errMsg" | Tee-Object -FilePath $logPath -Append | Write-Host
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] NOTE: TV may be offline or IP placeholder not replaced in tv-config.json" | Tee-Object -FilePath $logPath -Append | Write-Host
} finally {
    if ($ws.State -eq 'Open') {
        try { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, '', $ct).Wait(3000) | Out-Null } catch {}
    }
}

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] tv-keepalive.ps1 complete. Log: $logPath" | Write-Host
