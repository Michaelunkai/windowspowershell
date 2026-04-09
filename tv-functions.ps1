# MODEL: UE50CU7100UXSQ
# SERIAL: 0KYH3HEW400178K
# FIRMWARE: T-KSU2ECDEUC-0080-2032.8
# UNIQUE_ID: UN5IYNGNBQN4T
# FIX_PATCH: RLCPQZFM2VYHQ
# PORT_WS: 8002
# PORT_REST: 8001
# PAIRING: Allow on TV first time.
# Samsung TV UE50CU7100UXSQ - PS v5 TV Functions
# Requires tv-config.json in same directory

function Get-TVConfig {
    $configPath = Join-Path $PSScriptRoot 'tv-config.json'
    Get-Content -Raw $configPath | ConvertFrom-Json
}

function Get-TVConnection {
    # Returns a cached open WebSocket to Samsung TV. Reconnects only if closed or null.
    if ($global:TVWebSocket -and $global:TVWebSocket.State -eq 'Open') {
        return $global:TVWebSocket
    }
    $global:TVWebSocket = Connect-SamsungTV
    return $global:TVWebSocket
}

function Get-TVApps {
    <#
    .SYNOPSIS
        Lists all installed apps on the Samsung TV.
    .DESCRIPTION
        GET http://<TV_IP>:8001/api/v2/applications, parses JSON array,
        prints each app name and appId, and updates tv-config.json AppIDs
        with any newly discovered IDs.
    #>
    $cfg = Get-TVConfig
    $uri = 'http://' + $cfg.IP + ':8001/api/v2/applications'

    Write-Host "Querying TV apps at $uri ..."

    try {
        $response = Invoke-RestMethod -Uri $uri -TimeoutSec 10
    } catch {
        Write-Error "Failed to contact TV at $uri : $_"
        return
    }

    if ($response.data) {
        $apps = $response.data
    } else {
        $apps = $response
    }

    if (-not $apps) {
        Write-Warning 'No apps returned from TV.'
        return
    }

    Write-Host ''
    Write-Host ('Found {0} apps:' -f $apps.Count)
    Write-Host ('{0,-40} {1}' -f 'Name', 'AppID')
    Write-Host ('-' * 70)
    $apps | Sort-Object name | ForEach-Object {
        Write-Host ('{0,-40} {1}' -f $_.name, $_.appId)
    }

    $configPath = Join-Path $PSScriptRoot 'tv-config.json'
    $cfg2 = Get-Content -Raw $configPath | ConvertFrom-Json

    if (-not ($cfg2.PSObject.Properties.Name -contains 'AppIDs')) {
        $cfg2 | Add-Member -MemberType NoteProperty -Name AppIDs -Value (New-Object PSObject) -Force
    }

    $updated = $false
    foreach ($app in $apps) {
        $safeName = $app.name -replace '[^A-Za-z0-9]', '_'
        if (-not ($cfg2.AppIDs.PSObject.Properties.Name -contains $safeName)) {
            $cfg2.AppIDs | Add-Member -MemberType NoteProperty -Name $safeName -Value $app.appId -Force
            $updated = $true
        }
    }

    $netflixKey = 'Netflix'
    if (-not ($cfg2.AppIDs.PSObject.Properties.Name -contains $netflixKey)) {
        $cfg2.AppIDs | Add-Member -MemberType NoteProperty -Name $netflixKey -Value '11101200001' -Force
        $updated = $true
    }

    if ($updated) {
        [System.IO.File]::WriteAllText(
            $configPath,
            ($cfg2 | ConvertTo-Json -Depth 20),
            [System.Text.Encoding]::UTF8
        )
        Write-Host ''
        Write-Host 'tv-config.json AppIDs updated with newly discovered apps.'
    } else {
        Write-Host ''
        Write-Host 'tv-config.json AppIDs already up to date.'
    }

    $netflix = $apps | Where-Object { $_.name -like '*Netflix*' -or $_.appId -eq '11101200001' }
    if ($netflix) {
        Write-Host ('Netflix found: name=''{0}'' appId=''{1}''' -f $netflix.name, $netflix.appId)
    } else {
        Write-Host 'Netflix not found in live app list (TV may be offline). Known ID: 11101200001'
    }

    return $apps
}

