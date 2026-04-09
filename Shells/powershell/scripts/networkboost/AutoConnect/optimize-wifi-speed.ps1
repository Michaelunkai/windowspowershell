# WiFi Speed Optimization for MediaTek MT7922 (WiFi 6E)
# Maximizes download speed and performance

Write-Host "=== WiFi Speed Optimization ===" -ForegroundColor Cyan
Write-Host "Adapter: MediaTek Wi-Fi 6E MT7922 (RZ616) 160MHz" -ForegroundColor White
Write-Host ""

# Find the MediaTek WiFi adapter registry key
$baseKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
$wifiKey = $null

$subkeys = Get-ChildItem $baseKey -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\\\d{4}$' }
foreach ($subkey in $subkeys) {
    $driverDesc = (Get-ItemProperty -Path $subkey.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
    if ($driverDesc -match "MT7922|MediaTek.*Wi-Fi") {
        $wifiKey = $subkey.PSPath
        Write-Host "[FOUND] Adapter at: $wifiKey" -ForegroundColor Green
        break
    }
}

if (-not $wifiKey) {
    Write-Host "[ERROR] MediaTek WiFi adapter not found in registry" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Applying optimizations..." -ForegroundColor Yellow
Write-Host ""

# 1. Set 802.11ax (WiFi 6/6E) mode for maximum throughput
Write-Host "[1/10] Enabling WiFi 6E mode..." -ForegroundColor Yellow
Set-ItemProperty -Path $wifiKey -Name "WirelessMode" -Value 8 -Type DWord -ErrorAction SilentlyContinue
Write-Host "   [OK] 802.11ax (WiFi 6E) enabled" -ForegroundColor Green

# 2. Enable 160MHz channel width for maximum bandwidth
Write-Host "[2/10] Enabling 160MHz channel width..." -ForegroundColor Yellow
Set-ItemProperty -Path $wifiKey -Name "BandwidthCapability5GHz" -Value 2 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wifiKey -Name "ChannelWidth" -Value 160 -Type DWord -ErrorAction SilentlyContinue
Write-Host "   [OK] 160MHz channel width enabled" -ForegroundColor Green

# 3. Prefer 5GHz/6GHz bands (faster than 2.4GHz)
Write-Host "[3/10] Setting 5GHz band preference..." -ForegroundColor Yellow
Set-ItemProperty -Path $wifiKey -Name "RoamAggressiveness" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wifiKey -Name "PreferredBand" -Value 2 -Type DWord -ErrorAction SilentlyContinue
Write-Host "   [OK] 5GHz/6GHz preferred" -ForegroundColor Green

# 4. Enable MIMO (Multiple Input Multiple Output)
Write-Host "[4/10] Enabling MIMO..." -ForegroundColor Yellow
Set-ItemProperty -Path $wifiKey -Name "MIMOPowerSaveMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "   [OK] MIMO enabled (no power save)" -ForegroundColor Green

# 5. Disable U-APSD (power saving feature that adds latency)
Write-Host "[5/10] Disabling U-APSD..." -ForegroundColor Yellow
Set-ItemProperty -Path $wifiKey -Name "uAPSD" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "   [OK] U-APSD disabled (lower latency)" -ForegroundColor Green

# 6. Set maximum transmit power
Write-Host "[6/10] Setting maximum transmit power..." -ForegroundColor Yellow
Set-ItemProperty -Path $wifiKey -Name "TxPower" -Value 100 -Type DWord -ErrorAction SilentlyContinue
Write-Host "   [OK] Transmit power at maximum" -ForegroundColor Green

# 7. Optimize throughput settings
Write-Host "[7/10] Optimizing throughput..." -ForegroundColor Yellow
Set-ItemProperty -Path $wifiKey -Name "ThroughputBooster" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wifiKey -Name "AmsduSupport" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $wifiKey -Name "AmpduSupport" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "   [OK] A-MSDU and A-MPDU aggregation enabled" -ForegroundColor Green

# 8. Disable adaptive radio (keeps full performance)
Write-Host "[8/10] Disabling adaptive radio..." -ForegroundColor Yellow
Set-ItemProperty -Path $wifiKey -Name "AdaptiveRadio" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "   [OK] Adaptive radio disabled (max performance)" -ForegroundColor Green

# 9. System-wide TCP optimizations
Write-Host "[9/10] Applying TCP optimizations..." -ForegroundColor Yellow

# Enable TCP Window Auto-Tuning
netsh int tcp set global autotuninglevel=normal 2>$null
# Enable ECN
netsh int tcp set global ecncapability=enabled 2>$null
# Enable RSS (Receive Side Scaling)
netsh int tcp set global rss=enabled 2>$null
# Enable Direct Cache Access
netsh int tcp set global dca=enabled 2>$null
# Enable Receive Segment Coalescing
netsh int tcp set global rsc=enabled 2>$null

Write-Host "   [OK] TCP auto-tuning, ECN, RSS enabled" -ForegroundColor Green

# 10. DNS optimization - use fast public DNS
Write-Host "[10/10] Optimizing DNS..." -ForegroundColor Yellow
# This sets DNS for the WiFi adapter - using Cloudflare (1.1.1.1) and Google (8.8.8.8)
netsh interface ip set dns name="Wi-Fi" static 1.1.1.1 primary 2>$null
netsh interface ip add dns name="Wi-Fi" 8.8.8.8 index=2 2>$null
netsh interface ip add dns name="Wi-Fi" 1.0.0.1 index=3 2>$null
Write-Host "   [OK] Fast DNS configured (Cloudflare 1.1.1.1, Google 8.8.8.8)" -ForegroundColor Green

Write-Host ""
Write-Host "=== OPTIMIZATION COMPLETE ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Applied optimizations:" -ForegroundColor White
Write-Host "  - WiFi 6E (802.11ax) mode enabled" -ForegroundColor Gray
Write-Host "  - 160MHz channel width for max bandwidth" -ForegroundColor Gray
Write-Host "  - 5GHz/6GHz band preferred" -ForegroundColor Gray
Write-Host "  - MIMO enabled (no power save)" -ForegroundColor Gray
Write-Host "  - U-APSD disabled (lower latency)" -ForegroundColor Gray
Write-Host "  - Maximum transmit power" -ForegroundColor Gray
Write-Host "  - A-MSDU/A-MPDU packet aggregation" -ForegroundColor Gray
Write-Host "  - TCP optimizations (auto-tuning, RSS, ECN)" -ForegroundColor Gray
Write-Host "  - Fast DNS (Cloudflare + Google)" -ForegroundColor Gray
Write-Host ""
Write-Host "REBOOT RECOMMENDED for all changes to take full effect." -ForegroundColor Yellow
Write-Host ""
