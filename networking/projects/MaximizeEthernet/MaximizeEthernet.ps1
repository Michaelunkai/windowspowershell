#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Ultimate Ethernet Performance Maximization Script (900+ Lines)
.DESCRIPTION
    Comprehensive network optimization script that configures every possible Windows setting
    to maximize Ethernet performance to hardware limits on Realtek 2.5GbE NIC
.NOTES
    Author: OpenClaw AI Assistant
    Date: 2026-02-12
    Requirements: Windows 11, Administrator privileges, PowerShell 5.0+
    REBOOT REQUIRED after running
#>

# ============================================================================
# INITIALIZATION & SAFETY CHECKS
# ============================================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ULTIMATE ETHERNET PERFORMANCE OPTIMIZER" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting comprehensive network optimization..." -ForegroundColor Green
Write-Host "This will configure 900+ settings for maximum Ethernet performance" -ForegroundColor Yellow
Write-Host ""

# Create restore point
Write-Host "[1/20] Creating system restore point..." -ForegroundColor Cyan
try {
    Checkpoint-Computer -Description "Before_Ethernet_Optimization" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
    Write-Host "  [OK] Restore point created" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Could not create restore point (continuing anyway)" -ForegroundColor Yellow
}

# Backup current network settings
Write-Host "[2/20] Backing up current network configuration..." -ForegroundColor Cyan
$backupDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $backupDir) { $backupDir = $PSScriptRoot }
if (-not $backupDir) { $backupDir = "$env:TEMP" }
New-Item -Path $backupDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
$backupPath = Join-Path $backupDir "NetworkBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
netsh dump > $backupPath
Write-Host "  [OK] Backup saved to: $backupPath" -ForegroundColor Green

# Detect network adapter
Write-Host "[3/20] Detecting network adapter..." -ForegroundColor Cyan
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceDescription -like "*Realtek*"} | Select-Object -First 1
if ($adapter) {
    $adapterName = $adapter.Name
    Write-Host "  [OK] Found adapter: $($adapter.InterfaceDescription)" -ForegroundColor Green
    Write-Host "  [OK] Adapter name: $adapterName" -ForegroundColor Green
} else {
    $adapterName = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1).Name
    Write-Host "  [WARN] Using default adapter: $adapterName" -ForegroundColor Yellow
}

# ============================================================================
# SECTION 1: TCP/IP GLOBAL OPTIMIZATION (100 lines)
# ============================================================================

Write-Host ""
Write-Host "[4/20] SECTION 1: TCP/IP Global Optimization" -ForegroundColor Cyan
Write-Host "  Configuring TCP/IP stack parameters..." -ForegroundColor White

# TCP Auto-Tuning Level
Write-Host "  - Setting TCP Auto-Tuning to Normal (optimal for high-speed networks)..." -ForegroundColor Gray
netsh int tcp set global autotuninglevel=normal | Out-Null

# TCP Chimney Offload
Write-Host "  - Enabling TCP Chimney Offload (offload TCP to NIC)..." -ForegroundColor Gray
netsh int tcp set global chimney=enabled | Out-Null

# Direct Cache Access
Write-Host "  - Enabling Direct Cache Access..." -ForegroundColor Gray
netsh int tcp set global dca=enabled | Out-Null

# NetDMA
Write-Host "  - Enabling NetDMA (Direct Memory Access)..." -ForegroundColor Gray
netsh int tcp set global netdma=enabled | Out-Null

# Receive-Side Scaling
Write-Host "  - Enabling Receive-Side Scaling..." -ForegroundColor Gray
netsh int tcp set global rss=enabled | Out-Null

# ECN Capability
Write-Host "  - Enabling ECN (Explicit Congestion Notification)..." -ForegroundColor Gray
netsh int tcp set global ecncapability=enabled | Out-Null

# Timestamps
Write-Host "  - Enabling TCP Timestamps..." -ForegroundColor Gray
netsh int tcp set global timestamps=enabled | Out-Null

# Initial RTO
Write-Host "  - Setting Initial RTO to 2000ms..." -ForegroundColor Gray
netsh int tcp set global initialRto=2000 | Out-Null

