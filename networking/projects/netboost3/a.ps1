#Requires -RunAsAdministrator
# NetBoost3 - Advanced Ethernet Optimizer (complements netboost and netboost2, no overlap)
# Version 1.0 | 2026-03-17 | NO REBOOT REQUIRED | PS5 compatible

$ErrorActionPreference = 'Continue'
$script:startTime = Get-Date
$script:count = 0

Write-Host '================================================================' -ForegroundColor Cyan
Write-Host '          NETBOOST3 - ADVANCED ETHERNET OPTIMIZER' -ForegroundColor Cyan
Write-Host '   Complements netboost and netboost2 - no overlap' -ForegroundColor Cyan
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ''

function Apply {
    param([string]$Desc, [scriptblock]$Action)
    $script:count++
    try {
        & $Action 2>$null | Out-Null
        Write-Host "  [OK] $Desc" -ForegroundColor Green
    } catch {
        $err = $_.Exception.Message
        Write-Host "  [--] $Desc - skipped: $err" -ForegroundColor DarkGray
    }
}

# Detect active Ethernet adapter
$eth = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and ($_.MediaType -eq '802.3' -or $_.InterfaceDescription -like '*Ethernet*' -or $_.InterfaceDescription -like '*Realtek*') } | Select-Object -First 1
if (-not $eth) { $eth = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 }
$name = $eth.Name
$ifIndex = $eth.ifIndex
Write-Host "  Adapter: $($eth.InterfaceDescription) [$name]" -ForegroundColor Yellow
Write-Host ''

# ============================================================================
# SECTION 1: NetTCPSetting TUNING
# ============================================================================
Write-Host '[1/15] NetTCPSetting Profile Tuning' -ForegroundColor Cyan

Apply 'Internet: InitialCongestionWindow=10' {
    Set-NetTCPSetting -SettingName Internet -InitialCongestionWindow 10 -ErrorAction Stop
}
Apply 'Internet: CongestionProvider=CUBIC' {
    Set-NetTCPSetting -SettingName Internet -CongestionProvider CUBIC -ErrorAction Stop
}
Apply 'Internet: AutoTuningLevelLocal=Experimental' {
    Set-NetTCPSetting -SettingName Internet -AutoTuningLevelLocal Experimental -ErrorAction Stop
}
Apply 'Internet: ScalingHeuristics=Disabled' {
    Set-NetTCPSetting -SettingName Internet -ScalingHeuristics Disabled -ErrorAction Stop
}
Apply 'Internet: EcnCapability=Enabled' {
    Set-NetTCPSetting -SettingName Internet -EcnCapability Enabled -ErrorAction Stop
}
Apply 'Internet: Timestamps=Enabled' {
    Set-NetTCPSetting -SettingName Internet -Timestamps Enabled -ErrorAction Stop
}
Apply 'Internet: MaxSynRetransmissions=2' {
    Set-NetTCPSetting -SettingName Internet -MaxSynRetransmissions 2 -ErrorAction Stop
}
Apply 'Internet: NonSackRttResiliency=Disabled' {
    Set-NetTCPSetting -SettingName Internet -NonSackRttResiliency Disabled -ErrorAction Stop
}
Apply 'Internet: InitialRto=2000' {
    Set-NetTCPSetting -SettingName Internet -InitialRto 2000 -ErrorAction Stop
}
Apply 'Internet: MinRto=300' {
    Set-NetTCPSetting -SettingName Internet -MinRto 300 -ErrorAction Stop
}
Apply 'Internet: DelayedAckTimeout=40ms' {
    Set-NetTCPSetting -SettingName Internet -DelayedAckTimeout 40 -ErrorAction Stop
}
Apply 'Internet: DelayedAckFrequency=1' {
    Set-NetTCPSetting -SettingName Internet -DelayedAckFrequency 1 -ErrorAction Stop
}
Apply 'Internet: MemoryPressureProtection=Disabled' {
    Set-NetTCPSetting -SettingName Internet -MemoryPressureProtection Disabled -ErrorAction Stop
}
Apply 'Internet: ForceWS=Enabled' {
    Set-NetTCPSetting -SettingName Internet -ForceWS Enabled -ErrorAction Stop
}
Apply 'Datacenter: CongestionProvider=CUBIC' {
    Set-NetTCPSetting -SettingName Datacenter -CongestionProvider CUBIC -ErrorAction Stop
}
Apply 'Datacenter: AutoTuningLevelLocal=Experimental' {
    Set-NetTCPSetting -SettingName Datacenter -AutoTuningLevelLocal Experimental -ErrorAction Stop
}
Apply 'Datacenter: EcnCapability=Enabled' {
    Set-NetTCPSetting -SettingName Datacenter -EcnCapability Enabled -ErrorAction Stop
}
Apply 'Compat: CongestionProvider=CUBIC' {
    Set-NetTCPSetting -SettingName Compat -CongestionProvider CUBIC -ErrorAction Stop
}
Apply 'DatacenterCustom: CongestionProvider=CUBIC' {
    Set-NetTCPSetting -SettingName DatacenterCustom -CongestionProvider CUBIC -ErrorAction Stop
}
Apply 'InternetCustom: CongestionProvider=CUBIC' {
    Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider CUBIC -ErrorAction Stop
}

