# tv-gaming-hook.ps1 - Samsung TV Auto HDMI Switch for Gaming Mode (PS v5)
# Triggered when coolmax-oc.ps1 runs at tier 200+
# Switches TV to HDMI1 and sets volume to 30; skips silently if TV unreachable

function Get-TVConfig {
    $tvConfigPath = "$PSScriptRoot\tv-config.json"
    if (Test-Path $tvConfigPath) {
        return (Get-Content $tvConfigPath -Raw | ConvertFrom-Json)
    }
    return [PSCustomObject]@{ IP = "192.168.1.100"; Port = 8002; AppName = "SamsungTVControl"; Token = "" }
}

function Send-TVKeyCommand {
    param(
        [string]$IP,
        [int]$Port,
        [string]$AppName,
        [string]$Token,
        [string]$KeyCode
    )
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    $ws = [System.Net.WebSockets.ClientWebSocket]::new()
    $cts = [System.Threading.CancellationTokenSource]::new()
    $appNameB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AppName))
    $uriStr = 'wss://' + $IP + ':' + $Port + '/api/v2/channels/samsung.remote.control?name=' + $appNameB64
    if ($Token -and $Token -ne "") { $uriStr += '&token=' + $Token }
    $uri = [Uri]$uriStr
    try {
        $ws.ConnectAsync($uri, $cts.Token).Wait()
        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"' + $KeyCode + '","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $segment = [System.ArraySegment[byte]]::new($bytes)
            $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).Wait()
            Start-Sleep -Milliseconds 400
        }
    } catch {
        Write-Warning "TV key command failed: $_"
    } finally {
        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Done", $cts.Token).Wait()
        }
        $cts.Dispose()
        $ws.Dispose()
    }
}

function Send-TVAppCommand {
    param(
        [string]$IP,
        [int]$Port,
        [string]$AppName,
        [string]$Token,
        [string]$JsonPayload
    )
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    $ws = [System.Net.WebSockets.ClientWebSocket]::new()
    $cts = [System.Threading.CancellationTokenSource]::new()
    $appNameB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($AppName))
    $uriStr = 'wss://' + $IP + ':' + $Port + '/api/v2/channels/samsung.remote.control?name=' + $appNameB64
    if ($Token -and $Token -ne "") { $uriStr += '&token=' + $Token }
    $uri = [Uri]$uriStr
    try {
        $ws.ConnectAsync($uri, $cts.Token).Wait()
        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
            $segment = [System.ArraySegment[byte]]::new($bytes)
            $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).Wait()
            Start-Sleep -Milliseconds 400
        }
    } catch {
        Write-Warning "TV app command failed: $_"
    } finally {
        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Done", $cts.Token).Wait()
        }
        $cts.Dispose()
        $ws.Dispose()
    }
}

function Set-TVInput {
    param([string]$InputName = "HDMI1")
    # Map input names to Samsung key codes
    $keyMap = @{
        "HDMI1" = "KEY_HDMI1"
        "HDMI2" = "KEY_HDMI2"
        "HDMI3" = "KEY_HDMI3"
        "HDMI4" = "KEY_HDMI4"
        "TV"    = "KEY_TV"
    }
    $key = $keyMap[$InputName]
    if (-not $key) { Write-Warning "Unknown input: $InputName"; return }
    Write-Host "Switching TV input to $InputName ($key) ..."
    $ws = Get-TVConnection
    if (-not $ws -or $ws.State -ne 'Open') { Write-Warning "Set-TVInput: no open WS connection"; return }
    $ct = [System.Threading.CancellationToken]::None
    $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"' + $key + '","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $seg = [System.ArraySegment[byte]]::new($bytes)
    $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).GetAwaiter().GetResult()
    Write-Host "TV input switch command sent: $InputName"
}

function Set-TVVolume {
    param([int]$Level = 30)
    $cfg = Get-TVConfig
    # Try REST API first (port 8001)
    $uri = 'http://' + $cfg.IP + ':8001/api/v2/requests/volume'
    $body = '{"value":' + $Level + '}'
    try {
        Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 5 | Out-Null
        Write-Host "TV volume set to $Level"
    } catch {
        # Fallback: use cached WebSocket connection via Get-TVConnection
        Write-Warning "REST volume set failed ($_); using WebSocket fallback via Get-TVConnection"
        $ws = Get-TVConnection
        if (-not $ws -or $ws.State -ne 'Open') { Write-Warning "Set-TVVolume: no open WS connection"; return }
        $ct = [System.Threading.CancellationToken]::None
        # Send KEY_VOLDOWN 50x to reach minimum, then KEY_VOLUP $Level times
        for ($i = 0; $i -lt 50; $i++) {
            $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_VOLDOWN","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $seg = [System.ArraySegment[byte]]::new($bytes)
            $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).GetAwaiter().GetResult()
        }
        for ($i = 0; $i -lt $Level; $i++) {
            $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_VOLUP","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $seg = [System.ArraySegment[byte]]::new($bytes)
            $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).GetAwaiter().GetResult()
        }
        Write-Host "TV volume set to approximately $Level via WS key fallback"
    }
}

# --- Main gaming hook logic ---
# Called when coolmax-oc.ps1 runs at tier 200+

param([int]$Tier = 0)

if ($Tier -ge 200) {
    $cfg = Get-TVConfig
    if (Test-NetConnection -ComputerName $cfg.IP -Port 8001 -InformationLevel Quiet) {
        Write-Host "Gaming mode tier $Tier detected - switching TV to HDMI1 and setting volume to 30"
        Set-TVInput -InputName 'HDMI1'
        Set-TVVolume -Level 30
        Write-Host "TV gaming hook complete: HDMI1 active, volume 30"
    } else {
        Write-Warning "TV not reachable, skipping gaming hook"
    }
} else {
    Write-Host "Tier $Tier is below 200 - no TV action taken"
}
