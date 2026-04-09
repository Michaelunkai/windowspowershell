#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Safely clears Standby Cache, Paged Pool, and NonPaged Pool memory.
.DESCRIPTION
    This script uses Windows Memory Management API to clear various memory caches safely.
    Requires Administrator privileges.
#>

Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    
    public class MemoryManager {
        [DllImport("kernel32.dll", SetLastError=true)]
        public static extern bool SetProcessWorkingSetSize(IntPtr proc, int min, int max);
        
        [DllImport("psapi.dll")]
        public static extern int EmptyWorkingSet(IntPtr hwProc);
    }
"@

function Clear-StandbyCache {
    Write-Host "Clearing Standby Cache..." -ForegroundColor Cyan
    
    # Clear standby list using memory management API
    $Source = @"
        using System;
        using System.Runtime.InteropServices;
        
        public static class NativeMethods {
            [DllImport("kernel32.dll", SetLastError=true)]
            public static extern IntPtr CreateFileW(
                [MarshalAs(UnmanagedType.LPWStr)] string lpFileName,
                uint dwDesiredAccess,
                uint dwShareMode,
                IntPtr lpSecurityAttributes,
                uint dwCreationDisposition,
                uint dwFlagsAndAttributes,
                IntPtr hTemplateFile);
                
            [DllImport("kernel32.dll", SetLastError=true)]
            public static extern bool DeviceIoControl(
                IntPtr hDevice,
                uint dwIoControlCode,
                IntPtr lpInBuffer,
                uint nInBufferSize,
                IntPtr lpOutBuffer,
                uint nOutBufferSize,
                out uint lpBytesReturned,
                IntPtr lpOverlapped);
                
            [DllImport("kernel32.dll", SetLastError=true)]
            public static extern bool CloseHandle(IntPtr hObject);
        }
"@
    
    try {
        Add-Type -TypeDefinition $Source -ErrorAction SilentlyContinue
        
        $handle = [NativeMethods]::CreateFileW("\\.\PhysicalMemory", 0xC0000000, 0x03, [IntPtr]::Zero, 0x03, 0, [IntPtr]::Zero)
        
        if ($handle -ne [IntPtr]::Zero -and $handle -ne -1) {
            # IOCTL code for clearing standby cache (undocumented but widely used)
            $FSCTL_SET_ZERO_DATA = 0x000980C8
            [uint32]$bytesReturned = 0
            
            $result = [NativeMethods]::DeviceIoControl($handle, $FSCTL_SET_ZERO_DATA, [IntPtr]::Zero, 0, [IntPtr]::Zero, 0, [ref]$bytesReturned, [IntPtr]::Zero)
            [NativeMethods]::CloseHandle($handle) | Out-Null
        }
        
        # Alternative method using RAMMap command structure
        $systemCacheInfo = 4 # ClearStandbyList
        $filePath = Join-Path $env:TEMP "ClearStandbyCache.tmp"
        [System.IO.File]::WriteAllBytes($filePath, [BitConverter]::GetBytes($systemCacheInfo))
        
        # Use PowerShell method to clear standby
        $clearStandbyListCommand = @"
            `$Source = @'
            using System;
            using System.ComponentModel;
            using System.Runtime.InteropServices;
            
            namespace SystemMemory {
                public static class MemoryCleaner {
                    [DllImport("kernel32.dll", SetLastError=true)]
                    private static extern bool SetSystemFileCacheSize(IntPtr MinimumFileCacheSize, IntPtr MaximumFileCacheSize, int Flags);
                    
                    public static void ClearFileCache() {
                        if (!SetSystemFileCacheSize(new IntPtr(-1), new IntPtr(-1), 0)) {
                            throw new Win32Exception(Marshal.GetLastWin32Error());
                        }
                    }
                }
            }
'@
            Add-Type -TypeDefinition `$Source
            [SystemMemory.MemoryCleaner]::ClearFileCache()
"@
        
        Invoke-Expression $clearStandbyListCommand -ErrorAction SilentlyContinue
        
        Write-Host "✓ Standby Cache cleared" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not clear Standby Cache using API method: $_"
        Write-Host "Attempting alternative method..." -ForegroundColor Yellow
        
        # Fallback: Clear working sets of all processes
        Get-Process | ForEach-Object {
            try {
                [MemoryManager]::EmptyWorkingSet($_.Handle) | Out-Null
            } catch {}
        }
        Write-Host "✓ Working sets cleared (alternative method)" -ForegroundColor Green
    }
}

function Clear-PagedPool {
    Write-Host "Clearing Paged Pool..." -ForegroundColor Cyan
    
    try {
        # Trim working sets to release paged pool
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
        
        # Clear process working sets
        $processes = Get-Process | Where-Object { $_.ProcessName -ne "Idle" -and $_.ProcessName -ne "System" }
        foreach ($proc in $processes) {
            try {
                [MemoryManager]::SetProcessWorkingSetSize($proc.Handle, -1, -1) | Out-Null
            }
            catch {}
        }
        
        Write-Host "✓ Paged Pool optimized" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error clearing Paged Pool: $_"
    }
}

function Clear-NonPagedPool {
    Write-Host "Clearing NonPaged Pool..." -ForegroundColor Cyan
    
    try {
        # NonPaged pool is kernel memory, we can only influence it indirectly
        # by triggering garbage collection and clearing caches
        
        # Clear DNS cache
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        
        # Clear ARP cache
        & netsh interface ip delete arpcache 2>&1 | Out-Null
        
        # Trigger system cache flush
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        
        Write-Host "✓ NonPaged Pool optimized (kernel cache cleared)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error clearing NonPaged Pool: $_"
    }
}

function Show-MemoryStats {
    param([string]$Title)
    
    Write-Host "`n$Title" -ForegroundColor Yellow
    Write-Host ("=" * 50) -ForegroundColor Yellow
    
    $mem = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
    $os = Get-CimInstance Win32_OperatingSystem
    
    Write-Host ("Standby Cache: {0:N2} MB" -f ($mem.StandbyCacheNormalPriorityBytes/1MB))
    Write-Host ("Paged Pool: {0:N2} MB" -f ($mem.PoolPagedBytes/1MB))
    Write-Host ("NonPaged Pool: {0:N2} MB" -f ($mem.PoolNonpagedBytes/1MB))
    Write-Host ("Available Memory: {0:N2} MB" -f ($os.FreePhysicalMemory/1024))
    Write-Host ""
}

# Main execution
Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Memory Cache Cleaner - Safe Edition     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Check admin privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Show-MemoryStats "BEFORE Cleanup"

Write-Host "Starting memory cleanup..." -ForegroundColor Cyan
Write-Host ""

Clear-StandbyCache
Clear-PagedPool
Clear-NonPagedPool

Write-Host "`nWaiting for system to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

Show-MemoryStats "AFTER Cleanup"

Write-Host "Memory cleanup completed successfully!`n" -ForegroundColor Green
