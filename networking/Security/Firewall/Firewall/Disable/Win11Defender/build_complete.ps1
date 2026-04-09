# Build complete disable.ps1 with proper encoding
$content = [System.IO.File]::ReadAllText('F:\study\security_networking\security\firewall\Disable\Win11Defender\disable0.ps1', [System.Text.Encoding]::UTF8)

# Update step counters
$content = $content -replace '\[0/16\]', '[0/20]'
$content = $content -replace '\[1/16\]', '[1/20]'
$content = $content -replace '\[2/16\]', '[2/20]'
$content = $content -replace '\[3/16\]', '[3/20]'
$content = $content -replace '\[4/16\]', '[4/20]'
$content = $content -replace '\[5/16\]', '[5/20]'
$content = $content -replace '\[6/16\]', '[6/20]'
$content = $content -replace '\[7/16\]', '[7/20]'
$content = $content -replace '\[8/16\]', '[8/20]'
$content = $content -replace '\[9/16\]', '[9/20]'
$content = $content -replace '\[10/16\]', '[10/20]'
$content = $content -replace '\[11/16\]', '[11/20]'
$content = $content -replace '\[12/16\]', '[12/20]'
$content = $content -replace '\[13/16\]', '[13/20]'
$content = $content -replace '\[14/16\]', '[14/20]'
$content = $content -replace '\[15/16\]', '[15/20]'
$content = $content -replace '\[16/16\]', '[16/20]'

# Fix problematic text
$content = $content -replace 'file & printer', 'file and printer'
$content = $content -replace 'network protection & filtering', 'network protection and filtering'
$content = $content -replace '10000%', '10000 percent'
$content = $content -replace 'C:\\2aa\.ps1', 'the enable.ps1 script'

# Add new sections before the final summary
$newSections = @'

# ====================
# 17. DISABLE ALL NETWORK BLOCKING AND RESTRICTIONS
# ====================
Write-Host "[17/20] Disabling ALL network blocking mechanisms..." -ForegroundColor Yellow

# Disable network-level authentication
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "LmCompatibilityLevel" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "NoLmHash" /t REG_DWORD /d 0 /f 2>&1

# Disable SMB signing requirements
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "RequireSecuritySignature" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v "RequireSecuritySignature" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "EnableSecuritySignature" /t REG_DWORD /d 0 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v "EnableSecuritySignature" /t REG_DWORD /d 0 /f 2>&1

# Disable all firewall rules
netsh advfirewall firewall set rule all new enable=no 2>&1 | Out-Null

# Allow all inbound connections
netsh advfirewall set allprofiles blockedinbound off 2>&1 | Out-Null
netsh advfirewall set allprofiles blockedoutbound off 2>&1 | Out-Null

# Disable all port blocking
netsh interface ipv4 set global defaultcurhoplimit=255 2>&1 | Out-Null
netsh interface ipv6 set global defaultcurhoplimit=255 2>&1 | Out-Null

# Remove all firewall port blocks
netsh advfirewall firewall delete rule name=all 2>&1 | Out-Null

Write-Host "  * All network blocking obliterated" -ForegroundColor Green

# ====================
# 18. DISABLE WINDOWS UPDATE INTERFERENCE
# ====================
Write-Host "[18/20] Disabling Windows Update interference..." -ForegroundColor Yellow

Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
Set-Service -Name "wuauserv" -StartupType Disabled -ErrorAction SilentlyContinue
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "NoAutoUpdate" /t REG_DWORD /d 1 /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "AUOptions" /t REG_DWORD /d 1 /f 2>&1

Write-Host "  * Windows Update disabled" -ForegroundColor Green

# ====================
# 19. DISABLE NETWORK PROTECTION AND FILTERING
# ====================
Write-Host "[19/20] Disabling network protection and filtering..." -ForegroundColor Yellow

# Disable all attack surface reduction rules
$asrIds = @(
    "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550",
    "D4F940AB-401B-4EFC-AADC-AD5F3C50688A",
    "3B576869-A4EC-4529-8536-B80A7769E899",
    "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84",
    "D3E037E1-3EB8-44C8-A917-57927947596D",
    "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC",
    "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B",
    "01443614-CD74-433A-B99E-2ECDC07BFC25",
    "C1DB55AB-C21A-4637-BB3F-A12568109D35",
    "9E6C4E1F-7D60-472F-BA1A-A39EF669E4B2",
    "D1E49AAC-8F56-4280-B9BA-993A6D77406C",
    "B2B3F03D-6A65-4F7B-A9C7-1C7EF74A9BA4",
    "26190899-1602-49E8-8B27-EB1D0A1CE869",
    "7674BA52-37EB-4A4F-A9A1-F0F9A1619A2C",
    "E6DB77E5-3DF2-4CF1-B95A-636979351E5B"
)

foreach ($id in $asrIds) {
    $null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\Rules" /v $id /t REG_DWORD /d 0 /f 2>&1
}

# Disable controlled folder access
$null = reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access" /v "EnableControlledFolderAccess" /t REG_DWORD /d 0 /f 2>&1

# Disable Network Inspection System
Stop-Service -Name "WdNisSvc" -Force -ErrorAction SilentlyContinue
Set-Service -Name "WdNisSvc" -StartupType Disabled -ErrorAction SilentlyContinue

Write-Host "  * Network protection obliterated" -ForegroundColor Green

# ====================
# 20. ENABLE FILE AND PRINTER SHARING - NO RESTRICTIONS
# ====================
Write-Host "[20/20] Enabling unrestricted file and printer sharing..." -ForegroundColor Yellow

# Enable network discovery
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" /f 2>&1
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes 2>&1 | Out-Null
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes 2>&1 | Out-Null

# Enable anonymous access to shares
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "NullSessionShares" /t REG_MULTI_SZ /d "C$\0D$\0ADMIN$\0IPC$" /f 2>&1
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "RestrictNullSessAccess" /t REG_DWORD /d 0 /f 2>&1

# Disable password-protected sharing
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "ForceGuest" /t REG_DWORD /d 1 /f 2>&1

# Enable SMBv1 for maximum compatibility
Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
$null = reg.exe add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "SMB1" /t REG_DWORD /d 1 /f 2>&1

Write-Host "  * File sharing fully enabled - no restrictions" -ForegroundColor Green
'@

# Insert new sections before the final summary
$insertPoint = $content.IndexOf('Write-Host "" -ForegroundColor Green')
if ($insertPoint -gt 0) {
    $before = $content.Substring(0, $insertPoint)
    $after = $content.Substring($insertPoint)
    $content = $before + $newSections + "`n" + $after
}

# Update the summary section
$content = $content -replace '  ✓ File System Protection \(OBLITERATED\)" -ForegroundColor White', '  * File System Protection (OBLITERATED)" -ForegroundColor White
Write-Host "  * All Network Blocking (OBLITERATED)" -ForegroundColor White
Write-Host "  * Network Protection (OFF)" -ForegroundColor White
Write-Host "  * Attack Surface Reduction (OFF)" -ForegroundColor White
Write-Host "  * File Sharing (FULLY ENABLED)" -ForegroundColor White
Write-Host "  * Windows Update (DISABLED)" -ForegroundColor White'

# Write the final file with UTF-8 encoding
[System.IO.File]::WriteAllText('F:\study\security_networking\security\firewall\Disable\Win11Defender\disable.ps1', $content, [System.Text.Encoding]::UTF8)

Write-Host "Script built successfully!" -ForegroundColor Green
