# Docker VHDX Purge Script - PowerShell Wrapper
# Automatically elevates to admin and runs the Python script

$pythonScript = Join-Path $PSScriptRoot "a.py"

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[ELEVATE] Requesting administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot'; python '$pythonScript'"
    exit
}

# Run the Python script
Write-Host "[ADMIN] Running with administrator privileges" -ForegroundColor Green
python $pythonScript
