# Install Windows Defender Quick Scan as automatic scheduled task
# Runs every night at 2 AM, auto-removes threats
# Set it and forget it

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Must run as Administrator" -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host "Installing automatic nightly scan..." -ForegroundColor Cyan

# Create scheduled task action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -Command `"Start-MpScan -ScanType QuickScan -AsJob | Wait-Job`""

# Create trigger: every night at 2 AM
$trigger = New-ScheduledTaskTrigger -Daily -At 2am

# Create task settings
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -RunOnlyIfIdle `
    -StopIfGoingOffEdges `
    -AllowStartIfOnBatteries:$false

# Register the task
$taskName = "Windows Defender Quick Scan Auto"
$taskPath = "\Microsoft\Windows\Windows Defender\"

try {
    # Remove old task if exists
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
    
    # Register new task
    Register-ScheduledTask `
        -TaskName $taskName `
        -TaskPath $taskPath `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -RunLevel Highest `
        -Description "Automatic Windows Defender Quick Scan (auto-removes threats)" | Out-Null
    
    Write-Host "✓ Task installed successfully" -ForegroundColor Green
    Write-Host "`nSchedule: Every night at 2:00 AM" -ForegroundColor Yellow
    Write-Host "Task will:" -ForegroundColor Yellow
    Write-Host "  1. Update signatures" -ForegroundColor Gray
    Write-Host "  2. Run Quick Scan" -ForegroundColor Gray
    Write-Host "  3. Auto-remove threats" -ForegroundColor Gray
    Write-Host "`nTo verify: Task Scheduler > Microsoft > Windows > Windows Defender" -ForegroundColor Cyan
    
} catch {
    Write-Host "ERROR: Failed to install task" -ForegroundColor Red
    Write-Host "$_" -ForegroundColor Red
}

Read-Host "`nPress Enter to close"
