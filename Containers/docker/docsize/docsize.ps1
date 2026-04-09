<#
.SYNOPSIS
    docsize
#>
Write-Host "`n=== DOCKER DESKTOP HYPER-V RESOURCES ===" -ForegroundColor Cyan
    # Ensure Hyper-V VM Management service is running
    $vmms = Get-Service vmms -ErrorAction SilentlyContinue
    if ($vmms -and $vmms.Status -ne 'Running') {
        Write-Host "Starting Hyper-V service..." -ForegroundColor Yellow
        Start-Service vmms -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    $vm = Get-VM -Name "DockerDesktopVM" -ErrorAction SilentlyContinue
    if ($vm) {
        $memGB = [math]::Round($vm.MemoryStartup / 1GB, 1)
        $memAssignedGB = [math]::Round($vm.MemoryAssigned / 1GB, 1)
        $cpus = $vm.ProcessorCount
        $state = $vm.State
        Write-Host "[CONFIG] Allocated: ${memGB}GB RAM, $cpus CPUs" -ForegroundColor Yellow
        Write-Host "[STATE] $state" -ForegroundColor $(if($state -eq 'Running'){'Green'}else{'Gray'})
        if ($state -eq 'Running') {
            Write-Host "[LIVE] Memory in use: ${memAssignedGB}GB" -ForegroundColor Magenta
        }
    } else {
        Write-Host "DockerDesktopVM not found - Hyper-V backend not configured" -ForegroundColor Red
    }
    $totalMem = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $totalCpu = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
    Write-Host "[SYSTEM] ${totalMem}GB RAM, ${totalCpu} CPUs" -ForegroundColor DarkGray
    Write-Host "[TIERS] min|2(10%)|3(20%)|4(30%)|5(40%)|6(50%)|7(60%)|8(70%)|9(80%)|10(90%)|max" -ForegroundColor DarkCyan
    Write-Host ""
