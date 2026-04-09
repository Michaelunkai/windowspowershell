# Script to insert enhancements into logs and fixer scripts
$ErrorActionPreference = "Continue"

Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "INSERTING ENHANCEMENTS INTO SCRIPTS" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan

# ============================================================================
# INSERT INTO LOGS SCRIPT
# ============================================================================
Write-Host "`n1. Enhancing LOGS script..." -ForegroundColor Yellow

$logsPath = "F:\study\Platforms\windows\projects\logs\b\a.ps1"
$logsEnhancement = "F:\study\Platforms\windows\projects\logs\b\logs_enhancement.ps1"

try {
    Write-Host "  Reading original logs script..."
    $logsLines = Get-Content $logsPath -Encoding UTF8

    Write-Host "  Reading enhancement content..."
    $enhancementLines = Get-Content $logsEnhancement -Encoding UTF8

    Write-Host "  Finding insertion point (before SUMMARY section)..."
    $summaryLineIndex = -1
    for ($i = 0; $i -lt $logsLines.Count; $i++) {
        if ($logsLines[$i] -match "^# SUMMARY$") {
            $summaryLineIndex = $i
            break
        }
    }

    if ($summaryLineIndex -eq -1) {
        Write-Host "  ERROR: Could not find SUMMARY section marker!" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Inserting enhancement at line $summaryLineIndex..."

    # Create new content: before + enhancement + summary onwards
    $newLines = @()
    $newLines += $logsLines[0..($summaryLineIndex - 1)]
    $newLines += ""
    $newLines += $enhancementLines
    $newLines += ""
    $newLines += $logsLines[$summaryLineIndex..($logsLines.Count - 1)]

    Write-Host "  Writing enhanced script..."
    $newLines | Out-File $logsPath -Encoding UTF8 -Force

    $newCount = (Get-Content $logsPath).Count
    Write-Host "  SUCCESS! New line count: $newCount" -ForegroundColor Green

} catch {
    Write-Host "  ERROR: $_" -ForegroundColor Red
    exit 1
}

# ============================================================================
# INSERT INTO FIXER SCRIPT
# ============================================================================
Write-Host "`n2. Enhancing FIXER script..." -ForegroundColor Yellow

$fixerPath = "F:\study\shells\powershell\fixer\a.ps1"
$fixerEnhancement = "F:\study\shells\powershell\fixer\fixer_enhancement.ps1"

try {
    Write-Host "  Reading original fixer script..."
    $fixerLines = Get-Content $fixerPath -Encoding UTF8

    Write-Host "  Reading enhancement content..."
    $enhancementLines = Get-Content $fixerEnhancement -Encoding UTF8

    Write-Host "  Finding insertion point (before event log clearing - PHASE 54)..."
    $insertLineIndex = -1
    for ($i = 0; $i -lt $fixerLines.Count; $i++) {
        if ($fixerLines[$i] -match "#region PHASE 54.*Event Log Clearing") {
            $insertLineIndex = $i
            break
        }
    }

    if ($insertLineIndex -eq -1) {
        Write-Host "  ERROR: Could not find PHASE 54 marker!" -ForegroundColor Red
        Write-Host "  Looking for cleanup section instead..."

        for ($i = 0; $i -lt $fixerLines.Count; $i++) {
            if ($fixerLines[$i] -match "# Clear any crash dump files") {
                $insertLineIndex = $i - 2
                break
            }
        }
    }

    if ($insertLineIndex -eq -1) {
        Write-Host "  ERROR: Could not find insertion point!" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Inserting enhancement at line $insertLineIndex..."

    # Create new content: before + enhancement + cleanup onwards
    $newLines = @()
    $newLines += $fixerLines[0..($insertLineIndex - 1)]
    $newLines += ""
    $newLines += $enhancementLines
    $newLines += ""
    $newLines += $fixerLines[$insertLineIndex..($fixerLines.Count - 1)]

    Write-Host "  Writing enhanced script..."
    $newLines | Out-File $fixerPath -Encoding UTF8 -Force

    $newCount = (Get-Content $fixerPath).Count
    Write-Host "  SUCCESS! New line count: $newCount" -ForegroundColor Green

} catch {
    Write-Host "  ERROR: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
Write-Host "ENHANCEMENTS INSERTED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""
Write-Host "Scripts are now enhanced with:" -ForegroundColor Yellow
Write-Host "  - LOGS: Complete performance detection (network, gaming, Docker, freezes)" -ForegroundColor Cyan
Write-Host "  - FIXER: Boot-critical file protection + all fixes" -ForegroundColor Cyan
Write-Host ""