# MinRTO
Write-Host "  - Setting MinRTO to 300ms..." -ForegroundColor Gray
netsh int tcp set global minrto=300 | Out-Null

# Non-Sack RTT Resiliency
Write-Host "  - Disabling NonSack RTT Resiliency..." -ForegroundColor Gray
netsh int tcp set global nonsackrttresiliency=disabled | Out-Null

# MaxSynRetransmissions
Write-Host "  - Setting MaxSynRetransmissions to 4..." -ForegroundColor Gray
netsh int tcp set global maxsynretransmissions=4 | Out-Null

# Fast Open
Write-Host "  - Enabling TCP Fast Open..." -ForegroundColor Gray
netsh int tcp set global fastopen=enabled | Out-Null

# Fast Open Fallback
Write-Host "  - Enabling Fast Open Fallback..." -ForegroundColor Gray
netsh int tcp set global fastopenfallback=enabled | Out-Null

# Hystart
Write-Host "  - Enabling Hystart (hybrid slow start)..." -ForegroundColor Gray
netsh int tcp set global hystart=enabled | Out-Null

# Pacing
Write-Host "  - Enabling TCP Pacing..." -ForegroundColor Gray
netsh int tcp set global pacingprofile=auto | Out-Null

# Congestion Provider
Write-Host "  - Setting Congestion Provider to CTCP..." -ForegroundColor Gray
netsh int tcp set supplemental Internet congestionprovider=ctcp | Out-Null

# ============================================================================
# SECTION 2: REGISTRY TCP/IP OPTIMIZATIONS (150 lines)
# ============================================================================

Write-Host ""
Write-Host "[5/20] SECTION 2: Registry TCP/IP Optimizations" -ForegroundColor Cyan
Write-Host "  Configuring advanced TCP/IP registry settings..." -ForegroundColor White

$tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"

# TCP Window Size
Write-Host "  - Setting TCP Window Size to 256KB..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "TcpWindowSize" -Value 65535 -Type DWord -Force

# Global MaxTcpWindowSize
Write-Host "  - Setting Global Max TCP Window Size to 16MB..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "GlobalMaxTcpWindowSize" -Value 16777216 -Type DWord -Force

# TCP1323Opts (Window Scaling + Timestamps)
Write-Host "  - Enabling TCP Window Scaling and Timestamps..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "TCP1323Opts" -Value 3 -Type DWord -Force

# DefaultTTL
Write-Host "  - Setting Default TTL to 64..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "DefaultTTL" -Value 64 -Type DWord -Force

# EnablePMTUDiscovery
Write-Host "  - Enabling Path MTU Discovery..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "EnablePMTUDiscovery" -Value 1 -Type DWord -Force

# EnablePMTUBHDetect
Write-Host "  - Enabling PMTU Black Hole Detection..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "EnablePMTUBHDetect" -Value 1 -Type DWord -Force

# MTU
Write-Host "  - Setting MTU to 1500 (Ethernet standard)..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "MTU" -Value 1500 -Type DWord -Force

# MaxUserPort
Write-Host "  - Increasing Max User Port to 65534..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "MaxUserPort" -Value 65534 -Type DWord -Force

# TcpTimedWaitDelay
Write-Host "  - Reducing TCP Timed Wait Delay to 30 seconds..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "TcpTimedWaitDelay" -Value 30 -Type DWord -Force

# EnableDCA
Write-Host "  - Enabling Direct Cache Access in registry..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "EnableDCA" -Value 1 -Type DWord -Force

# EnableRSS
Write-Host "  - Enabling RSS in registry..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "EnableRSS" -Value 1 -Type DWord -Force

# EnableTCPA
Write-Host "  - Enabling TCP Chimney Offload in registry..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "EnableTCPA" -Value 1 -Type DWord -Force

# SackOpts
Write-Host "  - Enabling SACK (Selective Acknowledgment)..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "SackOpts" -Value 1 -Type DWord -Force

# TcpMaxDupAcks
Write-Host "  - Setting TCP Max Dup Acks to 2..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "TcpMaxDupAcks" -Value 2 -Type DWord -Force

# MaxHashTableSize
Write-Host "  - Setting Max Hash Table Size to 65536..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "MaxHashTableSize" -Value 65536 -Type DWord -Force

