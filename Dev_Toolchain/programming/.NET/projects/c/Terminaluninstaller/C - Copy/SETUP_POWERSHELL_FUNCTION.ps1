# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                                                                          ║
# ║     SETUP POWERSHELL FUNCTION FOR ULTIMATE UNINSTALLER NUCLEAR          ║
# ║                                                                          ║
# ╚══════════════════════════════════════════════════════════════════════════╝

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  NUCLEAR UNINSTALLER - PowerShell Function Setup" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$nuclearPath = "F:\study\Dev_Toolchain\programming\.NET\projects\c\Terminaluninstaller\C\ultimate_uninstaller_NUCLEAR.exe"

# Check if NUCLEAR exe exists
if (-not (Test-Path $nuclearPath)) {
    Write-Host "ERROR: NUCLEAR executable not found at:" -ForegroundColor Red
    Write-Host "  $nuclearPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please compile it first using:" -ForegroundColor Yellow
    Write-Host "  compile_nuclear.bat" -ForegroundColor White
    Write-Host ""
    pause
    exit 1
}

Write-Host "✓ Found NUCLEAR executable" -ForegroundColor Green
Write-Host ""

# Get PowerShell profile path
$profilePath = $PROFILE.CurrentUserAllHosts
Write-Host "PowerShell Profile: $profilePath" -ForegroundColor Cyan
Write-Host ""

# Create profile directory if it doesn't exist
$profileDir = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) {
    Write-Host "Creating profile directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Create profile if it doesn't exist
if (-not (Test-Path $profilePath)) {
    Write-Host "Creating PowerShell profile..." -ForegroundColor Yellow
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

# Function definition
$functionDefinition = @"

# ═══════════════════════════════════════════════════════════════════════
# ULTIMATE UNINSTALLER NUCLEAR - Universal App Obliterator
# ═══════════════════════════════════════════════════════════════════════
function uni {
    `$nuclearExe = "$nuclearPath"

    if (-not (Test-Path `$nuclearExe)) {
        Write-Host "ERROR: NUCLEAR executable not found!" -ForegroundColor Red
        Write-Host "  Expected: `$nuclearExe" -ForegroundColor Red
        return
    }

    # Check for admin privileges
    `$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not `$isAdmin) {
        Write-Host ""
        Write-Host "ERROR: Administrator privileges required!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please run PowerShell as Administrator, then retry:" -ForegroundColor Yellow
        Write-Host "  uni @args" -ForegroundColor White
        Write-Host ""
        return
    }

    # Execute NUCLEAR with all arguments
    & `$nuclearExe @args
}

# Aliases for convenience
Set-Alias -Name uninstall -Value uni -Force -Option AllScope
Set-Alias -Name nuke -Value uni -Force -Option AllScope
Set-Alias -Name obliterate -Value uni -Force -Option AllScope

# ═══════════════════════════════════════════════════════════════════════
"@

# Check if function already exists
$currentContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

if ($currentContent -match "function uni \{") {
    Write-Host "Function 'uni' already exists in profile!" -ForegroundColor Yellow
    Write-Host ""
    $choice = Read-Host "Replace it? (Y/N)"

    if ($choice -ne "Y" -and $choice -ne "y") {
        Write-Host ""
        Write-Host "Cancelled. No changes made." -ForegroundColor Yellow
        Write-Host ""
        pause
        exit 0
    }

    # Remove old function
    $currentContent = $currentContent -replace "(?ms)# ═+\s*ULTIMATE UNINSTALLER.*?# ═+\s*", ""
}

# Append new function
Add-Content -Path $profilePath -Value $functionDefinition

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✓ SUCCESS! Function 'uni' added to PowerShell profile" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "RELOAD YOUR PROFILE:" -ForegroundColor Yellow
Write-Host "  . `$PROFILE" -ForegroundColor White
Write-Host ""
Write-Host "Or restart PowerShell for changes to take effect." -ForegroundColor Cyan
Write-Host ""
Write-Host "USAGE EXAMPLES:" -ForegroundColor Yellow
Write-Host "  uni `"DRIVER BOOSTER`" DRIVERBOOSTER IOBIT" -ForegroundColor White
Write-Host "  uni `"CHROME`" GOOGLE" -ForegroundColor White
Write-Host "  uni `"ADOBE`" ACROBAT READER" -ForegroundColor White
Write-Host "  uni `"ANYDESK`"" -ForegroundColor White
Write-Host "  uni `"TEAMVIEWER`"" -ForegroundColor White
Write-Host "  uni `"CCLEANER`"" -ForegroundColor White
Write-Host ""
Write-Host "ALIASES AVAILABLE:" -ForegroundColor Yellow
Write-Host "  uni, uninstall, nuke, obliterate" -ForegroundColor White
Write-Host ""
Write-Host "ALL COMMANDS WORK WITH ANY APPLICATION!" -ForegroundColor Green
Write-Host ""

pause
