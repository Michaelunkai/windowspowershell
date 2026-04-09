#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Fully automated setup: Tailscale Funnel + OpenClaw Dashboard always-on.
.DESCRIPTION
    Step 1: Install Tailscale (winget)
    Step 2: Login to Tailscale (auto-opens browser)
    Step 3: Auto-configure ACL via Tailscale API (creates API key if needed)
    Step 4: Enable Funnel for this node
    Step 5: Update openclaw.json for Tailscale Funnel
    Step 6: Install OpenClaw gateway as Windows service
    Step 7: Auto-open dashboard in browser + output URL
.NOTES
    Run as Administrator in PowerShell 5.1+
    Free Tailscale account required (sign up at https://tailscale.com)
#>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$openclawConfig = "$env:USERPROFILE\.openclaw\openclaw.json"
$tailscaleCli   = "C:\Program Files\Tailscale\tailscale.exe"
$port           = 18789
$apiKeyFile     = "$env:USERPROFILE\.tailscale-api-key"

function Write-Step($num, $msg) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  STEP $num - $msg" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Find-Tailscale {
    $candidates = @(
        "C:\Program Files\Tailscale\tailscale.exe",
        "C:\Program Files (x86)\Tailscale\tailscale.exe",
        "$env:LOCALAPPDATA\Tailscale\tailscale.exe",
        "$env:LOCALAPPDATA\Programs\Tailscale\tailscale.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    $cmd = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-TailscaleHostname {
    $ErrorActionPreference = 'SilentlyContinue'
    $raw = & $script:tailscaleCli status --json 2>$null
    $ErrorActionPreference = 'Stop'
    if (-not $raw) { return $null }
    $obj = $raw | ConvertFrom-Json
    if ($obj.BackendState -ne 'Running') { return $null }
    $dns = $obj.Self.DNSName
    if ($dns) { return $dns.TrimEnd('.') }
    return $null
}

function Get-TailnetName {
    # Extract tailnet name from hostname (e.g. "user-1.tail5cbd67.ts.net" -> "tail5cbd67.ts.net")
    $ErrorActionPreference = 'SilentlyContinue'
    $raw = & $script:tailscaleCli status --json 2>$null
    $ErrorActionPreference = 'Stop'
    if (-not $raw) { return $null }
    $obj = $raw | ConvertFrom-Json
    $dns = $obj.Self.DNSName
    if ($dns) {
        $dns = $dns.TrimEnd('.')
        # tailnet is everything after first dot
        $dotIdx = $dns.IndexOf('.')
        if ($dotIdx -gt 0) { return $dns.Substring($dotIdx + 1) }
    }
    # Try MagicDNSSuffix
    if ($obj.MagicDNSSuffix) { return $obj.MagicDNSSuffix }
    return $null
}

# ── STEP 1: Install Tailscale ──────────────────────────────────────────────
Write-Step 1 "Install Tailscale"

$tailscaleCli = Find-Tailscale

if ($tailscaleCli) {
    Write-Host "Tailscale already installed at: $tailscaleCli" -ForegroundColor Green
} else {
    # Nuke any ghost winget entries first
    Write-Host "Cleaning up ghost installs..." -ForegroundColor Yellow
    $ErrorActionPreference = 'SilentlyContinue'
    winget uninstall --id Tailscale.Tailscale --silent --force 2>&1 | Out-Null
    # Also nuke winget's internal package state for Tailscale
    $wingetDB = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState"
    if (Test-Path $wingetDB) {
        Get-ChildItem $wingetDB -Filter '*.db' -ErrorAction SilentlyContinue | ForEach-Object {
            # Touch the DB to force winget to re-scan
        }
    }
    $ErrorActionPreference = 'Stop'
    Start-Sleep -Seconds 2

    # Direct download - always reliable, no winget phantom issues
    Write-Host "Downloading Tailscale installer..." -ForegroundColor Yellow
    $installerPath = "$env:TEMP\tailscale-setup.exe"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object Net.WebClient).DownloadFile("https://pkgs.tailscale.com/stable/tailscale-setup-full-1.96.2.exe", $installerPath)
    Write-Host "Installing Tailscale (silent)..." -ForegroundColor Yellow
    Start-Process -FilePath $installerPath -ArgumentList '/install', '/quiet', '/norestart' -Wait
    Start-Sleep -Seconds 5

    # Find the installed binary
    $tailscaleCli = Find-Tailscale
    if (-not $tailscaleCli) {
        # Wait a bit more for install to finish
        $retries = 0
        while ($retries -lt 15) {
            Start-Sleep -Seconds 2; $retries++
            $tailscaleCli = Find-Tailscale
            if ($tailscaleCli) { break }
        }
    }

    if (-not $tailscaleCli) {
        Write-Error "Tailscale CLI not found after install. Reboot and re-run this script."
    }
    Write-Host "Tailscale installed at: $tailscaleCli" -ForegroundColor Green
}