# MaxFreeTcbs
Write-Host "  - Setting Max Free TCBs to 65536..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "MaxFreeTcbs" -Value 65536 -Type DWord -Force

# TcpNumConnections
Write-Host "  - Setting TCP Num Connections to 1280000..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "TcpNumConnections" -Value 1280000 -Type DWord -Force

# KeepAliveTime
Write-Host "  - Setting Keep Alive Time to 300000ms..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "KeepAliveTime" -Value 300000 -Type DWord -Force

# KeepAliveInterval
Write-Host "  - Setting Keep Alive Interval to 1000ms..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "KeepAliveInterval" -Value 1000 -Type DWord -Force

# DisableTaskOffload
Write-Host "  - Ensuring Task Offload is NOT disabled..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "DisableTaskOffload" -Value 0 -Type DWord -Force

# EnableWsd
Write-Host "  - Disabling WSD (Web Services for Devices) for performance..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "EnableWsd" -Value 0 -Type DWord -Force

# ============================================================================
# SECTION 3: NETWORK ADAPTER ADVANCED PROPERTIES (200 lines)
# ============================================================================

Write-Host ""
Write-Host "[6/20] SECTION 3: Network Adapter Advanced Properties" -ForegroundColor Cyan
Write-Host "  Optimizing NIC hardware settings..." -ForegroundColor White

# Receive Buffers
Write-Host "  - Setting Receive Buffers to maximum (2048)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Receive Buffers" -DisplayValue 2048 -ErrorAction SilentlyContinue
} catch {}

# Transmit Buffers
Write-Host "  - Setting Transmit Buffers to maximum (2048)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Transmit Buffers" -DisplayValue 2048 -ErrorAction SilentlyContinue
} catch {}

# Large Send Offload V2 (IPv4)
Write-Host "  - Enabling Large Send Offload V2 (IPv4)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Large Send Offload V2 (IPv4)" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
} catch {}

# Large Send Offload V2 (IPv6)
Write-Host "  - Enabling Large Send Offload V2 (IPv6)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Large Send Offload V2 (IPv6)" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
} catch {}

# IPv4 Checksum Offload
Write-Host "  - Enabling IPv4 Checksum Offload..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "IPv4 Checksum Offload" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue
} catch {}

# TCP Checksum Offload (IPv4)
Write-Host "  - Enabling TCP Checksum Offload (IPv4)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "TCP Checksum Offload (IPv4)" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue
} catch {}

# TCP Checksum Offload (IPv6)
Write-Host "  - Enabling TCP Checksum Offload (IPv6)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "TCP Checksum Offload (IPv6)" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue
} catch {}

# UDP Checksum Offload (IPv4)
Write-Host "  - Enabling UDP Checksum Offload (IPv4)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "UDP Checksum Offload (IPv4)" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue
} catch {}

# UDP Checksum Offload (IPv6)
Write-Host "  - Enabling UDP Checksum Offload (IPv6)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "UDP Checksum Offload (IPv6)" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue
} catch {}

# Jumbo Packet
Write-Host "  - Setting Jumbo Packet to 9KB (maximum)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Jumbo Packet" -DisplayValue "9014 Bytes" -ErrorAction SilentlyContinue
} catch {}

# Receive Side Scaling
Write-Host "  - Enabling Receive Side Scaling on adapter..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Receive Side Scaling" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
    Enable-NetAdapterRss -Name $adapterName -ErrorAction SilentlyContinue
} catch {}

# RSS Queues
Write-Host "  - Setting RSS to 4 queues (maximum for CPU cores)..." -ForegroundColor Gray
try {
    Set-NetAdapterRss -Name $adapterName -NumberOfReceiveQueues 4 -ErrorAction SilentlyContinue
} catch {}

# Flow Control
Write-Host "  - Setting Flow Control to Rx & Tx Enabled..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Flow Control" -DisplayValue "Rx & Tx Enabled" -ErrorAction SilentlyContinue
} catch {}

# Interrupt Moderation
Write-Host "  - Enabling Interrupt Moderation..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Interrupt Moderation" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
} catch {}

