# tv-discover.ps1 - Samsung TV IP auto-discovery
# Scans 192.168.1.0/24 on port 8001 for Samsung API response
# Updates tv-config.json with discovered IP

$ConfigPath = "C:\Users\micha\Documents\WindowsPowerShell\tv-config.json"
$LogPath    = "C:\Users\micha\Documents\WindowsPowerShell\tv-discover-log.txt"
$Subnet     = "192.168.1"
$Port       = 8001
$Timeout    = 500  # ms per host

function Write-Log {
    param([string]$Msg)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Msg"
    Add-Content -Path $LogPath -Value $line
}

Write-Log "Starting Samsung TV discovery scan on $Subnet.0/24 port $Port"

$found = $null

for ($i = 1; $i -le 254; $i++) {
    $ip = "$Subnet.$i"
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($ip, $Port, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne($Timeout, $false)
        if ($wait -and $tcp.Connected) {
            $tcp.Close()
            # Probe Samsung REST API
            try {
                $uri = "http://$ip`:$Port/api/v2/"
                $resp = Invoke-RestMethod -Uri $uri -TimeoutSec 2 -ErrorAction Stop
                if ($resp -ne $null) {
                    Write-Log "Samsung API responded at $ip - device: $($resp.device.modelName)"
                    $found = $ip
                    break
                }
            } catch {
                # Port open but not Samsung API - continue
                Write-Log "Port $Port open on $ip but not Samsung API: $_"
            }
        } else {
            if ($tcp) { $tcp.Close() }
        }
    } catch {
        # Connection refused or timeout - normal, continue
    }
}

if ($found) {
    Write-Log "TV found at $found - updating tv-config.json"
    if (Test-Path $ConfigPath) {
        $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    } else {
        $cfg = [PSCustomObject]@{ IP = ""; Port = 8002; AppName = "PSControl" }
    }
    $cfg.IP = $found
    # Remove Note field if present
    $cfgOut = [ordered]@{
        IP      = $cfg.IP
        Port    = $cfg.Port
        AppName = $cfg.AppName
    }
    [System.IO.File]::WriteAllText($ConfigPath, ($cfgOut | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8)
    Write-Log "tv-config.json updated: IP = $found"
} else {
    Write-Log "No Samsung TV found on $Subnet.0/24. tv-config.json not changed."
}
