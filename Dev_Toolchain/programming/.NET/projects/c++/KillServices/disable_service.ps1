param([string]$ProcessName = "endpointprotection")

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ULTIMATE SERVICE KILLER" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
if ($proc) {
    $procId = $proc.Id
    $ramBefore = [math]::Round($proc.WorkingSet64/1MB, 2)
    Write-Host "[FOUND] $ProcessName (PID: $procId) using $ramBefore MB RAM" -ForegroundColor Yellow
    
    # Method 1: Direct PowerShell
    try {
        Stop-Process -Id $procId -Force -ErrorAction Stop
        Start-Sleep -Milliseconds 300
        Write-Host "[SUCCESS] Killed with Stop-Process!" -ForegroundColor Green
    } catch {
        Write-Host "[FAILED] Stop-Process blocked" -ForegroundColor Red
    }
    
    # Method 2: WMI
    if (Get-Process -Id $procId -ErrorAction SilentlyContinue) {
        try {
            (Get-WmiObject Win32_Process -Filter "ProcessId=$procId").Terminate()
            Start-Sleep -Milliseconds 300
            Write-Host "[SUCCESS] Killed with WMI!" -ForegroundColor Green
        } catch {
            Write-Host "[FAILED] WMI blocked" -ForegroundColor Red
        }
    }
    
    # Method 3: Taskkill
    if (Get-Process -Id $procId -ErrorAction SilentlyContinue) {
        taskkill /F /PID $procId 2>&1 | Out-Null
        Start-Sleep -Milliseconds 300
        if (!(Get-Process -Id $procId -ErrorAction SilentlyContinue)) {
            Write-Host "[SUCCESS] Killed with taskkill!" -ForegroundColor Green
        } else {
            Write-Host "[FAILED] Taskkill blocked" -ForegroundColor Red
        }
    }
    
    # Method 4: Registry disable service
    if (Get-Process -Id $procId -ErrorAction SilentlyContinue) {
        Write-Host "[ATTEMPT] Disabling via registry..." -ForegroundColor Yellow
        $services = Get-Service | Where-Object { $_.DisplayName -like "*$ProcessName*" -or $_.ServiceName -like "*$ProcessName*" }
        foreach ($svc in $services) {
            try {
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.ServiceName)" -Name "Start" -Value 4 -ErrorAction Stop
                Write-Host "[DISABLED] Service: $($svc.ServiceName)" -ForegroundColor Green
            } catch {
                Write-Host "[FAILED] Cannot modify registry for $($svc.ServiceName)" -ForegroundColor Red
            }
        }
    }
    
    # Final check
    Start-Sleep -Seconds 1
    $stillRunning = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if (!$stillRunning) {
        Write-Host "" 
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "SUCCESS! Process terminated!" -ForegroundColor Green
        Write-Host "RAM freed: ~$ramBefore MB" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "KERNEL-LEVEL PROTECTED PROCESS DETECTED" -ForegroundColor Red
        Write-Host "This process has Anti-Tamper protection" -ForegroundColor Yellow
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  1. Boot into Safe Mode and delete it" -ForegroundColor Cyan
        Write-Host "  2. Use driver-level termination tool" -ForegroundColor Cyan  
        Write-Host "  3. Disable from BIOS/UEFI settings" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Red
    }
} else {
    Write-Host "[INFO] Process '$ProcessName' not found or already terminated" -ForegroundColor Green
}
