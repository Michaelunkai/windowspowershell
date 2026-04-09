# Disable "Managed by your organization" - Permanent Fix
# Run as Administrator

Write-Host "Disabling 'Managed by your organization' settings..." -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

# Registry paths for organization management
$registryPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings",
    "HKLM:\SOFTWARE\Policies\Microsoft\Edge",
    "HKLM:\SOFTWARE\Policies\Google\Chrome",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System",
    "HKLM:\SOFTWARE\Microsoft\Policies\PassportForWork",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\Managed",
    "HKLM:\SOFTWARE\Microsoft\Enrollments",
    "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager"
)

# Disable Cloud Content
$cloudContentPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
if (-not (Test-Path $cloudContentPath)) {
    New-Item -Path $cloudContentPath -Force | Out-Null
}
Set-ItemProperty -Path $cloudContentPath -Name "DisableWindowsConsumerFeatures" -Value 0 -Type DWord -ErrorAction SilentlyContinue

# Remove organization management keys
foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Write-Host "Removing: $path" -ForegroundColor Yellow
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Disable MDM Enrollment
$enrollPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
if (Test-Path $enrollPath) {
    Get-ChildItem -Path $enrollPath | ForEach-Object {
        Write-Host "Removing enrollment: $($_.Name)" -ForegroundColor Yellow
        Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clear Enterprise Management
$entMgmtPath = "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager"
if (Test-Path $entMgmtPath) {
    Write-Host "Clearing Enterprise Resource Manager..." -ForegroundColor Yellow
    Remove-Item -Path $entMgmtPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove Work or School Account Policies
$accountPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device"
if (Test-Path $accountPath) {
    Write-Host "Removing device policies..." -ForegroundColor Yellow
    Remove-Item -Path $accountPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Disable MDM via Task Scheduler
Write-Host "Disabling MDM-related scheduled tasks..." -ForegroundColor Yellow
$mdmTasks = @(
    "\Microsoft\Windows\EnterpriseMgmt\*",
    "\Microsoft\Windows\Workplace Join\*"
)

foreach ($taskPattern in $mdmTasks) {
    try {
        Get-ScheduledTask -TaskPath $taskPattern -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue
    } catch {
        # Task may not exist, continue
    }
}

# Remove EdgeUpdate policies
$edgeUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
if (Test-Path $edgeUpdatePath) {
    Write-Host "Removing Edge Update policies..." -ForegroundColor Yellow
    Remove-Item -Path $edgeUpdatePath -Recurse -Force -ErrorAction SilentlyContinue
}

# Clear Chrome enterprise policies
$chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
if (Test-Path $chromePolicyPath) {
    Write-Host "Removing Chrome enterprise policies..." -ForegroundColor Yellow
    Remove-Item -Path $chromePolicyPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Reset Location Services management
$locationPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
if (Test-Path $locationPath) {
    Write-Host "Removing Location Services policies..." -ForegroundColor Yellow
    Remove-Item -Path $locationPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Enable user control of Location Services
$locationUserPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
if (-not (Test-Path $locationUserPath)) {
    New-Item -Path $locationUserPath -Force | Out-Null
}
Set-ItemProperty -Path $locationUserPath -Name "Value" -Value "Allow" -Type String -ErrorAction SilentlyContinue

# Clear Group Policy cache
Write-Host "Clearing Group Policy cache..." -ForegroundColor Yellow
Remove-Item -Path "$env:SystemRoot\System32\GroupPolicy\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemRoot\System32\GroupPolicyUsers\*" -Recurse -Force -ErrorAction SilentlyContinue

# Force Group Policy update
Write-Host "Forcing Group Policy update..." -ForegroundColor Yellow
gpupdate /force | Out-Null

# Restart required services
Write-Host "Restarting relevant services..." -ForegroundColor Yellow
$services = @("gpsvc", "PolicyAgent", "DmEnrollmentSvc", "DmWappushService")
foreach ($svc in $services) {
    try {
        $serviceObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($serviceObj) {
            Write-Host "  Restarting $svc..." -ForegroundColor Gray
            Restart-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
    } catch {
        # Service may not be running
    }
}

# Kill and restart Explorer to refresh Settings UI
Write-Host "Restarting Windows Explorer to refresh UI..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe

# Kill Settings app if running to force refresh
Write-Host "Closing Settings app to force refresh..." -ForegroundColor Yellow
Get-Process -Name SystemSettings -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Refresh system tray and taskbar
Write-Host "Refreshing system components..." -ForegroundColor Yellow
$code = @'
[DllImport("user32.dll", SetLastError = true)]
public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

[DllImport("user32.dll", SetLastError = true)]
public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
'@

try {
    Add-Type -MemberDefinition $code -Name WinAPI -Namespace Win32 -ErrorAction SilentlyContinue
    $hwnd = [Win32.WinAPI]::FindWindow("Shell_TrayWnd", $null)
    [Win32.WinAPI]::PostMessage($hwnd, 0x0112, 0xF5B0, 0) | Out-Null
} catch {
    # Refresh failed, not critical
}

# Force refresh of location services permissions
Write-Host "Refreshing location services..." -ForegroundColor Yellow
Stop-Service -Name "lfsvc" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue

# Clear any cached credentials
Write-Host "Clearing credential cache..." -ForegroundColor Yellow
cmdkey /list | Select-String "Target:" | ForEach-Object {
    $target = $_.Line.Replace("Target: ", "").Trim()
    if ($target -like "*organization*" -or $target -like "*work*" -or $target -like "*AAD*") {
        cmdkey /delete:$target 2>$null
    }
}

# Force notification of policy changes without reboot
Write-Host "Broadcasting policy change notification..." -ForegroundColor Yellow
$signature = @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, IntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
'@

try {
    Add-Type -MemberDefinition $signature -Name PolicyNotify -Namespace Win32 -ErrorAction SilentlyContinue
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x1a
    $result = [IntPtr]::Zero
    [Win32.PolicyNotify]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [IntPtr]::Zero, "Policy", 2, 5000, [ref]$result) | Out-Null
} catch {
    # Notification failed, not critical
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "COMPLETED: Organization management disabled!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nChanges applied IMMEDIATELY - No reboot required!" -ForegroundColor Cyan
Write-Host "Location services and other settings are now under your control." -ForegroundColor Cyan
Write-Host "`nOpen Settings > Privacy & security > Location to verify." -ForegroundColor Yellow
Write-Host "`nNote: If message persists, close and reopen Settings app." -ForegroundColor Gray

pause
