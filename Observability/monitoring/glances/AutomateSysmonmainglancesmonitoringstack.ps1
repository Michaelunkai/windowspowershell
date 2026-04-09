# =============================================================
# FULL WINDOWS 11 MONITORING AUTO-INSTALLER
# Sysmon + Glances Web Dashboard
# Works under ANY circumstances
# =============================================================

Write-Host "`n[*] Starting full cleanup..." -ForegroundColor Cyan

# --- KILL PREVIOUS PROCESSES
Get-Process glances -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# --- REMOVE OLD PYTHON USER PACKAGES
$pyBase = python -m site --user-base 2>$null
if ($pyBase) {
    Write-Host "[*] Removing old Python local packages..."
    Remove-Item -Recurse -Force "$pyBase" -ErrorAction SilentlyContinue
}

# --- REMOVE OLD GIT CLONES
Remove-Item -Recurse -Force "C:\temp\Automate-Sysmon-main" -ErrorAction SilentlyContinue

# =============================================================
# INSTALL SYSMON (AUTO)
# =============================================================
Write-Host "`n[*] Installing Sysmon automatically..." -ForegroundColor Cyan
iwr -useb 'https://simeononsecurity.ch/scripts/sosautomatesysmon.ps1' | iex

Write-Host "[*] Sysmon installation complete." -ForegroundColor Green


# =============================================================
# INSTALL PYTHON (IF MISSING)
# =============================================================
Write-Host "`n[*] Ensuring Python is installed..." -ForegroundColor Cyan

if (-not (Get-Command python.exe -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Python not found. Installing..."
    winget install -e --id Python.Python.3.13 --silent
} else {
    Write-Host "[*] Python found."
}

# FORCE REFRESH AFTER PYTHON INSTALL
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")


# =============================================================
# INSTALL GLANCES + WEB UI
# =============================================================
Write-Host "`n[*] Installing Glances..." -ForegroundColor Cyan

python -m pip install --upgrade pip
python -m pip install glances glances[web]

Write-Host "[*] Glances installed." -ForegroundColor Green


# =============================================================
# DISCOVER TRUE LOCATION OF glances.exe
# Microsoft Store Python hides this in insane paths.
# =============================================================

Write-Host "`n[*] Searching for glances.exe..." -ForegroundColor Cyan

$glancesPath = Get-ChildItem -Recurse -Filter "glances.exe" `
    "C:\Users\micha\AppData\Local\Packages" -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName -First 1

if (-not $glancesPath) {
    Write-Host "[!] glances.exe NOT FOUND. Something is wrong." -ForegroundColor Red
    exit
}

Write-Host "[*] Found glances.exe at: $glancesPath" -ForegroundColor Green


# =============================================================
# ADD TO PATH (ALWAYS WORKS)
# =============================================================

$scriptDir = Split-Path $glancesPath -Parent

Write-Host "[*] Adding Scripts dir to PATH: $scriptDir"

$currentUserPath = [Environment]::GetEnvironmentVariable("Path","User")

if ($currentUserPath -notlike "*$scriptDir*") {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$currentUserPath;$scriptDir",
        "User"
    )
}

# UPDATE PATH FOR CURRENT SESSION
$env:Path = "$env:Path;$scriptDir"

Write-Host "[*] PATH updated successfully." -ForegroundColor Green


# =============================================================
# START GLANCES WEB SERVER
# =============================================================

Write-Host "`n[*] Starting Glances web dashboard..." -ForegroundColor Cyan

# Run glances inside the real directory to avoid any path issue
Start-Process $glancesPath -ArgumentList "-w"

Start-Sleep -Seconds 3

# =============================================================
# OUTPUT FINAL URL
# =============================================================

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  YOUR REAL-TIME WINDOWS 11 MONITORING DASHBOARD IS READY  " -ForegroundColor Green
Write-Host "==========================================================`n" -ForegroundColor Cyan

Write-Host "Open this URL in your browser:" -ForegroundColor Yellow
Write-Host "    http://localhost:61208" -ForegroundColor Magenta
Write-Host "`n=========================================================="