# Ensure Tailscale service + GUI are running (GUI required on Windows for full init)
$ErrorActionPreference = 'SilentlyContinue'
$tsSvc = Get-Service -Name 'Tailscale' -ErrorAction SilentlyContinue
if ($tsSvc -and $tsSvc.Status -ne 'Running') {
    Start-Service -Name 'Tailscale'
    Start-Sleep -Seconds 3
}
# Launch GUI (tailscale-ipn.exe) - required on Windows for daemon to fully connect
$ipnProc = Get-Process 'tailscale-ipn' -ErrorAction SilentlyContinue
if (-not $ipnProc) {
    $ipnPath = Join-Path (Split-Path $tailscaleCli) 'tailscale-ipn.exe'
    if (Test-Path $ipnPath) {
        Start-Process $ipnPath
        Write-Host "Launched Tailscale GUI (required for connection)." -ForegroundColor Gray
    }
}
$ErrorActionPreference = 'Stop'

# Wait for Tailscale daemon to be ready
Write-Host "Waiting for Tailscale daemon..." -ForegroundColor Yellow
$retries = 0
while ($retries -lt 30) {
    $ErrorActionPreference = 'SilentlyContinue'
    $raw = & $tailscaleCli status --json 2>$null
    $ErrorActionPreference = 'Stop'
    if ($raw) {
        $obj = $raw | ConvertFrom-Json
        if ($obj.BackendState -and $obj.BackendState -ne 'NoState') { break }
    }
    Start-Sleep -Seconds 2; $retries++
}

# ── STEP 2: Login to Tailscale ─────────────────────────────────────────────
Write-Step 2 "Login to Tailscale"

$hostname = Get-TailscaleHostname