function Set-TVVolume {
    param([Parameter(Mandatory)][int]$Level)
    if (-not (Test-TVConnection)) {
        Write-Warning "Set-TVVolume: TV is not reachable. Skipping volume change."
        return
    }
    $cfg = Get-TVConfig
    $uri = 'http://' + $cfg.IP + ':8001/api/v2/devices/main/volume'
    $body = @{ value = $Level } | ConvertTo-Json
    $attempt = 0
    while ($attempt -lt 2) {
        $attempt++
        try {
            Invoke-RestMethod -Uri $uri -Method Put -Body $body -ContentType 'application/json' -TimeoutSec 10
            Write-Host "TV volume set to $Level"
            return
        } catch {
            Write-Warning "Set-TVVolume: attempt $attempt failed: $_"
            if ($attempt -ge 2) {
                Write-Warning "Set-TVVolume: gave up after 2 attempts."
            }
        }
    }
}

function Set-TVInput {
    param([Parameter(Mandatory)][string]$Source)
    if (-not (Test-TVConnection)) {
        Write-Warning "Set-TVInput: TV is not reachable. Skipping input change."
        return
    }
    $ws = Get-TVConnection
    $attempt = 0
    while ($attempt -lt 2) {
        $attempt++
        try {
            Send-TVKey -WebSocket $ws -Key "KEY_$Source"
            Write-Host "TV input switched to $Source"
            return
        } catch {
            Write-Warning "Set-TVInput: attempt $attempt failed: $_"
            try { if ($ws) { $ws.Dispose() } } catch {}
            $global:TVWebSocket = $null
            $ws = Get-TVConnection
            if ($attempt -ge 2) {
                Write-Warning "Set-TVInput: gave up after 2 attempts."
            }
        }
    }
}

function Start-TVApp {
    param([Parameter(Mandatory)][string]$AppId)
    if (-not (Test-TVConnection)) {
        Write-Warning "Start-TVApp: TV is not reachable. Skipping app launch."
        return
    }
    $cfg = Get-TVConfig
    $uri = 'http://' + $cfg.IP + ':8001/api/v2/applications/' + $AppId
    $attempt = 0
    while ($attempt -lt 2) {
        $attempt++
        try {
            Invoke-RestMethod -Uri $uri -Method Post -TimeoutSec 10
            Write-Host "Started TV app: $AppId"
            return
        } catch {
            Write-Warning "Start-TVApp: attempt $attempt failed: $_"
            if ($attempt -ge 2) {
                Write-Warning "Start-TVApp: gave up after 2 attempts for app '$AppId'."
            }
        }
    }
}

function Stop-TV {
    if (-not (Test-TVConnection)) {
        Write-Warning "Stop-TV: TV is not reachable (already off?)."
        return
    }
    $ws = Get-TVConnection
    $attempt = 0
    while ($attempt -lt 2) {
        $attempt++
        try {
            Send-TVKey -WebSocket $ws -Key 'KEY_POWEROFF'
            Write-Host 'TV power off sent.'
            return
        } catch {
            Write-Warning "Stop-TV: attempt $attempt failed: $_"
            try { if ($ws) { $ws.Dispose() } } catch {}
            $global:TVWebSocket = $null
            $ws = Get-TVConnection
            if ($attempt -ge 2) {
                Write-Warning "Stop-TV: gave up after 2 attempts."
            }
        }
    }
}

function Start-TV {
    $cfg = Get-TVConfig
    $mac = $cfg.MAC
    if (-not $mac) { Write-Warning 'No MAC in tv-config.json for WOL'; return }
    $mac = $mac -replace '[:\-]', ''
    $bytes = [byte[]](([byte[]]((,[byte]0xFF * 6))) + (([byte[]] ($mac -split '(..)' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })) * 16))
    $udp = New-Object System.Net.Sockets.UdpClient
    $udp.Connect([System.Net.IPAddress]::Broadcast, 9)
    $udp.Send($bytes, $bytes.Length) | Out-Null
    $udp.Close()
    Write-Host 'Wake-on-LAN packet sent to TV.'
}

function Test-TVConnection {
    $cfg = Get-TVConfig
    try {
        Invoke-WebRequest -Uri ('http://' + $cfg.IP + ':8001/api/v2') -TimeoutSec 2 -UseBasicParsing | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Show-TVHelp {
    Write-Host 'Connect-SamsungTV | Get-TVInfo | Send-TVKey | Set-TVVolume | Set-TVInput | Start-TVApp | Stop-TV | Start-TV | Test-TVConnection | Get-TVApps | Set-TVPictureMode'
}