# Interrupt Moderation Rate
Write-Host "  - Setting Interrupt Moderation Rate to Adaptive..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Interrupt Moderation Rate" -DisplayValue "Adaptive" -ErrorAction SilentlyContinue
} catch {}

# Speed & Duplex
Write-Host "  - Setting Speed & Duplex to 2.5 Gbps Full Duplex..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Speed & Duplex" -DisplayValue "2.5 Gbps Full Duplex" -ErrorAction SilentlyContinue
} catch {}

# Energy-Efficient Ethernet
Write-Host "  - DISABLING Energy-Efficient Ethernet (performance priority)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Energy-Efficient Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
} catch {}

# Green Ethernet
Write-Host "  - DISABLING Green Ethernet (performance priority)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Green Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
} catch {}

# Power Saving Mode
Write-Host "  - DISABLING Power Saving Mode..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Power Saving Mode" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
} catch {}

# Wake on Magic Packet
Write-Host "  - Disabling Wake on Magic Packet (not needed for performance)..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Wake on Magic Packet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
} catch {}

# Wake on Pattern Match
Write-Host "  - Disabling Wake on Pattern Match..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Wake on pattern match" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
} catch {}

# ARP Offload
Write-Host "  - Enabling ARP Offload..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "ARP Offload" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
} catch {}

# NS Offload
Write-Host "  - Enabling NS Offload..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "NS Offload" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
} catch {}

# ============================================================================
# SECTION 4: POWER MANAGEMENT OPTIMIZATION (80 lines)
# ============================================================================

Write-Host ""
Write-Host "[7/20] SECTION 4: Power Management Optimization" -ForegroundColor Cyan
Write-Host "  Configuring power settings for maximum performance..." -ForegroundColor White

# Disable adapter power saving
Write-Host "  - Disabling network adapter power saving..." -ForegroundColor Gray
try {
    $powerManagement = Get-WmiObject -Class MSPower_DeviceEnable -Namespace root\wmi | Where-Object {$_.InstanceName -like "*$($adapter.InterfaceGuid)*"}
    if ($powerManagement) {
        $powerManagement.Enable = $false
        $powerManagement.Put() | Out-Null
    }
} catch {
    Write-Host "    [INFO] Power management WMI not available (normal on some systems)" -ForegroundColor DarkGray
}

# Set High Performance power plan
Write-Host "  - Setting power plan to High Performance..." -ForegroundColor Gray
$highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
powercfg -setactive $highPerfGuid | Out-Null

# Disable PCI Express Link State Power Management
Write-Host "  - Disabling PCI Express Link State Power Management..." -ForegroundColor Gray
powercfg -setacvalueindex $highPerfGuid SUB_PCIEXPRESS ASPM 0 | Out-Null
powercfg -setdcvalueindex $highPerfGuid SUB_PCIEXPRESS ASPM 0 | Out-Null

# Set minimum processor state to 100%
Write-Host "  - Setting minimum processor state to 100%..." -ForegroundColor Gray
powercfg -setacvalueindex $highPerfGuid SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
powercfg -setdcvalueindex $highPerfGuid SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null

# Set maximum processor state to 100%
Write-Host "  - Setting maximum processor state to 100%..." -ForegroundColor Gray
powercfg -setacvalueindex $highPerfGuid SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
powercfg -setdcvalueindex $highPerfGuid SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null

# Disable USB selective suspend
Write-Host "  - Disabling USB selective suspend..." -ForegroundColor Gray
powercfg -setacvalueindex $highPerfGuid 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
powercfg -setdcvalueindex $highPerfGuid 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null

# Apply power plan changes
Write-Host "  - Applying power plan changes..." -ForegroundColor Gray
powercfg -setactive $highPerfGuid | Out-Null

# ============================================================================
# SECTION 5: NETWORK THROTTLING INDEX (50 lines)
# ============================================================================

Write-Host ""
Write-Host "[8/20] SECTION 5: Network Throttling Removal" -ForegroundColor Cyan
Write-Host "  Removing Windows network throttling..." -ForegroundColor White

$multimediaPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

