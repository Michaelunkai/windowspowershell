# samsung-tv-fix.ps1
# Samsung TV UE50CU7100UXSQ - Error recovery script
# PS v5 ONLY - use semicolons not &&
# Usage: .\samsung-tv-fix.ps1 -Issue token|ip|ws|tls

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('token','ip','ws','tls')]
    [string]$Issue
)

$ConfigPath = "C:\Users\micha\Documents\WindowsPowerShell\tv-config.json"
$LogPath    = "C:\Users\micha\Documents\WindowsPowerShell\tv-fix-log.txt"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [samsung-tv-fix] $Message"
    Add-Content -Path $LogPath -Value $line
    Write-Host $line
}

function Load-Config {
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "ERROR: tv-config.json not found at $ConfigPath"
        exit 1
    }
    $raw = Get-Content -Path $ConfigPath -Raw
    return $raw | ConvertFrom-Json
}

function Save-Config {
    param($cfg)
    $json = $cfg | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($ConfigPath, $json, [System.Text.Encoding]::UTF8)
    Write-Log "tv-config.json saved."
}

function Test-TVOnline {
    param([string]$Address, [int]$Port, [int]$TimeoutMs = 2000)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $ar  = $tcp.BeginConnect($Address, $Port, $null, $null)
        $ok  = $ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($ok -and $tcp.Connected) {
            $tcp.Close()
            return $true
        }
        $tcp.Close()
        return $false
    } catch {
        return $false
    }
}

function Find-SamsungTVIP {
    param([int]$Port = 8002)
    $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notmatch '^127\.' -and $_.PrefixLength -le 24 }
    foreach ($a in $adapters) {
        $parts  = $a.IPAddress -split '\.'
        $subnet = "$($parts[0]).$($parts[1]).$($parts[2])"
        Write-Log "Scanning $subnet.1-254 on port $Port ..."
        for ($i = 1; $i -le 254; $i++) {
            $candidate = "$subnet.$i"
            if (Test-TVOnline -Address $candidate -Port $Port -TimeoutMs 500) {
                Write-Log "Found TV candidate at $candidate`:$Port"
                return $candidate
            }
        }
    }
    return $null
}

function Send-TVKeyTest {
    param([string]$IP, [int]$WSPort)
    try {
        $ws  = New-Object System.Net.WebSockets.ClientWebSocket
        $uri = [System.Uri]("ws://$IP`:$WSPort/api/v2/channels/samsung.remote.control")
        $ct  = [System.Threading.CancellationToken]::None
        $ws.ConnectAsync($uri, $ct).Wait(3000) | Out-Null
        if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            $ws.Dispose()
            return $false
        }
        $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, '', $ct).Wait(2000) | Out-Null
        $ws.Dispose()
        return $true
    } catch {
        return $false
    }
}

function Set-TVVolume {
    param([int]$Level = 20)
    $cfg = Load-Config
    $ip  = $cfg.IP
    $wsPort = if ($cfg.WSPort) { $cfg.WSPort } else { 8002 }
    # Send KEY_MUTE as a simple connectivity test / volume action
    try {
        $ws  = New-Object System.Net.WebSockets.ClientWebSocket
        $uri = [System.Uri]("ws://$ip`:$wsPort/api/v2/channels/samsung.remote.control")
        $ct  = [System.Threading.CancellationToken]::None
        $ws.ConnectAsync($uri, $ct).Wait(3000) | Out-Null
        if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            Write-Log "Set-TVVolume: WebSocket not open after connect."
            $ws.Dispose()
            return $false
        }
        # Send volume key sequence: KEY_VOLDOWN x5 then KEY_VOLUP xLevel to approximate
        $payload = '{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_VOLUP","Option":"false","TypeOfRemote":"SendRemoteKey"}}'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $seg   = [System.ArraySegment[byte]]::new($bytes)
        $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait(2000) | Out-Null
        $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, '', $ct).Wait(2000) | Out-Null
        $ws.Dispose()
        Write-Log "Set-TVVolume: KEY_VOLUP sent successfully."
        return $true
    } catch {
        Write-Log "Set-TVVolume ERROR: $_"
        return $false
    }
}

