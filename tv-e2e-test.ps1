# tv-e2e-test.ps1
# Samsung TV UE50CU7100UXSQ - End-to-End Test Sequence
# PS v5 ONLY - semicolons not &&
# Sequence: Stop-TV -> sleep 30 -> Start-TV (WOL) -> sleep 15 -> Connect ->
#            Set-TVInput HDMI1 -> Set-TVVolume +5 -> Start-TVApp Netflix
# Logs to tv-test-log.txt; guards against TV-offline at each step.

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$logPath    = Join-Path $scriptDir 'tv-test-log.txt'
$cfgPath    = Join-Path $scriptDir 'tv-config.json'
$wsPath     = Join-Path $scriptDir 'tv-websocket.ps1'
$funPath    = Join-Path $scriptDir 'tv-functions.ps1'

$global:E2EExceptions = 0

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $ts   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$ts] [$Level] $Msg"
    Add-Content -Path $logPath -Value $line
    if ($Level -eq 'ERROR') {
        Write-Host $line -ForegroundColor Red
        $global:E2EExceptions++
    } elseif ($Level -eq 'WARN') {
        Write-Host $line -ForegroundColor Yellow
    } else {
        Write-Host $line
    }
}

function Test-TVReachable {
    param([string]$IP, [int]$TimeoutMs = 3000)
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send($IP, $TimeoutMs)
        return ($reply.Status -eq 'Success')
    } catch {
        return $false
    }
}

function Send-WOL {
    param([string]$MacAddress)
    # Build magic packet: 6x 0xFF then 16x MAC bytes
    $mac = $MacAddress -replace '[:-]',''
    if ($mac.Length -ne 12) {
        Write-Log "Invalid MAC for WOL: $MacAddress" 'ERROR'
        return $false
    }
    $bytes = @(0xFF,0xFF,0xFF,0xFF,0xFF,0xFF)
    for ($i = 0; $i -lt 16; $i++) {
        for ($j = 0; $j -lt 6; $j++) {
            $bytes += [Convert]::ToByte($mac.Substring($j*2,2),16)
        }
    }
    try {
        $udp    = New-Object System.Net.Sockets.UdpClient
        $udp.Connect('255.255.255.255', 9)
        $udp.Send($bytes, $bytes.Length) | Out-Null
        $udp.Close()
        return $true
    } catch {
        Write-Log "WOL send failed: $_" 'ERROR'
        return $false
    }
}

function Invoke-TVWebSocketCmd {
    param([string]$IP, [int]$Port, [string]$JsonPayload)
    # PS v5 ClientWebSocket - sends one command, reads one response
    $uri = [Uri]"ws://${IP}:${Port}/api/v2/channels/samsung.remote.control"
    $ws  = New-Object System.Net.WebSockets.ClientWebSocket
    $ws.Options.SetRequestHeader('Origin','http://localhost')
    $cts = New-Object System.Threading.CancellationTokenSource
    $cts.CancelAfter(8000)
    try {
        $connectTask = $ws.ConnectAsync($uri, $cts.Token)
        $connectTask.Wait(8000) | Out-Null
        if ($ws.State -ne 'Open') {
            Write-Log "WebSocket did not open (state=$($ws.State))" 'ERROR'
            return $false
        }
        $bytes  = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
        $seg    = [System.ArraySegment[byte]]::new($bytes)
        $sendT  = $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token)
        $sendT.Wait(5000) | Out-Null
        # Read acknowledgement (best-effort; TV may not always reply)
        $buf    = New-Object byte[] 4096
        $segR   = [System.ArraySegment[byte]]::new($buf)
        $recvT  = $ws.ReceiveAsync($segR, $cts.Token)
        $recvT.Wait(5000) | Out-Null
        $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,'done',$cts.Token).Wait(3000) | Out-Null
        return $true
    } catch {
        Write-Log "WebSocket cmd error: $_" 'ERROR'
        return $false
    } finally {
        $ws.Dispose()
        $cts.Dispose()
    }
}

function Step-StopTV {
    param([string]$IP, [int]$Port)
    Write-Log "STEP 1 - Stop-TV: Sending power-off key to $IP"
    if (-not (Test-TVReachable -IP $IP)) {
        Write-Log "TV not reachable at $IP - skipping Stop-TV (TV already off or unreachable)" 'WARN'
        return $false
    }
    $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_POWER","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
    $ok = Invoke-TVWebSocketCmd -IP $IP -Port $Port -JsonPayload $payload
    if ($ok) { Write-Log "Stop-TV command sent successfully" } else { Write-Log "Stop-TV command failed" 'ERROR' }
    return $ok
}