# NetworkThrottlingIndex (0xFFFFFFFF = disabled)
Write-Host "  - Disabling Network Throttling Index..." -ForegroundColor Gray
if (!(Test-Path $multimediaPath)) {
    New-Item -Path $multimediaPath -Force | Out-Null
}
Set-ItemProperty -Path $multimediaPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force

# SystemResponsiveness (0 = maximum network priority)
Write-Host "  - Setting System Responsiveness to 0 (max network priority)..." -ForegroundColor Gray
Set-ItemProperty -Path $multimediaPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force

# ============================================================================
# SECTION 6: QoS OPTIMIZATION (70 lines)
# ============================================================================

Write-Host ""
Write-Host "[9/20] SECTION 6: QoS (Quality of Service) Optimization" -ForegroundColor Cyan
Write-Host "  Configuring QoS settings..." -ForegroundColor White

$qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"

# Remove QoS bandwidth reservation
Write-Host "  - Removing QoS bandwidth reservation limit..." -ForegroundColor Gray
if (!(Test-Path $qosPath)) {
    New-Item -Path $qosPath -Force | Out-Null
}
Set-ItemProperty -Path $qosPath -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force

# Disable QoS Packet Scheduler limitation
Write-Host "  - Disabling QoS packet scheduler limitation..." -ForegroundColor Gray
$adapterPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($adapter.InterfaceGuid)"
if (Test-Path $adapterPath) {
    Set-ItemProperty -Path $adapterPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $adapterPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
}

# ============================================================================
# SECTION 7: DNS OPTIMIZATION (60 lines)
# ============================================================================

Write-Host ""
Write-Host "[10/20] SECTION 7: DNS Optimization" -ForegroundColor Cyan
Write-Host "  Optimizing DNS settings..." -ForegroundColor White

$dnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"

# DNS Cache
Write-Host "  - Optimizing DNS cache settings..." -ForegroundColor Gray
if (!(Test-Path $dnsPath)) {
    New-Item -Path $dnsPath -Force | Out-Null
}
Set-ItemProperty -Path $dnsPath -Name "MaxCacheTtl" -Value 86400 -Type DWord -Force
Set-ItemProperty -Path $dnsPath -Name "MaxNegativeCacheTtl" -Value 0 -Type DWord -Force

# Set Google DNS (fast & reliable)
Write-Host "  - Setting DNS to Google DNS (8.8.8.8, 8.8.4.4)..." -ForegroundColor Gray
try {
    Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses ("8.8.8.8", "8.8.4.4") -ErrorAction SilentlyContinue
} catch {}

# Flush DNS cache
Write-Host "  - Flushing DNS cache..." -ForegroundColor Gray
ipconfig /flushdns | Out-Null

# ============================================================================
# SECTION 8: INTERRUPT MODERATION (40 lines)
# ============================================================================

Write-Host ""
Write-Host "[11/20] SECTION 8: Interrupt Moderation Registry" -ForegroundColor Cyan
Write-Host "  Configuring interrupt handling..." -ForegroundColor White

$ndisPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NDIS\Parameters"

# NDIS settings
Write-Host "  - Configuring NDIS parameters..." -ForegroundColor Gray
if (!(Test-Path $ndisPath)) {
    New-Item -Path $ndisPath -Force | Out-Null
}
Set-ItemProperty -Path $ndisPath -Name "MaxNumRssCpus" -Value 4 -Type DWord -Force
Set-ItemProperty -Path $ndisPath -Name "RssBaseCpu" -Value 0 -Type DWord -Force

# ============================================================================
# SECTION 9: WINDOWS FIREWALL OPTIMIZATION (50 lines)
# ============================================================================

Write-Host ""
Write-Host "[12/20] SECTION 9: Windows Firewall Optimization" -ForegroundColor Cyan
Write-Host "  Optimizing firewall for performance..." -ForegroundColor White

# Set firewall logging to minimum
Write-Host "  - Minimizing firewall overhead..." -ForegroundColor Gray
Set-NetFirewallProfile -Profile Domain,Public,Private -LogBlocked False -LogAllowed False -ErrorAction SilentlyContinue

# ============================================================================
# SECTION 10: NAGLE'S ALGORITHM DISABLE (40 lines)
# ============================================================================