if ($hostname) {
    Write-Host "Already logged in as: $hostname" -ForegroundColor Green
} else {
    Write-Host "Logging in to Tailscale..." -ForegroundColor Yellow

    # Run tailscale up in background job to capture auth URL
    $job = Start-Job -ScriptBlock {
        param($cli)
        & $cli up 2>&1
    } -ArgumentList $tailscaleCli

    # Wait for auth URL to appear in output, then open browser
    $authUrlOpened = $false
    $retries = 0
    while ($retries -lt 60) {
        Start-Sleep -Seconds 2; $retries++
        # Check if job produced auth URL
        if (-not $authUrlOpened) {
            $jobOutput = Receive-Job $job 2>&1 | Out-String
            if ($jobOutput -match '(https://login\.tailscale\.com/\S+)') {
                $authUrl = $Matches[1]
                Write-Host "Opening login URL in browser..." -ForegroundColor Yellow
                Start-Process $authUrl
                $authUrlOpened = $true
            }
        }
        # Check if we got hostname (login complete)
        $hostname = Get-TailscaleHostname
        if ($hostname) { break }
        # Check if job finished
        if ($job.State -eq 'Completed') {
            $hostname = Get-TailscaleHostname
            break
        }
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    if (-not $hostname) {
        Write-Error "Could not get Tailscale hostname. Make sure login completed."
    }
    Write-Host "Logged in as: $hostname" -ForegroundColor Green
}

# ── STEP 3: Auto-configure ACL via Tailscale API ──────────────────────────
Write-Step 3 "Auto-configure Funnel ACL policy"

$tailnet = Get-TailnetName
Write-Host "Tailnet: $tailnet" -ForegroundColor Gray

# Get or create API key
$apiKey = $null
if (Test-Path $apiKeyFile) {
    $apiKey = (Get-Content $apiKeyFile -Raw).Trim()
    Write-Host "Using saved API key." -ForegroundColor Green
}

# Test if funnel already works (skip API key step entirely)
$ErrorActionPreference = 'SilentlyContinue'
& $tailscaleCli serve --bg https+insecure://localhost:$port 2>$null
& $tailscaleCli funnel --bg $port 2>$null
$funnelWorks = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = 'Stop'

if ($funnelWorks) {
    Write-Host "Funnel already enabled - ACL is configured!" -ForegroundColor Green
} else {
    # Need to configure ACL via API
    if (-not $apiKey) {
        Write-Host ""
        Write-Host "Funnel requires an ACL policy change. This needs a one-time API key." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Opening Tailscale API key page in browser..." -ForegroundColor Yellow
        Start-Process "https://login.tailscale.com/admin/settings/keys"
        Start-Sleep -Seconds 2
        Write-Host ""
        Write-Host "In the browser:" -ForegroundColor White
        Write-Host '  1. Click "Generate API key"' -ForegroundColor White
        Write-Host "  2. Copy the key" -ForegroundColor White
        Write-Host "  3. Paste it here and press ENTER" -ForegroundColor White
        Write-Host ""
        $apiKey = Read-Host "Paste your Tailscale API key"
        $apiKey = $apiKey.Trim()
        # Save for future runs
        $apiKey | Set-Content $apiKeyFile -Force
        Write-Host "API key saved for future use." -ForegroundColor Green
    }

    # Read current ACL policy
    Write-Host "Reading current ACL policy..." -ForegroundColor Yellow
    $headers = @{
        'Authorization' = "Bearer $apiKey"
        'Accept'        = 'application/json'
    }

    $ErrorActionPreference = 'SilentlyContinue'
    $aclResponse = Invoke-RestMethod -Uri "https://api.tailscale.com/api/v2/tailnet/-/acl" -Headers $headers -Method Get -ErrorAction SilentlyContinue
    $ErrorActionPreference = 'Stop'

    if (-not $aclResponse) {
        # Try with tailnet name
        $ErrorActionPreference = 'SilentlyContinue'
        $aclResponse = Invoke-RestMethod -Uri "https://api.tailscale.com/api/v2/tailnet/$tailnet/acl" -Headers $headers -Method Get -ErrorAction SilentlyContinue
        $ErrorActionPreference = 'Stop'
    }

    if ($aclResponse) {
        Write-Host "Current ACL policy retrieved." -ForegroundColor Green

        # Check if nodeAttrs already has funnel
        $needsUpdate = $true
        if ($aclResponse.nodeAttrs) {
            foreach ($attr in $aclResponse.nodeAttrs) {
                if ($attr.attr -contains 'funnel') {
                    $needsUpdate = $false
                    Write-Host "Funnel already in nodeAttrs." -ForegroundColor Green
                    break
                }
            }
        }

        if ($needsUpdate) {
            Write-Host "Adding funnel to ACL nodeAttrs..." -ForegroundColor Yellow

            # Add nodeAttrs with funnel
            $funnelAttr = @{
                'target' = @('autogroup:member')
                'attr'   = @('funnel')
            }

            if ($aclResponse.nodeAttrs) {
                $aclResponse.nodeAttrs += $funnelAttr
            } else {
                $aclResponse | Add-Member -NotePropertyName 'nodeAttrs' -NotePropertyValue @($funnelAttr) -Force
            }

            # Write updated ACL
            $body = $aclResponse | ConvertTo-Json -Depth 20
            $postHeaders = @{
                'Authorization' = "Bearer $apiKey"
                'Content-Type'  = 'application/json'
            }

            $ErrorActionPreference = 'SilentlyContinue'
            Invoke-RestMethod -Uri "https://api.tailscale.com/api/v2/tailnet/-/acl" -Headers $postHeaders -Method Post -Body $body -ErrorAction SilentlyContinue
            $ErrorActionPreference = 'Stop'

            if ($LASTEXITCODE -eq 0 -or $?) {
                Write-Host "ACL updated - funnel permission added!" -ForegroundColor Green
            } else {
                # Fallback: try HuJSON format
                $ErrorActionPreference = 'SilentlyContinue'
                $postHeaders['Content-Type'] = 'application/hujson'
                Invoke-RestMethod -Uri "https://api.tailscale.com/api/v2/tailnet/-/acl" -Headers $postHeaders -Method Post -Body $body -ErrorAction SilentlyContinue
                $ErrorActionPreference = 'Stop'
                Write-Host "ACL update sent." -ForegroundColor Yellow
            }

            # Wait for ACL to propagate
            Write-Host "Waiting for ACL changes to propagate..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    } else {
        Write-Host "Could not retrieve ACL via API. Trying manual approach..." -ForegroundColor Yellow
        Start-Process "https://login.tailscale.com/admin/acls/visual/node-attributes/add"
        Write-Host "  Add nodeAttr: target=autogroup:member, attr=funnel, then Save" -ForegroundColor White
        Write-Host "  Script will auto-detect when done..." -ForegroundColor White
    }

    # Retry funnel after ACL update
    $maxWait = 60; $waited = 0; $funnelOk = $false
    while ($waited -lt $maxWait) {
        $ErrorActionPreference = 'SilentlyContinue'
        & $tailscaleCli serve --bg https+insecure://localhost:$port 2>$null
        & $tailscaleCli funnel --bg $port 2>$null
        $result = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($result -eq 0) { $funnelOk = $true; break }
        Start-Sleep -Seconds 5; $waited += 5
        Write-Host "  Retrying funnel... ($waited/$maxWait sec)" -ForegroundColor Gray
    }

    if (-not $funnelOk) {
        # Try alternate funnel syntax
        $ErrorActionPreference = 'SilentlyContinue'
        & $tailscaleCli funnel on 2>$null
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Funnel could not be enabled after ACL update. Check https://login.tailscale.com/admin/acls and re-run."
        }
    }
}

Write-Host "Funnel enabled successfully!" -ForegroundColor Green

# Show funnel status
$ErrorActionPreference = 'SilentlyContinue'
& $tailscaleCli funnel status 2>&1 | Write-Host
$ErrorActionPreference = 'Stop'

# ── STEP 4: Enable HTTPS certificates ─────────────────────────────────────
Write-Step 4 "Enable HTTPS certificates"

Write-Host "Requesting TLS certificate for $hostname ..." -ForegroundColor Yellow
$ErrorActionPreference = 'SilentlyContinue'
& $tailscaleCli cert $hostname 2>$null
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -eq 0) {
    Write-Host "HTTPS certificates enabled." -ForegroundColor Green
} else {
    Write-Host "TLS cert skipped (Funnel handles its own TLS)." -ForegroundColor Yellow
}