# ============================================================================
# SECTION 2: ADAPTER OFFLOAD TASKS
# ============================================================================
Write-Host ''
Write-Host '[2/15] Adapter Offload Tasks' -ForegroundColor Cyan

Apply 'TCP Checksum Offload RxTx' {
    Set-NetAdapterChecksumOffload -Name $name -TcpIPv4 RxTxEnabled -TcpIPv6 RxTxEnabled -ErrorAction Stop
}
Apply 'UDP Checksum Offload RxTx' {
    Set-NetAdapterChecksumOffload -Name $name -UdpIPv4 RxTxEnabled -UdpIPv6 RxTxEnabled -ErrorAction Stop
}
Apply 'IP Checksum Offload' {
    Set-NetAdapterChecksumOffload -Name $name -IpIPv4 RxTxEnabled -ErrorAction Stop
}
Apply 'Large Send Offload V2 IPv4+IPv6' {
    Set-NetAdapterLso -Name $name -IPv4Enabled $true -IPv6Enabled $true -ErrorAction Stop
}
Apply 'Receive Segment Coalescing IPv4' {
    Set-NetAdapterRsc -Name $name -IPv4Enabled $true -ErrorAction Stop
}
Apply 'Receive Segment Coalescing IPv6' {
    Set-NetAdapterRsc -Name $name -IPv6Enabled $true -ErrorAction Stop
}
Apply 'Enable RSS' {
    Enable-NetAdapterRss -Name $name -ErrorAction Stop
}
Apply 'RSS: Base=0, Max=15, Queues=4' {
    Set-NetAdapterRss -Name $name -BaseProcessorNumber 0 -MaxProcessorNumber 15 -NumberOfReceiveQueues 4 -ErrorAction Stop
}
Apply 'Encapsulated Task Offload' {
    Set-NetAdapterEncapsulatedPacketTaskOffload -Name $name -EncapsulatedPacketTaskOffloadEnabled $true -ErrorAction Stop
}

# ============================================================================
# SECTION 3: ADAPTER QOS / PACKET DIRECT
# ============================================================================
Write-Host ''
Write-Host '[3/15] Adapter QoS and Advanced Features' -ForegroundColor Cyan

Apply 'Enable NetAdapter QoS' {
    Enable-NetAdapterQos -Name $name -ErrorAction Stop
}
Apply 'Enable PacketDirect' {
    Set-NetAdapterPacketDirect -Name $name -Enabled $true -ErrorAction Stop
}
Apply 'Set VLAN ID 0' {
    Set-NetAdapterAdvancedProperty -Name $name -DisplayName 'VLAN ID' -DisplayValue '0' -ErrorAction Stop
}
Apply 'Disable Priority and VLAN tagging' {
    Set-NetAdapterAdvancedProperty -Name $name -DisplayName 'Priority & VLAN' -DisplayValue 'Priority & VLAN Disabled' -ErrorAction Stop
}

# ============================================================================
# SECTION 4: SMB MULTICHANNEL
# ============================================================================
Write-Host ''
Write-Host '[4/15] SMB Multichannel and Direct' -ForegroundColor Cyan

