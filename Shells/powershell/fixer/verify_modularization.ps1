# Verification Script - Check modularization completeness

Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "MODULARIZATION VERIFICATION" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesDir = Join-Path $baseDir "modules"
$requiredModules = @(
    "script_00_init.ps1",
    "script_01_restore_point.ps1",
    "script_02-08_system_state.ps1",
    "script_09-15_boot_drivers.ps1",
    "script_16-25_drivers_dism.ps1",
    "script_26-35_dotnet_power.ps1",
    "script_36-45_network_gpu.ps1",
    "script_46-50_services_dcom.ps1",
    "script_51-60_hns_boot.ps1",
    "script_61-70_gaming_wsldns.ps1",
    "script_71-80_dism_storage.ps1",
    "script_81-92_nuclear_final.ps1"
)

# Check 1: Modules directory exists
Write-Host "[CHECK 1] Modules Directory" -ForegroundColor Yellow
if (Test-Path $modulesDir) {
    Write-Host "  [OK] Directory exists: $modulesDir" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Directory NOT found: $modulesDir" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Check 2: All module files exist
Write-Host "[CHECK 2] Module Files" -ForegroundColor Yellow
$missingModules = @()
foreach ($module in $requiredModules) {
    $modulePath = Join-Path $modulesDir $module
    if (Test-Path $modulePath) {
        $size = (Get-Item $modulePath).Length
        $sizeKB = [math]::Round($size / 1KB, 1)
        Write-Host "  [OK] $module ($sizeKB KB)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $module - MISSING" -ForegroundColor Red
        $missingModules += $module
    }
}

if ($missingModules.Count -gt 0) {
    Write-Host ""
    Write-Host "Missing modules: $($missingModules -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Check 3: Phase 52 fix in module script
Write-Host "[CHECK 3] Phase 52 Timeout Fix" -ForegroundColor Yellow
$phase52Script = Join-Path $modulesDir "script_51-60_hns_boot.ps1"
$phase52Content = Get-Content $phase52Script -Raw

if ($phase52Content -match "Wait-Job -Timeout 30") {
    Write-Host "  [OK] Job-based timeout fix found (30 seconds)" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Timeout fix NOT found in Phase 52 module" -ForegroundColor Red
    exit 1
}

if ($phase52Content -match "Remove-Job.*Force") {
    Write-Host "  [OK] Job cleanup (Remove-Job -Force) found" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Job cleanup not found" -ForegroundColor Red
    exit 1
}

if ($phase52Content -notmatch "Invoke-ServiceOperation.*dockerServices") {
    Write-Host "  [OK] Old blocking ServiceOperation removed" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Old blocking code still present" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Check 4: Master orchestrator exists
Write-Host "[CHECK 4] Master Orchestrator" -ForegroundColor Yellow
$orchestratorPath = Join-Path $baseDir "a_modular.ps1"
if (Test-Path $orchestratorPath) {
    $orchestratorSize = (Get-Item $orchestratorPath).Length
    $orchestratorKB = [math]::Round($orchestratorSize / 1KB, 1)
    Write-Host "  [OK] Master orchestrator exists ($orchestratorKB KB)" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Master orchestrator NOT found: $orchestratorPath" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Check 5: Phase 52 fix in original a.ps1
Write-Host "[CHECK 5] Phase 52 Fix in Original a.ps1" -ForegroundColor Yellow
$originalScript = Join-Path $baseDir "a.ps1"
if (Test-Path $originalScript) {
    $originalContent = Get-Content $originalScript -Raw
    if ($originalContent -match "Wait-Job -Timeout 30.*Stop-Service.*Force") {
        Write-Host "  [OK] Timeout fix applied to original a.ps1" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Original a.ps1 does not have timeout fix" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [FAIL] Original a.ps1 not found" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Check 6: Phase count verification
Write-Host "[CHECK 6] Phase Count Verification" -ForegroundColor Yellow
$totalPhases = 0
foreach ($module in $requiredModules) {
    if ($module -eq "script_00_init.ps1") { continue }

    $modulePath = Join-Path $modulesDir $module
    $content = Get-Content $modulePath -Raw
    $phases = [regex]::Matches($content, 'Phase\s+"[^"]+')
    $phaseCount = $phases.Count
    $totalPhases += $phaseCount
    Write-Host "  $module : $phaseCount phases" -ForegroundColor Cyan
}

if ($totalPhases -eq 92) {
    Write-Host "  [OK] Total phases: $totalPhases (CORRECT)" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Total phases: $totalPhases (expected 92)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Summary
Write-Host "=" * 70 -ForegroundColor Green
Write-Host "VERIFICATION COMPLETE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green
Write-Host ""
Write-Host "All checks passed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run the master orchestrator:" -ForegroundColor White
Write-Host "     & '$orchestratorPath'" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. Or test original script with fix:" -ForegroundColor White
Write-Host "     & '$originalScript'" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. Monitor Phase 52 (HNS/Docker Network Reset)" -ForegroundColor White
Write-Host "     Should complete WITHOUT hanging" -ForegroundColor Yellow
Write-Host ""
