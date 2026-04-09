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

$procs = Get-Process | Select-Object ProcessName, @{n="RAM_MB";e={[math]::Round($_.WorkingSet64/1MB,2)}}

# Group processes by name and sum their memory
$groupedProcs = $procs | Group-Object ProcessName | ForEach-Object {
    [pscustomobject]@{
        Name = $_.Name
        RAM_MB = [math]::Round(($_.Group | Measure-Object RAM_MB -Sum).Sum, 2)
        Count = $_.Count
    }
}

# Calculate system components
$pagedPool = [math]::Round($mem.PoolPagedBytes/1MB, 2)
$nonPagedPool = [math]::Round($mem.PoolNonpagedBytes/1MB, 2)
$modifiedPages = [math]::Round($mem.ModifiedPageListBytes/1MB, 2)
$standbyCache = [math]::Round(($mem.StandbyCacheCoreBytes + $mem.StandbyCacheNormalPriorityBytes + $mem.StandbyCacheReserveBytes)/1MB, 2)
$fileCache = [math]::Round($mem.CacheBytes/1MB, 2)

# Calculate total process memory
$totalProcessMem = [math]::Round(($groupedProcs | Measure-Object RAM_MB -Sum).Sum, 2)

# System/kernel overhead (hardware reserved, kernel structures, etc.)
$kernelOverhead = $usedRAM - $totalProcessMem - $pagedPool - $nonPagedPool - $modifiedPages

Write-Host "TOP MEMORY CONSUMERS:" -ForegroundColor Cyan
Write-Host "=====================`n" -ForegroundColor Cyan

$summary = @()

# System components
$summary += [pscustomobject]@{Category="System"; Name="Kernel & Drivers (NonPaged Pool)"; RAM_MB=$nonPagedPool; Percent=[math]::Round(($nonPagedPool/$totalRAM)*100,1)}
$summary += [pscustomobject]@{Category="System"; Name="Kernel & Drivers (Paged Pool)"; RAM_MB=$pagedPool; Percent=[math]::Round(($pagedPool/$totalRAM)*100,1)}
$summary += [pscustomobject]@{Category="System"; Name="Modified Pages (Pending Write)"; RAM_MB=$modifiedPages; Percent=[math]::Round(($modifiedPages/$totalRAM)*100,1)}
$summary += [pscustomobject]@{Category="System"; Name="Kernel Overhead & Hardware Reserved"; RAM_MB=$kernelOverhead; Percent=[math]::Round(($kernelOverhead/$totalRAM)*100,1)}

# Cache (can be reclaimed)
$summary += [pscustomobject]@{Category="Cache"; Name="Standby Cache (Reclaimable)"; RAM_MB=$standbyCache; Percent=[math]::Round(($standbyCache/$totalRAM)*100,1)}
$summary += [pscustomobject]@{Category="Cache"; Name="File System Cache"; RAM_MB=$fileCache; Percent=[math]::Round(($fileCache/$totalRAM)*100,1)}

# Top processes (only those using significant memory)
$topProcs = $groupedProcs | Where-Object {$_.RAM_MB -ge 10} | Sort-Object RAM_MB -Descending | Select-Object -First 20
foreach ($proc in $topProcs) {
    $instanceInfo = if ($proc.Count -gt 1) { " ($($proc.Count) instances)" } else { "" }
    $summary += [pscustomobject]@{
        Category="Process"
        Name="$($proc.Name)$instanceInfo"
        RAM_MB=$proc.RAM_MB
        Percent=[math]::Round(($proc.RAM_MB/$totalRAM)*100,1)
    }
}

# Output grouped by category
$summary | Sort-Object Category, RAM_MB -Descending | Format-Table -Property @{
    Label="Category"; Expression={$_.Category}; Width=10
}, @{
    Label="Name"; Expression={$_.Name}; Width=50
}, @{
    Label="RAM (MB)"; Expression={$_.RAM_MB}; Width=12; Align="Right"
}, @{
    Label="%"; Expression={$_.Percent}; Width=6; Align="Right"
} -AutoSize

Write-Host "`nOTHER PROCESSES (< 10 MB each):" -ForegroundColor Cyan
$smallProcs = $groupedProcs | Where-Object {$_.RAM_MB -lt 10 -and $_.RAM_MB -gt 0} | Sort-Object RAM_MB -Descending
$smallProcsTotal = [math]::Round(($smallProcs | Measure-Object RAM_MB -Sum).Sum, 2)
Write-Host "Total: $smallProcsTotal MB ($([math]::Round(($smallProcsTotal/$totalRAM)*100,1))%)" -ForegroundColor Gray
Write-Host "Count: $($smallProcs.Count) unique processes`n" -ForegroundColor Gray
