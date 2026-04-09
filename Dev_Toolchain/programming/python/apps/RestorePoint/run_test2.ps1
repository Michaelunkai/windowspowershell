# Simple test script
$ErrorActionPreference = "Stop"

# Check if admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "Not admin - elevating..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $MyInvocation.MyCommand.Path -Wait
    exit
}

Write-Host "Running as Admin"

try {
    # First, let's count current restore points
    $count = (Get-WmiObject -Namespace "root\default" -Class SystemRestore -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "Current restore points: $count"
    
    # Try to create a restore point using WMI
    Write-Host "Creating restore point..."
    $sr = [wmiclass]"\\localhost\root\default:SystemRestore"
    $result = $sr.CreateRestorePoint("Test_$(Get-Date -Format 'yyyyMMdd_HHmmss')", 12, 100)
    
    if ($result.ReturnValue -eq 0) {
        Write-Host "SUCCESS! Return value: $($result.ReturnValue)"
    } else {
        Write-Host "FAILED! Return value: $($result.ReturnValue)"
    }
    
    # Count again
    $count2 = (Get-WmiObject -Namespace "root\default" -Class SystemRestore -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "Restore points after: $count2"
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