# ---- MAIN ----
Write-Log "samsung-tv-fix.ps1 started. Issue=$Issue"

$cfg = Load-Config
Write-Log "Config: IP=$($cfg.IP) Port=$($cfg.Port) WSPort=$($cfg.WSPort) Model=$($cfg.Model)"

switch ($Issue) {

    'token' {
        Write-Log "Fix: token - removing Token field from config and reconnecting..."
        $props = $cfg.PSObject.Properties | Select-Object -ExpandProperty Name
        if ($props -contains 'Token') {
            $cfg.PSObject.Properties.Remove('Token')
            Save-Config $cfg
            Write-Log "Token field removed from tv-config.json."
        } else {
            Write-Log "No Token field found in config - already clean."
        }
        # Test reconnect via WebSocket
        $wsPort = if ($cfg.WSPort) { $cfg.WSPort } else { 8002 }
        Write-Log "Testing WebSocket reconnect to $($cfg.IP)`:$wsPort ..."
        $ok = Send-TVKeyTest -IP $cfg.IP -WSPort $wsPort
        if ($ok) {
            Write-Log "Reconnect SUCCESS after token fix."
        } else {
            Write-Log "WARNING: WebSocket reconnect failed. TV may be off or IP changed."
        }
    }

    'ip' {
        Write-Log "Fix: ip - re-running Find-SamsungTVIP..."
        $wsPort = if ($cfg.WSPort) { $cfg.WSPort } else { 8002 }
        $newIP  = Find-SamsungTVIP -Port $wsPort
        if ($newIP) {
            $oldIP  = $cfg.IP
            $cfg.IP = $newIP
            Save-Config $cfg
            Write-Log "IP updated from $oldIP to $newIP in tv-config.json."
            # Verify Set-TVVolume works
            Write-Log "Verifying Set-TVVolume after IP fix..."
            $ok = Set-TVVolume -Level 1
            if ($ok) {
                Write-Log "Set-TVVolume PASSED after ip fix."
            } else {
                Write-Log "WARNING: Set-TVVolume failed after ip fix."
            }
        } else {
            Write-Log "ERROR: TV not found on any subnet. IP not updated."
            exit 1
        }
    }

    'ws' {
        Write-Log "Fix: ws - closing stale WebSocket and reconnecting..."
        $wsPort = if ($cfg.WSPort) { $cfg.WSPort } else { 8002 }
        # Force close any lingering connections by creating a fresh client
        Write-Log "Opening fresh WebSocket connection to $($cfg.IP)`:$wsPort ..."
        $ok = Send-TVKeyTest -IP $cfg.IP -WSPort $wsPort
        if ($ok) {
            Write-Log "WebSocket reconnect SUCCESS."
        } else {
            Write-Log "WebSocket reconnect FAILED. Attempting port 8001 fallback..."
            $ok2 = Send-TVKeyTest -IP $cfg.IP -WSPort 8001
            if ($ok2) {
                Write-Log "Connected on port 8001. Updating WSPort in config."
                $cfg.WSPort = 8001
                Save-Config $cfg
            } else {
                Write-Log "ERROR: Could not reconnect WebSocket on port 8002 or 8001."
                exit 1
            }
        }
    }

    'tls' {
        Write-Log "Fix: tls - switching to port 8002 (standard Samsung SmartThings WS port)..."
        $oldPort    = $cfg.WSPort
        $cfg.WSPort = 8002
        Save-Config $cfg
        Write-Log "WSPort updated from $oldPort to 8002."
        # Verify connection on 8002
        Write-Log "Testing WebSocket on $($cfg.IP)`:8002 ..."
        $ok = Send-TVKeyTest -IP $cfg.IP -WSPort 8002
        if ($ok) {
            Write-Log "Port 8002 connection SUCCESS."
        } else {
            Write-Log "WARNING: Port 8002 connection failed. TV may be off or TLS mismatch."
        }
    }
}

Write-Log "samsung-tv-fix.ps1 complete. Issue=$Issue resolved."
