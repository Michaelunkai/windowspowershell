# Samsung TV UE50CU7100UXSQ Control Script
# PS v5 compatible

function Get-TVConfig {
    $configPath = "$PSScriptRoot\tv-config.json"
    Get-Content -Raw $configPath | ConvertFrom-Json
}

function Get-TVPowerState {
    $tvIP = (Get-TVConfig).IP
    if (Test-NetConnection -ComputerName $tvIP -Port 8001 -InformationLevel Quiet) { 'On' } else { 'Off' }
}

function Get-TVInfo {
    $tvIP = (Get-TVConfig).IP
    $r = Invoke-RestMethod -Uri ('http://' + $tvIP + ':8001/api/v2')
    [PSCustomObject]@{
        ModelName       = $r.device.modelName
        FirmwareVersion = $r.device.firmwareVersion
        DeviceID        = $r.id
    }
}

function Send-TVKey {
    param([string]$KeyCode)
    $tvIP = (Get-TVConfig).IP
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $uri = [System.Uri]('ws://' + $tvIP + ':8002/api/v2/channels/samsung.remote.control')
    $ct = [System.Threading.CancellationToken]::None
    $ws.ConnectAsync($uri, $ct).Wait()
    $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"' + $KeyCode + '","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $seg = [System.ArraySegment[byte]]::new($bytes)
    $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
    $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, '', $ct).Wait()
    $ws.Dispose()
}

function Set-TVChannel {
    param([int]$Number)
    $Number.ToString().ToCharArray() | ForEach-Object {
        Send-TVKey ('KEY_' + $_)
        Start-Sleep -Milliseconds 300
    }
}

function Channel-Up {
    Send-TVKey 'KEY_CHUP'
}

function Channel-Down {
    Send-TVKey 'KEY_CHDOWN'
}


function Set-TVSubtitles {
    param([bool]$Enabled)
    Send-TVKey 'KEY_CAPTION'
}

function Get-TVConnection {
    return Connect-SamsungTV
}

function Set-TVPictureMode {
    param(
        [System.Net.WebSockets.ClientWebSocket]$ws,
        [ValidateSet('Movie','Standard','Dynamic','Game','Natural','Sports','HDR+','FILMMAKER')][string]$Mode = 'Game'
    )
    if (-not $ws -or $ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
        Write-Error 'WebSocket connection is not open. Call Get-TVConnection first.'
        return
    }
    $payload = '{"method":"ms.channel.emit","params":{"event":"ed.apps.launch","to":"host","data":{"category":"Picture","key":"PictureMode","value":"' + $Mode + '"}}}'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $seg = [System.ArraySegment[byte]]::new($bytes)
    $ct = [System.Threading.CancellationToken]::None
    $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()
    Write-Host "Picture mode set to $Mode"
}
function Set-TVSleepTimer {
    param([ValidateSet(30,60,90,120)][int]$Minutes)
    Send-TVKey 'KEY_SLEEP'
    Start-Sleep -Milliseconds 800
    $steps = @{30=0;60=1;90=2;120=3}[$Minutes]
    for ($i = 0; $i -lt $steps; $i++) {
        Send-TVKey 'KEY_DOWN'
        Start-Sleep -Milliseconds 300
    }
    Send-TVKey 'KEY_ENTER'
}

function Invoke-TVAmbientMode {
    Send-TVKey 'KEY_AMBIENT'
}

function Set-TVIdleAmbient {
    # Integrate with coolmax-oc.ps1 tier 1 idle mode: activate ambient when not gaming
    $powerState = Get-TVPowerState
    if ($powerState -eq 'On') {
        Invoke-TVAmbientMode
    }
}

function Receive-TVMessage {
    param(
        [System.Net.WebSockets.ClientWebSocket]$ws,
        [System.Threading.CancellationToken]$ct
    )
    $buf = [byte[]]::new(8192)
    $seg = [ArraySegment[byte]]$buf
    $r = $ws.ReceiveAsync($seg, $ct).GetAwaiter().GetResult()
    return [System.Text.Encoding]::UTF8.GetString($buf, 0, $r.Count)
}

function Connect-SamsungTV {
    $cfg = Get-Content -Raw "$PSScriptRoot\tv-config.json" | ConvertFrom-Json
    $ip = $cfg.IP
    $appName = 'SamsungTVControl'
    $token = $cfg.Token

    $appNameB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($appName))

    # CU7100 firmware T-KSU2ECDEUC-0080-2032.8: try port 8002 first, fall back to 8001
    $ports = @(8002, 8001)
    $ws = $null
    $cts = $null
    $connectedPort = $null

    foreach ($port in $ports) {
        if ($token -and $token -ne '') {
            $uri = "ws://${ip}:${port}/api/v2/channels/samsung.remote.control?name=$appNameB64&token=$token"
        } else {
            $uri = "ws://${ip}:${port}/api/v2/channels/samsung.remote.control?name=$appNameB64"
        }

        Write-Host "Connecting to $uri"

        $ws = [System.Net.WebSockets.ClientWebSocket]::new()
        # Add User-Agent header for CU7100 firmware compatibility
        $ws.Options.SetRequestHeader('User-Agent', 'Samsung SmartTV Remote Control/1.0')
        $cts = [System.Threading.CancellationTokenSource]::new(10000)

        try {
            $ws.ConnectAsync([Uri]$uri, $cts.Token).GetAwaiter().GetResult()
            $connectedPort = $port
            Write-Host "WebSocket connected on port $port."
            break
        } catch {
            Write-Warning "Port $port failed: $_"
            $ws.Dispose()
            $ws = $null
            $cts.Dispose()
            $cts = $null
        }
    }

    if (-not $ws -or $ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
        Write-Error "Connection failed on both ports 8002 and 8001."
        return $null
    }

    Write-Host 'WebSocket connected. Waiting for pairing response...'

    try {
        $msg = Receive-TVMessage -ws $ws -ct $cts.Token
        Write-Host "Received: $msg"

        try {
            $tok = ($msg | ConvertFrom-Json).params.token
            if ($tok -and $tok -ne '') {
                $configPath = "$PSScriptRoot\tv-config.json"
                $cfg2 = Get-Content -Raw $configPath | ConvertFrom-Json
                $cfg2 | Add-Member -MemberType NoteProperty -Name Token -Value $tok -Force
                $cfg2 | Add-Member -MemberType NoteProperty -Name WSPort -Value $connectedPort -Force
                $cfg2 | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
                Write-Host "Pairing token saved: $tok (port $connectedPort)"
            }
        } catch {
            Write-Warning "Could not extract token from pairing response: $_"
        }

        return $ws
    } catch {
        Write-Error "Failed to receive pairing response: $_"
        $ws.Dispose()
        return $null
    }
}