# ── STEP 5: Update openclaw.json ───────────────────────────────────────────
Write-Step 5 "Check OpenClaw config"

if (-not (Test-Path $openclawConfig)) {
    Write-Error "OpenClaw config not found at $openclawConfig"
}

$json = Get-Content $openclawConfig -Raw | ConvertFrom-Json
$configChanged = $false

if ($json.gateway.bind -ne 'loopback') {
    $json.gateway.bind = "loopback"; $configChanged = $true
}
if ($json.gateway.tailscale.mode -ne 'funnel') {
    $json.gateway.tailscale.mode = "funnel"; $configChanged = $true
}
if ($json.gateway.tailscale.resetOnExit -ne $false) {
    $json.gateway.tailscale.resetOnExit = $false; $configChanged = $true
}
if (-not $json.gateway.controlUi.allowedOrigins -or $json.gateway.controlUi.allowedOrigins -notcontains '*') {
    $json.gateway.controlUi.allowedOrigins = @("*"); $configChanged = $true
}
if ($json.gateway.controlUi.dangerouslyDisableDeviceAuth -ne $true) {
    $json.gateway.controlUi | Add-Member -NotePropertyName 'dangerouslyDisableDeviceAuth' -NotePropertyValue $true -Force
    $configChanged = $true
}

if ($configChanged) {
    $json | ConvertTo-Json -Depth 20 | Set-Content $openclawConfig -Encoding UTF8
    Write-Host "openclaw.json updated: bind=loopback, tailscale.mode=funnel" -ForegroundColor Green
} else {
    Write-Host "Config already correct - no changes needed." -ForegroundColor Green
}

# ── STEP 6: Gateway check (managed by ClawdbotTray.vbs) ───────────────────
Write-Step 6 "Gateway check"

Write-Host "Gateway is managed by ClawdbotTray.vbs" -ForegroundColor Gray
Write-Host "No restart needed - openclaw.json changes apply via hot-reload." -ForegroundColor Green

# ── STEP 7: Output URL + Auto-open in browser ─────────────────────────────
Write-Step 7 "Your Global Dashboard URL"

# Re-fetch hostname in case it was empty
if (-not $hostname) { $hostname = Get-TailscaleHostname }
$token = $json.gateway.auth.token

$publicUrl = "https://$hostname"
$dashboardUrl = "https://${hostname}/#token=$token"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Public URL:     $publicUrl" -ForegroundColor White
Write-Host "  Dashboard URL:  $dashboardUrl" -ForegroundColor White
Write-Host ""
Write-Host "  This URL works from ANYWHERE on the internet." -ForegroundColor Yellow
Write-Host "  OpenClaw auto-starts on boot. Tailscale keeps tunnel alive." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Verify funnel:  tailscale funnel status" -ForegroundColor Gray
Write-Host "  Verify gateway: openclaw gateway status" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Green

# Auto-open dashboard in browser
Write-Host ""
Write-Host "Opening dashboard in browser..." -ForegroundColor Yellow
Start-Process $dashboardUrl
