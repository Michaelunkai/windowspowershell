$os = Get-CimInstance Win32_OperatingSystem
$mem = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory

$totalRAM = [math]::Round($os.TotalVisibleMemorySize/1KB, 2)
$usedRAM = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1KB, 2)
$freeRAM = [math]::Round($os.FreePhysicalMemory/1KB, 2)
$usagePercent = [math]::Round(($usedRAM / $totalRAM) * 100, 1)

Write-Host "`n========== MEMORY OVERVIEW ==========" -ForegroundColor Cyan
Write-Host "Total RAM:     $totalRAM MB" -ForegroundColor White
Write-Host "Used RAM:      $usedRAM MB ($usagePercent%)" -ForegroundColor Yellow
Write-Host "Free RAM:      $freeRAM MB" -ForegroundColor Green
Write-Host "======================================`n" -ForegroundColor Cyan

# Get all processes with detailed info
$procs = Get-Process | Select-Object ProcessName, Id, 
    @{n="RAM_MB";e={[math]::Round($_.WorkingSet64/1MB,2)}},
    @{n="Path";e={$_.Path}},
    @{n="MainWindowTitle";e={$_.MainWindowTitle}},
    @{n="StartTime";e={try{$_.StartTime}catch{$null}}}

# Group by process name
$groupedProcs = $procs | Group-Object ProcessName | ForEach-Object {
    $processes = $_.Group | Sort-Object RAM_MB -Descending
    $topProcess = $processes[0]
    
    [pscustomobject]@{
        Name = $_.Name
        TotalRAM_MB = [math]::Round(($processes | Measure-Object RAM_MB -Sum).Sum, 2)
        Count = $_.Count
        Instances = $processes
        Path = $topProcess.Path
        CanClose = ($topProcess.Path -ne $null -and $topProcess.Name -notmatch '^(System|Idle|Registry|csrss|wininit|services|lsass|smss|dwm|svchost|RuntimeBroker|sihost|taskhostw|fontdrvhost|WUDFHost)$')
    }
}

# Calculate system components
$pagedPool = [math]::Round($mem.PoolPagedBytes/1MB, 2)
$nonPagedPool = [math]::Round($mem.PoolNonpagedBytes/1MB, 2)
$modifiedPages = [math]::Round($mem.ModifiedPageListBytes/1MB, 2)
$standbyCache = [math]::Round(($mem.StandbyCacheCoreBytes + $mem.StandbyCacheNormalPriorityBytes + $mem.StandbyCacheReserveBytes)/1MB, 2)

$totalProcessMem = [math]::Round(($groupedProcs | Measure-Object TotalRAM_MB -Sum).Sum, 2)
$kernelOverhead = $usedRAM - $totalProcessMem - $pagedPool - $nonPagedPool - $modifiedPages

Write-Host "========== SYSTEM MEMORY (NOT ACTIONABLE) ==========" -ForegroundColor DarkGray
Write-Host "These are kernel/system components you cannot stop:`n" -ForegroundColor Gray

$systemMem = @(
    [pscustomobject]@{Component="Kernel Overhead & Hardware Reserved"; RAM_MB=$kernelOverhead; Percent=[math]::Round(($kernelOverhead/$totalRAM)*100,1)}
    [pscustomobject]@{Component="Modified Pages (Pending Write)"; RAM_MB=$modifiedPages; Percent=[math]::Round(($modifiedPages/$totalRAM)*100,1)}
    [pscustomobject]@{Component="Kernel & Drivers (NonPaged Pool)"; RAM_MB=$nonPagedPool; Percent=[math]::Round(($nonPagedPool/$totalRAM)*100,1)}
    [pscustomobject]@{Component="Kernel & Drivers (Paged Pool)"; RAM_MB=$pagedPool; Percent=[math]::Round(($pagedPool/$totalRAM)*100,1)}
    [pscustomobject]@{Component="Standby Cache (Auto-Reclaimable)"; RAM_MB=$standbyCache; Percent=[math]::Round(($standbyCache/$totalRAM)*100,1)}
)

$systemMem | Format-Table -Property @{
    Label="Component"; Expression={$_.Component}; Width=40
}, @{
    Label="RAM (MB)"; Expression={$_.RAM_MB}; Width=12; Align="Right"
}, @{
    Label="%"; Expression={$_.Percent}; Width=6; Align="Right"
} -AutoSize

$systemTotal = [math]::Round(($systemMem | Measure-Object RAM_MB -Sum).Sum, 2)
Write-Host "System Total: $systemTotal MB ($([math]::Round(($systemTotal/$totalRAM)*100,1))%)" -ForegroundColor DarkGray
Write-Host "NOTE: Standby Cache is auto-released when needed - not a problem!`n" -ForegroundColor DarkYellow

Write-Host "`n========== APPLICATIONS YOU CAN CLOSE ==========" -ForegroundColor Red
Write-Host "These consume RAM and can be stopped to free memory:`n" -ForegroundColor Yellow

$closableApps = $groupedProcs | Where-Object {$_.CanClose -and $_.TotalRAM_MB -ge 5} | Sort-Object TotalRAM_MB -Descending