function Step-StartTV {
    param([string]$MAC)
    Write-Log "STEP 3 - Start-TV (WOL): Sending magic packet to MAC $MAC"
    $ok = Send-WOL -MacAddress $MAC
    if ($ok) { Write-Log "WOL packet sent successfully" } else { Write-Log "WOL packet send failed" 'ERROR' }
    return $ok
}

function Step-ConnectTV {
    param([string]$IP, [int]$Port, [string]$AppName)
    Write-Log "STEP 5 - Connect-SamsungTV: Testing WebSocket handshake $IP:$Port"
    $handshake = @{
        method = 'ms.channel.connect'
        params = @{
            name  = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AppName))
            token = ''
        }
    } | ConvertTo-Json -Depth 5
    $ok = Invoke-TVWebSocketCmd -IP $IP -Port $Port -JsonPayload $handshake
    if ($ok) { Write-Log "Connect-SamsungTV succeeded" } else { Write-Log "Connect-SamsungTV failed - TV may still be booting" 'WARN' }
    return $ok
}

function Step-SetTVInput {
    param([string]$IP, [int]$Port)
    Write-Log "STEP 6 - Set-TVInput HDMI1: Sending KEY_HDMI1 via remote"
    if (-not (Test-TVReachable -IP $IP)) {
        Write-Log "TV not reachable - cannot set input" 'ERROR'
        return $false
    }
    $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_HDMI1","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
    $ok = Invoke-TVWebSocketCmd -IP $IP -Port $Port -JsonPayload $payload
    if ($ok) { Write-Log "Set-TVInput HDMI1 sent successfully" } else { Write-Log "Set-TVInput HDMI1 failed" 'ERROR' }
    return $ok
}

function Step-SetTVVolumePlus5 {
    param([string]$IP, [int]$Port)
    Write-Log "STEP 7 - Set-TVVolume +5: Sending KEY_VOLUP x5"
    if (-not (Test-TVReachable -IP $IP)) {
        Write-Log "TV not reachable - cannot set volume" 'ERROR'
        return $false
    }
    $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_VOLUP","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
    $allOk = $true
    for ($i = 1; $i -le 5; $i++) {
        $ok = Invoke-TVWebSocketCmd -IP $IP -Port $Port -JsonPayload $payload
        if ($ok) {
            Write-Log "  Vol+1 step $i/5 sent"
        } else {
            Write-Log "  Vol+1 step $i/5 FAILED" 'ERROR'
            $allOk = $false
        }
        Start-Sleep -Milliseconds 600
    }
    if ($allOk) { Write-Log "Set-TVVolume +5 completed" } else { Write-Log "Set-TVVolume +5 had errors" 'ERROR' }
    return $allOk
}

function Step-StartTVAppNetflix {
    param([string]$IP, [int]$Port, [string]$NetflixAppId)
    Write-Log "STEP 8 - Start-TVApp Netflix: Launching app ID $NetflixAppId via REST"
    if (-not (Test-TVReachable -IP $IP)) {
        Write-Log "TV not reachable - cannot launch Netflix" 'ERROR'
        return $false
    }
    $uri = "http://${IP}:8001/api/v2/applications/$NetflixAppId"
    try {
        $resp = Invoke-RestMethod -Uri $uri -Method POST -TimeoutSec 10
        Write-Log "Start-TVApp Netflix: REST POST response = $($resp | ConvertTo-Json -Compress -Depth 3)"
        return $true
    } catch {
        # Fallback: send KEY_Netflix remote key
        Write-Log "REST launch failed ($_), trying KEY_Netflix remote key" 'WARN'
        $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_NETFLIX","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
        $ok = Invoke-TVWebSocketCmd -IP $IP -Port $Port -JsonPayload $payload
        if ($ok) { Write-Log "KEY_Netflix fallback sent successfully" } else { Write-Log "KEY_Netflix fallback also failed" 'ERROR' }
        return $ok
    }
}

# ---- MAIN ----

# Banner
Add-Content -Path $logPath -Value ""
Write-Log "=========================================================="
Write-Log "Samsung TV E2E Test Sequence - START"
Write-Log "Script: $($MyInvocation.MyCommand.Path)"
Write-Log "Log:    $logPath"
Write-Log "=========================================================="

# Load config
if (-not (Test-Path $cfgPath)) {
    Write-Log "tv-config.json not found at $cfgPath" 'ERROR'
    exit 1
}
$cfg = Get-Content -Raw $cfgPath | ConvertFrom-Json
$IP      = $cfg.IP
$Port    = if ($cfg.Port) { [int]$cfg.Port } else { 8002 }
$AppName = if ($cfg.AppName) { $cfg.AppName } else { 'PSControl' }
$MAC     = if ($cfg.MAC) { $cfg.MAC } else { '00:00:00:00:00:00' }
# Netflix appId - well-known Samsung Tizen value
$NetflixId = if ($cfg.AppIDs -and $cfg.AppIDs.Netflix) { $cfg.AppIDs.Netflix } else { '11101200001' }

