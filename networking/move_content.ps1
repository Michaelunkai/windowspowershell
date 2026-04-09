# Move networking content to organized hierarchy

$ErrorActionPreference = 'Continue'
$base = 'F:\study\networking'

Write-Output "===== Moving Cisco Content ====="

# Move Cisco subdirectories
$ciscoMappings = @{
    'GNS3' = 'Cisco\GNS3'
    'Packet_Tracer' = 'Cisco\Packet_Tracer'
    'Cisco_AnyConnect' = 'Cisco\AnyConnect_VPN'
    'Cdpr' = 'Cisco\CDPR'
    'Vpnc' = 'Cisco\VPNC'
}

foreach ($source in $ciscoMappings.Keys) {
    $srcPath = "F:\study\Security_Networking\Cisco\$source"
    $destPath = Join-Path $base $ciscoMappings[$source]
    if (Test-Path $srcPath) {
        Write-Output "Moving $source to $($ciscoMappings[$source])"
        Get-ChildItem -Path $srcPath -Recurse | Move-Item -Destination $destPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $srcPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Move Cisco root files
$ciscoRoot = "F:\study\Security_Networking\Cisco"
if (Test-Path $ciscoRoot) {
    Get-ChildItem -Path $ciscoRoot -File | ForEach-Object {
        Write-Output "Moving Cisco root file: $($_.Name)"
        Move-Item -Path $_.FullName -Destination "$base\Cisco\" -Force -ErrorAction SilentlyContinue
    }
}

Write-Output "`n===== Moving Security/Hacking Content ====="

# Move Hacking content
$hackingMappings = @{
    'BruteForce' = 'Security\Hacking\BruteForce'
    'botnet' = 'Security\Hacking\Botnet'
    'ddos-dos' = 'Security\Hacking\DDoS-DoS'
}

foreach ($source in $hackingMappings.Keys) {
    $srcPath = "F:\study\Security_Networking\Hacking\$source"
    $destPath = Join-Path $base $hackingMappings[$source]
    if (Test-Path $srcPath) {
        Write-Output "Moving Hacking\$source to $($hackingMappings[$source])"
        Get-ChildItem -Path $srcPath -Recurse | Move-Item -Destination $destPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $srcPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Move other hacking files
$hackingRoot = "F:\study\Security_Networking\Hacking"
if (Test-Path $hackingRoot) {
    Get-ChildItem -Path $hackingRoot -File | ForEach-Object {
        Write-Output "Moving Hacking root file: $($_.Name)"
        Move-Item -Path $_.FullName -Destination "$base\Security\Hacking\" -Force -ErrorAction SilentlyContinue
    }
}

Write-Output "`n===== Moving Security Content ====="

# Move security folder content
$securityRoot = "F:\study\Security_Networking\security"
if (Test-Path $securityRoot) {
    Get-ChildItem -Path $securityRoot -Recurse | ForEach-Object {
        Write-Output "Moving security item: $($_.Name)"
        if ($_.PSIsContainer) {
            $destPath = Join-Path "$base\Security\Firewall" $_.Name
            Move-Item -Path $_.FullName -Destination $destPath -Force -ErrorAction SilentlyContinue
        } else {
            Move-Item -Path $_.FullName -Destination "$base\Security\Firewall\" -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -Path $securityRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "`n===== Moving SSH Content ====="

# Move SSH folder
$sshRoot = "F:\study\ssh"
if (Test-Path $sshRoot) {
    Get-ChildItem -Path $sshRoot -Recurse | ForEach-Object {
        Write-Output "Moving SSH item: $($_.Name)"
        Move-Item -Path $_.FullName -Destination "$base\Protocols\SSH\" -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -Path $sshRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "`n===== Moving Cloud Networking Content ====="

# Move cloud networking-related folders
$cloudMappings = @{
    'aws' = 'Cloud_Networking\AWS'
    'azure' = 'Cloud_Networking\Azure'
    'GCP' = 'Cloud_Networking\GCP'
    'cloudflare' = 'Cloud_Networking\Cloudflare'
}

foreach ($source in $cloudMappings.Keys) {
    $srcPath = "F:\study\cloud\$source"
    $destPath = Join-Path $base $cloudMappings[$source]
    if (Test-Path $srcPath) {
        Write-Output "Moving cloud\$source to $($cloudMappings[$source])"
        Get-ChildItem -Path $srcPath -Recurse | Move-Item -Destination $destPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $srcPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Move VPS folder to Cloud_Networking\Other
$vpsPath = "F:\study\cloud\vps"
if (Test-Path $vpsPath) {
    Write-Output "Moving cloud\vps to Cloud_Networking\Other"
    New-Item -ItemType Directory -Path "$base\Cloud_Networking\Other\VPS" -Force | Out-Null
    Get-ChildItem -Path $vpsPath -Recurse | Move-Item -Destination "$base\Cloud_Networking\Other\VPS\" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $vpsPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "`n===== Cleanup Empty Directories ====="

# Remove empty Security_Networking directory structure
if (Test-Path "F:\study\Security_Networking") {
    $isEmpty = (Get-ChildItem -Path "F:\study\Security_Networking" -Recurse -File).Count -eq 0
    if ($isEmpty) {
        Remove-Item -Path "F:\study\Security_Networking" -Recurse -Force
        Write-Output "Removed empty Security_Networking directory"
    }
}

Write-Output "`nMove operation complete!"