$actionable = @()
foreach ($app in $closableApps) {
    $color = if ($app.TotalRAM_MB -gt 100) { "Red" } 
             elseif ($app.TotalRAM_MB -gt 50) { "Yellow" } 
             else { "White" }
    
    $instanceInfo = if ($app.Count -gt 1) { " ($($app.Count) instances)" } else { "" }
    
    $actionable += [pscustomobject]@{
        Application = "$($app.Name)$instanceInfo"
        "RAM (MB)" = $app.TotalRAM_MB
        "%" = [math]::Round(($app.TotalRAM_MB/$totalRAM)*100,1)
        Color = $color
        ProcessName = $app.Name
    }
}

foreach ($item in $actionable) {
    $ramStr = "$($item.'RAM (MB)')".PadLeft(10)
    $pctStr = "$($item.'%')%".PadLeft(5)
    Write-Host "$ramStr MB  $pctStr  " -NoNewline -ForegroundColor $item.Color
    Write-Host "$($item.Application)" -ForegroundColor $item.Color
}

$actionableTotal = [math]::Round(($actionable | Measure-Object 'RAM (MB)' -Sum).Sum, 2)
Write-Host "`nActionable Total: $actionableTotal MB ($([math]::Round(($actionableTotal/$totalRAM)*100,1))%)" -ForegroundColor Green

Write-Host "`n========== SYSTEM PROCESSES (CRITICAL - DO NOT CLOSE) ==========" -ForegroundColor DarkGray
$systemProcs = $groupedProcs | Where-Object {-not $_.CanClose -and $_.TotalRAM_MB -ge 5} | Sort-Object TotalRAM_MB -Descending | Select-Object -First 10

foreach ($proc in $systemProcs) {
    $instanceInfo = if ($proc.Count -gt 1) { " ($($proc.Count) instances)" } else { "" }
    Write-Host "$([math]::Round($proc.TotalRAM_MB,2))".PadLeft(10) -NoNewline -ForegroundColor DarkGray
    Write-Host " MB   $($proc.Name)$instanceInfo" -ForegroundColor Gray
}

Write-Host "`n========== HOW TO FREE MEMORY ==========" -ForegroundColor Cyan
Write-Host "Run these commands to close high-memory applications:`n" -ForegroundColor White

$topClosable = $closableApps | Select-Object -First 5
foreach ($app in $topClosable) {
    if ($app.Name -eq "chrome" -or $app.Name -match "edge|firefox|browser") {
        Write-Host "  # Close $($app.Name) ($($app.TotalRAM_MB) MB) - Save tabs first!" -ForegroundColor Yellow
        Write-Host "  Stop-Process -Name '$($app.Name)' -Force`n" -ForegroundColor White
    }
    elseif ($app.TotalRAM_MB -gt 50) {
        Write-Host "  # Close $($app.Name) ($($app.TotalRAM_MB) MB)" -ForegroundColor Yellow
        Write-Host "  Stop-Process -Name '$($app.Name)' -Force`n" -ForegroundColor White
    }
}

Write-Host "`n========== DETAILED PROCESS BREAKDOWN ==========" -ForegroundColor Cyan
Write-Host "Showing individual instances for top consumers:`n" -ForegroundColor White

$topApps = $closableApps | Select-Object -First 3
foreach ($app in $topApps) {
    Write-Host "`n[$($app.Name)] Total: $($app.TotalRAM_MB) MB" -ForegroundColor Yellow
    $app.Instances | Sort-Object RAM_MB -Descending | Select-Object -First 10 | ForEach-Object {
        $title = if ($_.MainWindowTitle) { " - $($_.MainWindowTitle)" } else { "" }
        $runtime = if ($_.StartTime) { " (Running: $([math]::Round(((Get-Date) - $_.StartTime).TotalHours, 1))h)" } else { "" }
        Write-Host "  PID $($_.Id): $($_.RAM_MB) MB$title$runtime" -ForegroundColor Gray
    }
}

Write-Host "`n========== QUICK ACTIONS ==========" -ForegroundColor Green
Write-Host "Copy-paste these commands to free memory quickly:`n" -ForegroundColor White

if ($closableApps | Where-Object Name -eq "chrome") {
    $chromeRAM = ($closableApps | Where-Object Name -eq "chrome").TotalRAM_MB
    Write-Host "# Close Chrome (frees ~$chromeRAM MB):" -ForegroundColor Yellow
    Write-Host "Stop-Process -Name 'chrome' -Force`n" -ForegroundColor White
}

if ($closableApps | Where-Object {$_.Name -match "Docker"}) {
    $dockerRAM = ($closableApps | Where-Object {$_.Name -match "Docker"} | Measure-Object TotalRAM_MB -Sum).Sum
    Write-Host "# Stop Docker (frees ~$([math]::Round($dockerRAM, 2)) MB):" -ForegroundColor Yellow
    Write-Host "Stop-Process -Name 'Docker Desktop','com.docker.backend','com.docker.service' -Force -ErrorAction SilentlyContinue`n" -ForegroundColor White
}

Write-Host "# Or close all non-essential apps automatically:" -ForegroundColor Yellow
Write-Host @"
`$apps = 'chrome','msedge','firefox','Teams','Slack','Discord','Spotify'
foreach (`$app in `$apps) { Stop-Process -Name `$app -Force -ErrorAction SilentlyContinue }
"@ -ForegroundColor White

Write-Host "`n====================================`n" -ForegroundColor Cyan