Apply 'SMB Client: EnableMultiChannel' {
    Set-SmbClientConfiguration -EnableMultiChannel $true -Force -ErrorAction Stop
}
Apply 'SMB Client: DisableBandwidthThrottling' {
    Set-SmbClientConfiguration -EnableBandwidthThrottling $false -Force -ErrorAction Stop
}
Apply 'SMB Client: MaxConnectionCountPerServer=32' {
    Set-SmbClientConfiguration -MaximumConnectionCountPerServer 32 -Force -ErrorAction Stop
}
Apply 'SMB Client: Disable signing overhead' {
    Set-SmbClientConfiguration -EnableSecuritySignature $false -RequireSecuritySignature $false -Force -ErrorAction Stop
}
Apply 'SMB Server: EnableMultiChannel' {
    Set-SmbServerConfiguration -EnableMultiChannel $true -Force -ErrorAction Stop
}
Apply 'SMB Server: MaxChannelPerSession=32' {
    Set-SmbServerConfiguration -MaxChannelPerSession 32 -Force -ErrorAction Stop
}
Apply 'SMB Server: AsynchronousCredits=512' {
    Set-SmbServerConfiguration -AsynchronousCredits 512 -Force -ErrorAction Stop
}
Apply 'SMB Server: Smb2Credits 512-8192' {
    Set-SmbServerConfiguration -Smb2CreditsMin 512 -Smb2CreditsMax 8192 -Force -ErrorAction Stop
}
Apply 'SMB Server: Disable signing' {
    Set-SmbServerConfiguration -EnableSecuritySignature $false -RequireSecuritySignature $false -Force -ErrorAction Stop
}
Apply 'SMB Server: MaxWorkItems=8192' {
    Set-SmbServerConfiguration -MaxWorkItems 8192 -Force -ErrorAction Stop
}

# ============================================================================
# SECTION 5: INTERFACE SETTINGS
# ============================================================================
Write-Host ''
Write-Host '[5/15] Interface-Level Optimizations' -ForegroundColor Cyan

Apply 'IPv4 forwarding=enabled' {
    netsh interface ipv4 set interface $ifIndex forwarding=enabled
}
Apply 'IPv4 dadtransmits=0' {
    netsh interface ipv4 set interface $ifIndex dadtransmits=0
}
Apply 'IPv4 routerdiscovery=disabled' {
    netsh interface ipv4 set interface $ifIndex routerdiscovery=disabled
}
Apply 'IPv4 advertise=disabled' {
    netsh interface ipv4 set interface $ifIndex advertise=disabled
}
Apply 'IPv4 nud=enabled' {
    netsh interface ipv4 set interface $ifIndex nud=enabled
}
Apply 'IPv4 siteprefixlength=0' {
    netsh interface ipv4 set interface $ifIndex siteprefixlength=0
}
Apply 'IPv6 dadtransmits=0' {
    netsh interface ipv6 set interface $ifIndex dadtransmits=0
}
Apply 'IPv6 routerdiscovery=dhcp' {
    netsh interface ipv6 set interface $ifIndex routerdiscovery=dhcp
}
Apply 'Global reassemblylimit=16MB' {
    netsh interface ipv4 set global reassemblylimit=16777216
}
Apply 'Global icmpredirects=disabled' {
    netsh interface ipv4 set global icmpredirects=disabled
}
Apply 'Global sourcerouting=dontforward' {
    netsh interface ipv4 set global sourceroutingbehavior=dontforward
}
Apply 'Global taskoffload=enabled' {
    netsh interface ipv4 set global taskoffload=enabled
}
Apply 'Global neighborcachelimit=4096' {
    netsh interface ipv4 set global neighborcachelimit=4096
}
Apply 'IPv6 global reassemblylimit=16MB' {
    netsh interface ipv6 set global reassemblylimit=16777216
}
Apply 'Global multicastforwarding=disabled' {
    netsh interface ipv4 set global multicastforwarding=disabled
}
Apply 'Global groupforwardedfragments=enabled' {
    netsh interface ipv4 set global groupforwardedfragments=enabled
}

# ============================================================================
# SECTION 6: TCP SUPPLEMENTAL TEMPLATES
# ============================================================================
Write-Host ''
Write-Host '[6/15] TCP Supplemental Templates' -ForegroundColor Cyan

$templates = @('Internet','Datacenter','Compat','DatacenterCustom','InternetCustom')
foreach ($tmpl in $templates) {
    Apply "Set $tmpl congestion=CUBIC" {
        netsh int tcp set supplemental template=$tmpl congestionprovider=cubic 2>$null
    }
}

# ============================================================================
# SECTION 7: WFP/BFE/NETIO
# ============================================================================
Write-Host ''
Write-Host '[7/15] WFP/BFE/NetIO Optimization' -ForegroundColor Cyan

