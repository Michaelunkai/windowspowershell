# DNS Bypass Guide - ISP/Carrier Blocking (Android & Windows)

## Overview
ISPs and mobile carriers (like Partner 5G's CyberGuard) block websites by controlling DNS servers. When you request a website, your device asks the ISP's DNS server for the IP address. The ISP can lie or refuse to respond, blocking access.

**Solution:** Use independent DNS servers (Google, Cloudflare) instead of your ISP's DNS.

---

## Android - Complete Step-by-Step Guide

### Method 1: Private DNS (Recommended - Permanent)

**Step 1:** Open Settings
- Tap the Settings app (gear icon)

**Step 2:** Navigate to Network Settings
- Scroll down and tap **"Connections"** or **"Network & Internet"**
- Tap **"More connection settings"** or **"Advanced"**

**Step 3:** Enable Private DNS
- Find and tap **"Private DNS"**
- Select **"Private DNS provider hostname"**

**Step 4:** Enter DNS Provider
Choose one:
- **Google DNS:** `dns.google` (most reliable)
- **Cloudflare DNS:** `1dot1dot1dot1.cloudflare-dns.com` (fastest, most private)
- **Quad9:** `dns.quad9.net` (blocks malware)

**Step 5:** Save and Test
- Tap **"Save"** or **"OK"**
- Open browser and test blocked sites
- Setting survives reboots ✅

### Method 2: Via ADB (Advanced - For PC Users)

**Requirements:**
- USB cable
- ADB installed on PC
- USB Debugging enabled on phone

**Steps:**

1. **Enable Developer Options:**
   - Settings → About Phone → Tap "Build Number" 7 times
   - Go back → Settings → Developer Options
   - Enable "USB Debugging"

2. **Connect Phone to PC:**
   - Plug USB cable
   - On phone: Tap notification → Select "File Transfer"
   - Approve "Allow USB debugging?" popup → Check "Always allow"

3. **Run ADB Commands:**
   ```bash
   # Enable Private DNS with Google DNS
   adb shell settings put global private_dns_mode hostname
   adb shell settings put global private_dns_default_mode hostname
   adb shell settings put global private_dns_specifier dns.google
   
   # Verify it worked
   adb shell settings get global private_dns_mode
   # Should output: hostname
   ```

4. **Alternative DNS Providers:**
   ```bash
   # Cloudflare
   adb shell settings put global private_dns_specifier 1dot1dot1dot1.cloudflare-dns.com
   
   # Quad9
   adb shell settings put global private_dns_specifier dns.quad9.net
   ```

---

## Windows - Complete Step-by-Step Guide

### Method 1: GUI (Recommended for Most Users)

**Step 1:** Open Network Connections
- Press `Windows + R`
- Type: `ncpa.cpl`
- Press Enter

**Step 2:** Access Adapter Properties
- Right-click your active network adapter (Wi-Fi or Ethernet - the one with color icon)
- Click **"Properties"**

**Step 3:** Configure IPv4 DNS
- Scroll down and click **"Internet Protocol Version 4 (TCP/IPv4)"**
- Click **"Properties"** button

**Step 4:** Enter Custom DNS Servers
- Select **"Use the following DNS servers"**
- Enter your chosen DNS:

**Google DNS:**
- Preferred DNS: `8.8.8.8`
- Alternate DNS: `8.8.4.4`

**Cloudflare DNS (Faster, More Private):**
- Preferred DNS: `1.1.1.1`
- Alternate DNS: `1.0.0.1`

**Quad9 (Blocks Malware):**
- Preferred DNS: `9.9.9.9`
- Alternate DNS: `149.112.112.112`

**Step 5:** Configure IPv6 DNS (Optional but Recommended)
- Click **"OK"** on IPv4 window
- Double-click **"Internet Protocol Version 6 (TCP/IPv6)"**
- Select **"Use the following DNS servers"**

**Google DNS (IPv6):**
- Preferred: `2001:4860:4860::8888`
- Alternate: `2001:4860:4860::8844`

**Cloudflare DNS (IPv6):**
- Preferred: `2606:4700:4700::1111`
- Alternate: `2606:4700:4700::1001`

**Step 6:** Apply and Test
- Click **"OK"** on all windows
- Close Network Connections
- Open Command Prompt and run: `ipconfig /flushdns`
- Test blocked sites in browser

### Method 2: PowerShell (Advanced - Faster)

**Run PowerShell as Administrator:**

```powershell
# Get your network adapter name
Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object Name

# Set DNS (replace "Wi-Fi" with your adapter name from above)
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses ("8.8.8.8","8.8.4.4")

# Verify
Get-DnsClientServerAddress -InterfaceAlias "Wi-Fi"

# Flush DNS cache
Clear-DnsClientCache

# Alternative: Cloudflare
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses ("1.1.1.1","1.0.0.1")
```

### Method 3: Registry (System-Wide, All Adapters)

⚠️ **Advanced - Use with caution**

```powershell
# Run as Administrator
# Set default DNS for all future network connections
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "NameServer" -Value "8.8.8.8,8.8.4.4" -PropertyType String -Force
```

---

## DNS Provider Comparison

| Provider | Primary DNS | Secondary DNS | Speed | Privacy | Blocks Malware | Notes |
|----------|-------------|---------------|-------|---------|----------------|-------|
| **Google DNS** | 8.8.8.8 | 8.8.4.4 | Fast | Low | No | Most reliable, logs queries |
| **Cloudflare** | 1.1.1.1 | 1.0.0.1 | Fastest | High | No | Privacy-focused, minimal logging |
| **Quad9** | 9.9.9.9 | 149.112.112.112 | Fast | High | Yes | Blocks known malicious domains |
| **OpenDNS** | 208.67.222.222 | 208.67.220.220 | Medium | Medium | Yes | Optional parental controls |

**Hostname (for Android Private DNS):**
- Google: `dns.google`
- Cloudflare: `1dot1dot1dot1.cloudflare-dns.com`
- Quad9: `dns.quad9.net`

---

## Troubleshooting

### Android Not Connecting After DNS Change
1. Go to Settings → Connections → Wi-Fi
2. Long-press your Wi-Fi network → "Forget"
3. Reconnect and re-enter password
4. Private DNS setting will persist

### Windows Not Working
1. Flush DNS cache: `ipconfig /flushdns`
2. Restart network adapter: `ipconfig /release` then `ipconfig /renew`
3. Reboot PC if necessary
4. Check firewall isn't blocking port 53 (DNS)

### Still Blocked
- ISP may block port 53 entirely (rare)
- Solution: Use DNS-over-HTTPS (DoH) instead:
  - Windows 11: Settings → Network → DNS → "DNS over HTTPS"
  - Android: Some browsers (Firefox, Chrome) have built-in DoH settings

---

## How It Works

**Normal DNS (ISP-controlled):**
```
Your Device → ISP DNS Server → Website IP (or block message)
```

**Custom DNS (Bypass):**
```
Your Device → Google/Cloudflare DNS → Real Website IP ✅
```

**Why This Works:**
- Your ISP can only block DNS queries sent to THEIR servers
- When you use Google/Cloudflare DNS, queries bypass ISP filtering
- ISP sees encrypted traffic but can't block specific sites (unless using deep packet inspection)

---

## Privacy & Security Notes

✅ **Safe:** Using third-party DNS is standard practice  
✅ **Legal:** No laws against choosing your own DNS  
✅ **Permanent:** Survives reboots and updates  
❌ **Not Anonymous:** DNS provider can see your queries (choose privacy-focused like Cloudflare)  
❌ **Not VPN:** Your ISP still sees encrypted traffic, just not which sites

---

## Real-World Example: Partner 5G CyberGuard

**Problem:** Partner's CyberGuard blocked OpenClaw gateway as "unsafe site"

**Solution Applied (Android):**
```bash
adb shell settings put global private_dns_mode hostname
adb shell settings put global private_dns_specifier dns.google
```

**Result:** ✅ Permanent bypass, app connects successfully

---

## Additional Resources

- Google DNS Info: https://developers.google.com/speed/public-dns
- Cloudflare 1.1.1.1: https://1.1.1.1/
- Quad9: https://www.quad9.net/
- Test DNS Speed: https://www.dnsperf.com/

---

*Last Updated: February 11, 2026*  
*Tested on: Android 13+, Windows 10/11*