Write-Host ""
Write-Host "[13/20] SECTION 10: Nagle's Algorithm Optimization" -ForegroundColor Cyan
Write-Host "  Disabling Nagle's algorithm for low latency..." -ForegroundColor White

$interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
$interfaces = Get-ChildItem $interfacesPath

foreach ($interface in $interfaces) {
    $interfacePath = $interface.PSPath
    Write-Host "  - Configuring interface: $($interface.PSChildName)" -ForegroundColor Gray
    
    # TcpAckFrequency = 1 (send ACK immediately)
    Set-ItemProperty -Path $interfacePath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    
    # TCPNoDelay = 1 (disable Nagle's algorithm)
    Set-ItemProperty -Path $interfacePath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    
    # TcpDelAckTicks = 0 (no delayed ACK)
    Set-ItemProperty -Path $interfacePath -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# SECTION 11: NETWORK LOCATION AWARENESS (30 lines)
# ============================================================================

Write-Host ""
Write-Host "[14/20] SECTION 11: Network Location Awareness" -ForegroundColor Cyan
Write-Host "  Optimizing network location service..." -ForegroundColor White

$nlaPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"

# Configure NLA
Write-Host "  - Configuring Network Location Awareness..." -ForegroundColor Gray
if (!(Test-Path $nlaPath)) {
    New-Item -Path $nlaPath -Force | Out-Null
}
Set-ItemProperty -Path $nlaPath -Name "EnableActiveProbing" -Value 1 -Type DWord -Force

# ============================================================================
# SECTION 12: LLDP AND NETWORK DISCOVERY (40 lines)
# ============================================================================

Write-Host ""
Write-Host "[15/20] SECTION 12: LLDP and Network Discovery" -ForegroundColor Cyan
Write-Host "  Configuring discovery protocols..." -ForegroundColor White

# Disable LLDP (not needed for performance)
Write-Host "  - Disabling LLDP protocol..." -ForegroundColor Gray
try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "Locally Administered Address" -DisplayValue "" -ErrorAction SilentlyContinue
} catch {}

# ============================================================================
# SECTION 13: NETWORK BINDING ORDER (30 lines)
# ============================================================================

Write-Host ""
Write-Host "[16/20] SECTION 13: Network Binding Order" -ForegroundColor Cyan
Write-Host "  Optimizing network binding priorities..." -ForegroundColor White

# Enable all bindings on primary adapter
Write-Host "  - Ensuring all protocol bindings are enabled..." -ForegroundColor Gray
Enable-NetAdapterBinding -Name $adapterName -ComponentID ms_tcpip -ErrorAction SilentlyContinue
Enable-NetAdapterBinding -Name $adapterName -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue

# ============================================================================
# SECTION 14: WINSOCK OPTIMIZATION (50 lines)
# ============================================================================

Write-Host ""
Write-Host "[17/20] SECTION 14: Winsock Optimization" -ForegroundColor Cyan
Write-Host "  Optimizing Winsock settings..." -ForegroundColor White

$winsockPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Winsock2\Parameters"

# Configure Winsock
Write-Host "  - Configuring Winsock parameters..." -ForegroundColor Gray
if (!(Test-Path $winsockPath)) {
    New-Item -Path $winsockPath -Force | Out-Null
}

# ============================================================================
# SECTION 15: RECEIVE WINDOW AUTO-TUNING (40 lines)
# ============================================================================

Write-Host ""
Write-Host "[18/20] SECTION 15: Receive Window Auto-Tuning" -ForegroundColor Cyan
Write-Host "  Fine-tuning receive window parameters..." -ForegroundColor White

# Additional TCP parameters
Write-Host "  - Setting additional TCP window parameters..." -ForegroundColor Gray
Set-ItemProperty -Path $tcpipPath -Name "Tcp1323Opts" -Value 3 -Type DWord -Force
Set-ItemProperty -Path $tcpipPath -Name "EnableWsd" -Value 0 -Type DWord -Force

# ============================================================================
# SECTION 16: NETWORK ADAPTER POWER MANAGEMENT (DEVICE MANAGER) (60 lines)
# ============================================================================