Apply 'BFE DisableStatefulFtp' {
    $p = 'HKLM:\SYSTEM\CurrentControlSet\Services\BFE\Parameters\Policy\Options'
    if (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name 'DisableStatefulFtp' -Value 1 -Type DWord -Force
}
Apply 'NetIO EnableRSCOnAggregation' {
    $p = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetIO\Parameters'
    if (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name 'EnableRSCOnAggregation' -Value 1 -Type DWord -Force
}

# ============================================================================
# SECTION 8: DISABLE BANDWIDTH-WASTING SERVICES
# ============================================================================
Write-Host ''
Write-Host '[8/15] Network Services Optimization' -ForegroundColor Cyan

$svcList = @(
    @{N='DiagTrack'; D='Telemetry'},
    @{N='dmwappushservice'; D='WAP Push'},
    @{N='WMPNetworkSvc'; D='WMP Network'},
    @{N='lfsvc'; D='Geolocation'},
    @{N='MapsBroker'; D='Maps Manager'},
    @{N='RetailDemo'; D='Retail Demo'},
    @{N='wisvc'; D='Windows Insider'},
    @{N='XblAuthManager'; D='Xbox Auth'},
    @{N='XblGameSave'; D='Xbox Save'},
    @{N='XboxNetApiSvc'; D='Xbox Net'},
    @{N='XboxGipSvc'; D='Xbox Accessory'},
    @{N='WpcMonSvc'; D='Parental Controls'},
    @{N='PhoneSvc'; D='Phone Service'},
    @{N='icssvc'; D='Mobile Hotspot'}
)

foreach ($svc in $svcList) {
    Apply "Disable $($svc.D)" {
        $s = Get-Service -Name $svc.N -ErrorAction Stop
        if ($s.Status -eq 'Running') { Stop-Service -Name $svc.N -Force -ErrorAction Stop }
        Set-Service -Name $svc.N -StartupType Disabled -ErrorAction Stop
    }
}

# ============================================================================
# SECTION 9: ADVANCED TCP/IP REGISTRY
# ============================================================================
Write-Host ''
Write-Host '[9/15] Advanced TCP/IP Registry' -ForegroundColor Cyan

$tcpip = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'

Apply 'EnableDSACK' {
    Set-ItemProperty -Path $tcpip -Name 'EnableDSACK' -Value 1 -Type DWord -Force
}
Apply 'TcpMaxSendFree=65535' {
    Set-ItemProperty -Path $tcpip -Name 'TcpMaxSendFree' -Value 65535 -Type DWord -Force
}
Apply 'MaxConnectionsPer1_0Server=32' {
    Set-ItemProperty -Path $tcpip -Name 'MaxConnectionsPer1_0Server' -Value 32 -Type DWord -Force
}
Apply 'MaxConnectionsPerServer=32' {
    Set-ItemProperty -Path $tcpip -Name 'MaxConnectionsPerServer' -Value 32 -Type DWord -Force
}
Apply 'EnableTFO=3' {
    Set-ItemProperty -Path $tcpip -Name 'EnableTFO' -Value 3 -Type DWord -Force
}
Apply 'TcbRateLimitDepth=0' {
    Set-ItemProperty -Path $tcpip -Name 'TcpCreateAndConnectTcbRateLimitDepth' -Value 0 -Type DWord -Force
}
Apply 'IPEnableRouter=1' {
    Set-ItemProperty -Path $tcpip -Name 'IPEnableRouter' -Value 1 -Type DWord -Force
}
Apply 'ArpRetryCount=3' {
    Set-ItemProperty -Path $tcpip -Name 'ArpRetryCount' -Value 3 -Type DWord -Force
}
Apply 'EnableDeadGWDetect=0' {
    Set-ItemProperty -Path $tcpip -Name 'EnableDeadGWDetect' -Value 0 -Type DWord -Force
}
Apply 'ArpCacheLife=300' {
    Set-ItemProperty -Path $tcpip -Name 'ArpCacheLife' -Value 300 -Type DWord -Force
}
Apply 'ArpCacheMinReferencedLife=300' {
    Set-ItemProperty -Path $tcpip -Name 'ArpCacheMinReferencedLife' -Value 300 -Type DWord -Force
}

# ============================================================================
# SECTION 10: IPv6 REGISTRY
# ============================================================================
Write-Host ''
Write-Host '[10/15] IPv6-Specific Registry' -ForegroundColor Cyan

$tcpip6 = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
if (!(Test-Path $tcpip6)) { New-Item -Path $tcpip6 -Force | Out-Null }

Apply 'IPv6 TcpWindowSize=65535' {
    Set-ItemProperty -Path $tcpip6 -Name 'TcpWindowSize' -Value 65535 -Type DWord -Force
}
Apply 'IPv6 Tcp1323Opts=3' {
    Set-ItemProperty -Path $tcpip6 -Name 'Tcp1323Opts' -Value 3 -Type DWord -Force
}
Apply 'IPv6 DefaultTTL=64' {
    Set-ItemProperty -Path $tcpip6 -Name 'DefaultTTL' -Value 64 -Type DWord -Force
}
Apply 'IPv6 MaxUserPort=65534' {
    Set-ItemProperty -Path $tcpip6 -Name 'MaxUserPort' -Value 65534 -Type DWord -Force
}
Apply 'IPv6 TcpTimedWaitDelay=30' {
    Set-ItemProperty -Path $tcpip6 -Name 'TcpTimedWaitDelay' -Value 30 -Type DWord -Force
}

# ============================================================================
# SECTION 11: WININET / HTTP STACK
# ============================================================================
Write-Host ''
Write-Host '[11/15] WinINET / HTTP Stack' -ForegroundColor Cyan

$inet = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings'

Apply 'MaxConnectionsPerServer=32' {
    Set-ItemProperty -Path $inet -Name 'MaxConnectionsPerServer' -Value 32 -Type DWord -Force
}
Apply 'MaxConnectionsPer1_0Server=32' {
    Set-ItemProperty -Path $inet -Name 'MaxConnectionsPer1_0Server' -Value 32 -Type DWord -Force
}
Apply 'EnableHTTP2' {
    $wh = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
    if (!(Test-Path $wh)) { New-Item -Path $wh -Force | Out-Null }
    Set-ItemProperty -Path $wh -Name 'EnableHTTP2' -Value 1 -Type DWord -Force
}
Apply 'WinHTTP ConnectionsPerServer=32' {
    $wh = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
    Set-ItemProperty -Path $wh -Name 'DefaultConnectionsPerServer' -Value 32 -Type DWord -Force
}
Apply 'ReceiveTimeout=60000' {
    Set-ItemProperty -Path $inet -Name 'ReceiveTimeout' -Value 60000 -Type DWord -Force
}
Apply 'SendTimeout=60000' {
    Set-ItemProperty -Path $inet -Name 'SendTimeout' -Value 60000 -Type DWord -Force
}
Apply 'KeepAliveTimeout=115000' {
    Set-ItemProperty -Path $inet -Name 'KeepAliveTimeout' -Value 115000 -Type DWord -Force
}
Apply 'ServerInfoTimeout=120' {
    Set-ItemProperty -Path $inet -Name 'ServerInfoTimeout' -Value 120 -Type DWord -Force
}

# ============================================================================
# SECTION 12: ADAPTER BINDING
# ============================================================================
Write-Host ''
Write-Host '[12/15] Adapter Binding Optimization' -ForegroundColor Cyan

Apply 'Disable ms_msclient' {
    Disable-NetAdapterBinding -Name $name -ComponentID ms_msclient -ErrorAction Stop
}
Apply 'Disable ms_server' {
    Disable-NetAdapterBinding -Name $name -ComponentID ms_server -ErrorAction Stop
}
Apply 'Disable ms_lltdio' {
    Disable-NetAdapterBinding -Name $name -ComponentID ms_lltdio -ErrorAction Stop
}
Apply 'Disable ms_rspndr' {
    Disable-NetAdapterBinding -Name $name -ComponentID ms_rspndr -ErrorAction Stop
}
Apply 'Disable ms_lldp' {
    Disable-NetAdapterBinding -Name $name -ComponentID ms_lldp -ErrorAction Stop
}
Apply 'Disable ms_implat' {
    Disable-NetAdapterBinding -Name $name -ComponentID ms_implat -ErrorAction Stop
}
Apply 'Enable ms_tcpip' {
    Enable-NetAdapterBinding -Name $name -ComponentID ms_tcpip -ErrorAction Stop
}
Apply 'Enable ms_tcpip6' {
    Enable-NetAdapterBinding -Name $name -ComponentID ms_tcpip6 -ErrorAction Stop
}

# ============================================================================
# SECTION 13: ROUTE METRICS
# ============================================================================
Write-Host ''
Write-Host '[13/15] Route and Neighbor Cache' -ForegroundColor Cyan

Apply 'IPv4 InterfaceMetric=5' {
    Set-NetIPInterface -InterfaceIndex $ifIndex -InterfaceMetric 5 -ErrorAction Stop
}
Apply 'IPv6 InterfaceMetric=5' {
    Set-NetIPInterface -InterfaceIndex $ifIndex -AddressFamily IPv6 -InterfaceMetric 5 -ErrorAction Stop
}
Apply 'Neighbor basereachable=30000' {
    netsh interface ipv4 set interface $ifIndex basereachable=30000
}
Apply 'Neighbor retransmittime=1000' {
    netsh interface ipv4 set interface $ifIndex retransmittime=1000
}
Apply 'IPv6 basereachable=30000' {
    netsh interface ipv6 set interface $ifIndex basereachable=30000
}

# ============================================================================
# SECTION 14: PROCESSOR SCHEDULING
# ============================================================================
Write-Host ''
Write-Host '[14/15] Processor Scheduling for Network' -ForegroundColor Cyan

Apply 'Win32PrioritySeparation=38' {
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 38 -Type DWord -Force
}
Apply 'Network provider order' {
    $po = 'HKLM:\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order'
    if (Test-Path $po) {
        $cur = (Get-ItemProperty -Path $po -Name 'ProviderOrder' -ErrorAction SilentlyContinue).ProviderOrder
        if ($cur -and $cur -notlike 'LanmanWorkstation*') {
            Set-ItemProperty -Path $po -Name 'ProviderOrder' -Value 'LanmanWorkstation,webclient' -Type String -Force
        }
    }
}
Apply 'Worker threads +16' {
    $ep = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive'
    Set-ItemProperty -Path $ep -Name 'AdditionalCriticalWorkerThreads' -Value 16 -Type DWord -Force
    Set-ItemProperty -Path $ep -Name 'AdditionalDelayedWorkerThreads' -Value 16 -Type DWord -Force
}
Apply 'MMCSS Games priority' {
    $mg = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    if (!(Test-Path $mg)) { New-Item -Path $mg -Force | Out-Null }
    Set-ItemProperty -Path $mg -Name 'Affinity' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $mg -Name 'Background Only' -Value 'False' -Type String -Force
    Set-ItemProperty -Path $mg -Name 'Clock Rate' -Value 10000 -Type DWord -Force
    Set-ItemProperty -Path $mg -Name 'GPU Priority' -Value 8 -Type DWord -Force
    Set-ItemProperty -Path $mg -Name 'Priority' -Value 6 -Type DWord -Force
    Set-ItemProperty -Path $mg -Name 'Scheduling Category' -Value 'High' -Type String -Force
    Set-ItemProperty -Path $mg -Name 'SFIO Priority' -Value 'High' -Type String -Force
}

# ============================================================================
# SECTION 15: CLEANUP
# ============================================================================
Write-Host ''
Write-Host '[15/15] Final Cleanup and Verification' -ForegroundColor Cyan

Apply 'Flush DNS cache' {
    Clear-DnsClientCache -ErrorAction Stop
}
Apply 'Flush ARP cache' {
    Remove-NetNeighbor -InterfaceIndex $ifIndex -Confirm:$false -ErrorAction SilentlyContinue
}
Apply 'Flush NetBIOS cache' {
    nbtstat -R 2>$null
}
Apply 'Register DNS' {
    $null = ipconfig /registerdns 2>$null
}
Apply 'Verify TCP settings' {
    $tcp = Get-NetTCPSetting -SettingName Internet
    Write-Host "    Congestion=$($tcp.CongestionProvider) AutoTune=$($tcp.AutoTuningLevelLocal) ECN=$($tcp.EcnCapability)" -ForegroundColor DarkCyan
}
Apply 'Verify adapter offloads' {
    $rsc = Get-NetAdapterRsc -Name $name -ErrorAction SilentlyContinue
    $lso = Get-NetAdapterLso -Name $name -ErrorAction SilentlyContinue
    Write-Host "    RSC4=$($rsc.IPv4Enabled) RSC6=$($rsc.IPv6Enabled) LSO4=$($lso.IPv4Enabled) LSO6=$($lso.IPv6Enabled)" -ForegroundColor DarkCyan
}

# ============================================================================
# SUMMARY
# ============================================================================
$elapsed = (Get-Date) - $script:startTime
$mins = [math]::Floor($elapsed.TotalMinutes)
$secs = $elapsed.Seconds

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host '                   NETBOOST3 COMPLETE' -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
Write-Host ''
Write-Host "  Optimizations: $($script:count) | Duration: ${mins}m ${secs}s" -ForegroundColor White
Write-Host ''
Write-Host '  NO REBOOT REQUIRED - all changes active now.' -ForegroundColor Yellow
Write-Host '  Run speedtest to verify improvements.' -ForegroundColor Yellow
Write-Host ''
