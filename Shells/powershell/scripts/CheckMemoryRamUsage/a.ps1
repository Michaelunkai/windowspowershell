$os = Get-CimInstance Win32_OperatingSystem
$mem = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
$procs = Get-Process | Select-Object ProcessName,@{n="RAM_MB";e={[math]::Round($_.WorkingSet64/1MB,2)}}

$list = @()

# Add each process
$list += $procs | ForEach-Object { [pscustomobject]@{Name=$_.ProcessName; RAM_MB=$_.RAM_MB} }

# Add system-level memory consumers
$list += [pscustomobject]@{Name="Memory Compression"; RAM_MB=[math]::Round((Get-Process "Memory Compression" -ErrorAction SilentlyContinue).WorkingSet64/1MB,2)}
$list += [pscustomobject]@{Name="Paged Pool (Drivers)"; RAM_MB=[math]::Round($mem.PoolPagedBytes/1MB,2)}
$list += [pscustomobject]@{Name="NonPaged Pool (Drivers)"; RAM_MB=[math]::Round($mem.PoolNonpagedBytes/1MB,2)}
$list += [pscustomobject]@{Name="Standby Cache"; RAM_MB=[math]::Round($mem.StandbyCacheNormalPriorityBytes/1MB,2)}
$list += [pscustomobject]@{Name="File Cache"; RAM_MB=[math]::Round($mem.CacheBytes/1MB,2)}
$list += [pscustomobject]@{Name="WSL / VMs (vmmem)"; RAM_MB=[math]::Round(((Get-Process -Name "vmmem","vmmemWSL" -ErrorAction SilentlyContinue | Measure-Object WorkingSet64 -Sum).Sum/1MB),2)}
$list += [pscustomobject]@{Name="System (Kernel + Misc)"; RAM_MB=[math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB) - ($procs.RAM_MB | Measure-Object -Sum).Sum,2)}

# Output sorted RAM usage
$list | Sort-Object RAM_MB -Descending | Format-Table -AutoSize