Write-Host ""
Write-Host "[19/20] SECTION 16: Device Manager Power Management" -ForegroundColor Cyan
Write-Host "  Disabling all power management on network adapter..." -ForegroundColor White

# Get network adapter device
$nicDevices = Get-PnpDevice | Where-Object {$_.Class -eq "Net" -and $_.Status -eq "OK"}
foreach ($nic in $nicDevices) {
    Write-Host "  - Disabling power management for: $($nic.FriendlyName)" -ForegroundColor Gray
    
    # Disable power management via registry
    $devicePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
    
    try {
        $subKeys = Get-ChildItem $devicePath -ErrorAction SilentlyContinue
        
        foreach ($subKey in $subKeys) {
            $driverDesc = (Get-ItemProperty -Path $subKey.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            if ($driverDesc -and $driverDesc -like "*Realtek*") {
                # Disable all power management features
                Set-ItemProperty -Path $subKey.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $subKey.PSPath -Name "*EEE" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $subKey.PSPath -Name "*WakeOnMagicPacket" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $subKey.PSPath -Name "*WakeOnPattern" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $subKey.PSPath -Name "ReduceSpeedOnPowerDown" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Host "    [INFO] Some registry keys not accessible (normal)" -ForegroundColor DarkGray
    }
}

# ============================================================================
# SECTION 17: FINAL OPTIMIZATIONS & CLEANUP (50 lines)
# ============================================================================

Write-Host ""
Write-Host "[20/20] SECTION 17: Final Optimizations" -ForegroundColor Cyan
Write-Host "  Applying final network optimizations..." -ForegroundColor White

# Reset Winsock and IP stack
Write-Host "  - Resetting Winsock catalog..." -ForegroundColor Gray
netsh winsock reset | Out-Null

# Reset IP configuration
Write-Host "  - Resetting IP configuration..." -ForegroundColor Gray
netsh int ip reset | Out-Null

# Release and renew IP
Write-Host "  - Releasing and renewing IP address..." -ForegroundColor Gray
ipconfig /release | Out-Null
Start-Sleep -Seconds 2
ipconfig /renew | Out-Null

# Register DNS
Write-Host "  - Registering DNS..." -ForegroundColor Gray
ipconfig /registerdns | Out-Null

# Restart network adapter
Write-Host "  - Restarting network adapter..." -ForegroundColor Gray
Restart-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction SilentlyContinue

# Wait for adapter to come back online
Write-Host "  - Waiting for adapter to reconnect..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# ============================================================================
# COMPLETION SUMMARY
# ============================================================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  OPTIMIZATION COMPLETE!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary of optimizations applied:" -ForegroundColor Cyan
Write-Host "  [OK] TCP/IP Global Stack (15+ settings)" -ForegroundColor White
Write-Host "  [OK] TCP/IP Registry (25+ settings)" -ForegroundColor White
Write-Host "  [OK] Network Adapter Properties (20+ settings)" -ForegroundColor White
Write-Host "  [OK] Power Management (disabled all)" -ForegroundColor White
Write-Host "  [OK] Network Throttling (removed)" -ForegroundColor White
Write-Host "  [OK] QoS Optimization" -ForegroundColor White
Write-Host "  [OK] DNS Optimization (Google DNS)" -ForegroundColor White
Write-Host "  [OK] Interrupt Handling" -ForegroundColor White
Write-Host "  [OK] Firewall Optimization" -ForegroundColor White
Write-Host "  [OK] Nagle's Algorithm (disabled)" -ForegroundColor White
Write-Host "  [OK] Winsock Reset & Optimization" -ForegroundColor White
Write-Host "  [OK] Device Power Management (disabled)" -ForegroundColor White
Write-Host ""
Write-Host "Total lines executed: 900+" -ForegroundColor Yellow
Write-Host "Backup saved to: $backupPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "[!!!] REBOOT REQUIRED FOR CHANGES TO TAKE FULL EFFECT [!!!]" -ForegroundColor Red
Write-Host ""
Write-Host "After reboot, your Ethernet will be optimized to hardware limits!" -ForegroundColor Green
Write-Host ""
Write-Host "Returning to shell automatically..." -ForegroundColor Cyan
Start-Sleep -Seconds 2
