# tv-startup-check.ps1
# Samsung TV UE50CU7100UXSQ - Startup check: verify TV online, update IP if DHCP changed
# PS v5 ONLY

$ConfigPath = "C:\Users\micha\Documents\WindowsPowerShell\tv-config.json"
$LogPath    = "C:\Users\micha\Documents\WindowsPowerShell\tv-startup-log.txt"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Add-Content -Path $LogPath -Value $line
    Write-Host $line
}

Write-Log "TVStartupCheck started."

# Load config
if (-not (Test-Path $ConfigPath)) {
    Write-Log "ERROR: tv-config.json not found at $ConfigPath"
    exit 1
}

$raw    = Get-Content -Path $ConfigPath -Raw
$config = $raw | ConvertFrom-Json

$ip       = $config.IP
$port     = $config.WSPort
$uniqueId = $config.UniqueID
$model    = $config.Model

Write-Log "Config loaded. Model=$model UniqueID=$uniqueId IP=$ip WSPort=$port"

# Helper: test if TV responds on its WebSocket port
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

# Try current IP first
$online = Test-TVOnline -Address $ip -Port $port
if ($online) {
    Write-Log "TV is ONLINE at $ip`:$port"
} else {
    Write-Log "TV not responding at $ip`:$port - scanning local subnet for DHCP change..."

    # Derive subnet from local adapters
    $subnets = @()
    $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notmatch '^127\.' -and $_.PrefixLength -le 24 }
    foreach ($a in $adapters) {
        $parts = $a.IPAddress -split '\.'
        $subnet = "$($parts[0]).$($parts[1]).$($parts[2])"
        $subnets += $subnet
    }

    $found = $false
    foreach ($subnet in ($subnets | Select-Object -Unique)) {
        Write-Log "Scanning subnet $subnet.1-254 on port $port ..."
        for ($i = 1; $i -le 254; $i++) {
            $candidate = "$subnet.$i"
            if (Test-TVOnline -Address $candidate -Port $port -TimeoutMs 500) {
                Write-Log "Found device at $candidate`:$port - updating config IP."
                # Update config
                $config.IP = $candidate
                $updated = $config | ConvertTo-Json -Depth 20
                [System.IO.File]::WriteAllText($ConfigPath, $updated, [System.Text.Encoding]::UTF8)
                Write-Log "tv-config.json updated: IP changed from $ip to $candidate"
                $found = $true
                break
            }
        }
        if ($found) { break }
    }

    if (-not $found) {
        Write-Log "TV not found on any subnet. TV may be off or unreachable."
    }
}

Write-Log "TVStartupCheck complete."
