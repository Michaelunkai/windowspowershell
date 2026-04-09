# Run restore point creation test
$ErrorActionPreference = "SilentlyContinue"

# Check if admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "Not admin - elevating..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $MyInvocation.MyCommand.Path -Wait
    exit
}

Write-Host "Running as Admin - Starting restore point creation..."

# Run the Python script
$output = py "F:\study\Dev_Toolchain\programming\python\apps\RestorePoint\fast_restore.py" --auto 2>&1

# Save output to file
$output | Out-File "F:\study\Dev_Toolchain\programming\python\apps\RestorePoint\test_output.txt" -Force

Write-Host "Done. Output saved to test_output.txt"