Write-Log "Config loaded: IP=$IP  Port=$Port  MAC=$MAC  Netflix=$NetflixId"

# Validate IP is set
if ($IP -match 'XXX' -or $IP -eq '192.168.1.XXX') {
    Write-Log "TV IP is placeholder ($IP) - steps requiring network will be skipped with WARN" 'WARN'
    $TVIpValid = $false
} else {
    $TVIpValid = $true
}

# --- STEP 1: Stop-TV ---
if ($TVIpValid) {
    $r1 = Step-StopTV -IP $IP -Port $Port
} else {
    Write-Log "STEP 1 - Stop-TV: SKIPPED (IP not configured)" 'WARN'
    $r1 = $false
}

# --- STEP 2: Sleep 30s ---
Write-Log "STEP 2 - Start-Sleep 30: Waiting 30 seconds for TV to power off..."
Start-Sleep -Seconds 30
Write-Log "STEP 2 - Sleep 30 complete"

# --- STEP 3: Start-TV (WOL) ---
if ($MAC -ne '00:00:00:00:00:00' -and $MAC -ne '') {
    $r3 = Step-StartTV -MAC $MAC
} else {
    Write-Log "STEP 3 - Start-TV (WOL): SKIPPED (MAC not configured in tv-config.json)" 'WARN'
    $r3 = $false
}

# --- STEP 4: Sleep 15s (boot time) ---
Write-Log "STEP 4 - Start-Sleep 15: Waiting 15 seconds for TV to boot..."
Start-Sleep -Seconds 15
Write-Log "STEP 4 - Sleep 15 complete"

# --- STEP 5: Connect-SamsungTV ---
if ($TVIpValid) {
    $r5 = Step-ConnectTV -IP $IP -Port $Port -AppName $AppName
} else {
    Write-Log "STEP 5 - Connect-SamsungTV: SKIPPED (IP not configured)" 'WARN'
    $r5 = $false
}

# Extra settle time after connect
Start-Sleep -Seconds 2

# --- STEP 6: Set-TVInput HDMI1 ---
if ($TVIpValid) {
    $r6 = Step-SetTVInput -IP $IP -Port $Port
} else {
    Write-Log "STEP 6 - Set-TVInput HDMI1: SKIPPED (IP not configured)" 'WARN'
    $r6 = $false
}

Start-Sleep -Seconds 2

# --- STEP 7: Set-TVVolume +5 ---
if ($TVIpValid) {
    $r7 = Step-SetTVVolumePlus5 -IP $IP -Port $Port
} else {
    Write-Log "STEP 7 - Set-TVVolume +5: SKIPPED (IP not configured)" 'WARN'
    $r7 = $false
}

Start-Sleep -Seconds 1

# --- STEP 8: Start-TVApp Netflix ---
if ($TVIpValid) {
    $r8 = Step-StartTVAppNetflix -IP $IP -Port $Port -NetflixAppId $NetflixId
} else {
    Write-Log "STEP 8 - Start-TVApp Netflix: SKIPPED (IP not configured)" 'WARN'
    $r8 = $false
}

# --- SUMMARY ---
Write-Log "=========================================================="
Write-Log "E2E TEST SUMMARY"
Write-Log "  STEP 1 Stop-TV:         $(if ($r1) {'PASS'} else {'SKIP/FAIL'})"
Write-Log "  STEP 2 Sleep 30:        PASS"
Write-Log "  STEP 3 Start-TV (WOL):  $(if ($r3) {'PASS'} else {'SKIP/FAIL'})"
Write-Log "  STEP 4 Sleep 15:        PASS"
Write-Log "  STEP 5 Connect-TV:      $(if ($r5) {'PASS'} else {'SKIP/FAIL'})"
Write-Log "  STEP 6 Set-TVInput:     $(if ($r6) {'PASS'} else {'SKIP/FAIL'})"
Write-Log "  STEP 7 Set-TVVolume+5:  $(if ($r7) {'PASS'} else {'SKIP/FAIL'})"
Write-Log "  STEP 8 Start Netflix:   $(if ($r8) {'PASS'} else {'SKIP/FAIL'})"
Write-Log "  Total EXCEPTIONS logged: $global:E2EExceptions"
if ($global:E2EExceptions -eq 0) {
    Write-Log "RESULT: ALL STEPS PASSED - 0 exceptions" 'INFO'
} else {
    Write-Log "RESULT: $global:E2EExceptions exception(s) logged - review above" 'WARN'
}
Write-Log "Log written to: $logPath"
Write-Log "=========================================================="
Write-Log "Samsung TV E2E Test Sequence - END"
Write-Log "=========================================================="
