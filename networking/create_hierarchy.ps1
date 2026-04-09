# Create organized networking hierarchy

$base = 'F:\study\networking'
$dirs = @(
    'Cisco',
    'Cisco\GNS3',
    'Cisco\Packet_Tracer',
    'Cisco\AnyConnect_VPN',
    'Cisco\CDPR',
    'Cisco\VPNC',
    'Security',
    'Security\Hacking',
    'Security\Hacking\BruteForce',
    'Security\Hacking\Botnet',
    'Security\Hacking\DDoS-DoS',
    'Security\Firewall',
    'Protocols',
    'Protocols\SSH',
    'Protocols\SSL_TLS',
    'Protocols\TCP_IP',
    'Protocols\DNS',
    'Protocols\DHCP',
    'Cloud_Networking',
    'Cloud_Networking\AWS',
    'Cloud_Networking\Azure',
    'Cloud_Networking\GCP',
    'Cloud_Networking\Cloudflare',
    'Cloud_Networking\Other',
    'VPN',
    'Remote_Access',
    'Network_Tools',
    'Documentation'
)

foreach ($dir in $dirs) {
    $fullPath = Join-Path $base $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Output "Created: $dir"
    }
}
Write-Output 'Hierarchy creation complete!'
