# Elevated restore point test
$ErrorActionPreference = "Stop"

# Check if admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "Elevating to Administrator..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $MyInvocation.MyCommand.Path -Wait
    exit
}

Write-Host "=== Running as Administrator ===" -ForegroundColor Green
Write-Host ""

# Run Python script and capture output
$scriptPath = "F:\study\Dev_Toolchain\programming\python\apps\RestorePoint\fast_restore.py"
$outputFile = "F:\study\Dev_Toolchain\programming\python\apps\RestorePoint\output.txt"

Write-Host "Starting restore point creation..." -ForegroundColor Cyan
$startTime = Get-Date

$ErrorActionPreference = "Continue"

# Run the script (use full path to Python 3.12)
$pythonPath = "C:\Users\User\AppData\Local\Programs\Python\Python312\python.exe"
$stdoutFile = "F:\study\Dev_Toolchain\programming\python\apps\RestorePoint\stdout.txt"
$stderrFile = "F:\study\Dev_Toolchain\programming\python\apps\RestorePoint\stderr.txt"

$proc = Start-Process -FilePath $pythonPath -ArgumentList "`"$scriptPath`"", "--auto" -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile

$endTime = Get-Date
$elapsed = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host "=== STDOUT ===" -ForegroundColor Yellow
if (Test-Path $stdoutFile) { Get-Content $stdoutFile }

Write-Host ""
Write-Host "=== STDERR ===" -ForegroundColor Red
if (Test-Path $stderrFile) { Get-Content $stderrFile }

Write-Host ""
Write-Host "Exit code: $($proc.ExitCode)" -ForegroundColor Cyan
Write-Host "Total elapsed: $([math]::Round($elapsed, 1)) seconds" -ForegroundColor Cyan

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
