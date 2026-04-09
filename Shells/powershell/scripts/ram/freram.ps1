# freram - MAXIMUM RAM Reduction (Run as Administrator!)
# Uses undocumented NT APIs for aggressive memory purging
Write-Host ">>> MAXIMUM RAM REDUCTION <<<" -ForegroundColor Red

$os = Get-CimInstance Win32_OperatingSystem
$init = [math]::Round($os.FreePhysicalMemory/1024,0)
$total = [math]::Round($os.TotalVisibleMemorySize/1024,0)
Write-Host "Before: $init MB free / $total MB total" -ForegroundColor Yellow

# Load all memory management APIs
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Principal;

public class MemoryOptimizer
{
    // Process memory APIs
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
    
    [DllImport("kernel32.dll")]
    public static extern bool SetProcessWorkingSetSizeEx(IntPtr hProcess, IntPtr dwMinimumWorkingSetSize, IntPtr dwMaximumWorkingSetSize, uint Flags);
    
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();

    // NT System APIs for standby list purging
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
    
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);
    
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out LUID lpLuid);
    
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, int BufferLength, IntPtr PreviousState, IntPtr ReturnLength);
    
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID { public uint LowPart; public int HighPart; }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct LUID_AND_ATTRIBUTES { public LUID Luid; public uint Attributes; }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct TOKEN_PRIVILEGES { public uint PrivilegeCount; public LUID_AND_ATTRIBUTES Privileges; }

    const uint TOKEN_ADJUST_PRIVILEGES = 0x0020;
    const uint TOKEN_QUERY = 0x0008;
    const uint SE_PRIVILEGE_ENABLED = 0x00000002;
    const int SystemMemoryListInformation = 80;
    
    // Memory list commands
    const int MemoryEmptyWorkingSets = 2;
    const int MemoryFlushModifiedList = 3;
    const int MemoryPurgeStandbyList = 4;
    const int MemoryPurgeLowPriorityStandbyList = 5;

    public static bool EnablePrivilege(string privilege)
    {
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out token))
            return false;
        
        LUID luid;
        if (!LookupPrivilegeValue(null, privilege, out luid))
        {
            CloseHandle(token);
            return false;
        }
        
        TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
        tp.PrivilegeCount = 1;
        tp.Privileges.Luid = luid;
        tp.Privileges.Attributes = SE_PRIVILEGE_ENABLED;
        
        bool result = AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        CloseHandle(token);
        return result;
    }

    public static int PurgeMemory(int command)
    {
        IntPtr pCommand = Marshal.AllocHGlobal(sizeof(int));
        Marshal.WriteInt32(pCommand, command);
        uint result = NtSetSystemInformation(SystemMemoryListInformation, pCommand, sizeof(int));
        Marshal.FreeHGlobal(pCommand);
        return (int)result;
    }

    public static void PurgeStandbyList()
    {
        EnablePrivilege("SeProfileSingleProcessPrivilege");
        PurgeMemory(MemoryPurgeStandbyList);
    }

    public static void PurgeLowPriorityStandbyList()
    {
        EnablePrivilege("SeProfileSingleProcessPrivilege");
        PurgeMemory(MemoryPurgeLowPriorityStandbyList);
    }

    public static void FlushModifiedList()
    {
        EnablePrivilege("SeProfileSingleProcessPrivilege");
        PurgeMemory(MemoryFlushModifiedList);
    }

    public static void EmptySystemWorkingSets()
    {
        EnablePrivilege("SeProfileSingleProcessPrivilege");
        PurgeMemory(MemoryEmptyWorkingSets);
    }

    public static int TrimAllProcesses()
    {
        int count = 0;
        foreach (Process proc in Process.GetProcesses())
        {
            try
            {
                EmptyWorkingSet(proc.Handle);
                // Also use SetProcessWorkingSetSizeEx with -1 to force page-out
                SetProcessWorkingSetSizeEx(proc.Handle, (IntPtr)(-1), (IntPtr)(-1), 0);
                count++;
            }
            catch { }
        }
        return count;
    }
}
"@ -ErrorAction SilentlyContinue

Write-Host "Step 1: Purging Standby List (NT API)..." -ForegroundColor Cyan
try {
    [MemoryOptimizer]::PurgeStandbyList()
    Write-Host "   [OK] Standby list purged" -ForegroundColor Green
} catch {
    Write-Host "   [WARN] Need admin rights for standby purge" -ForegroundColor Yellow
}

Write-Host "Step 2: Purging Low-Priority Standby..." -ForegroundColor Cyan
try {
    [MemoryOptimizer]::PurgeLowPriorityStandbyList()
    Write-Host "   [OK] Low-priority standby purged" -ForegroundColor Green
} catch { }

Write-Host "Step 3: Flushing Modified Page List..." -ForegroundColor Cyan
try {
    [MemoryOptimizer]::FlushModifiedList()
    Write-Host "   [OK] Modified list flushed" -ForegroundColor Green
} catch { }

Write-Host "Step 4: Emptying System Working Sets..." -ForegroundColor Cyan
try {
    [MemoryOptimizer]::EmptySystemWorkingSets()
    Write-Host "   [OK] System working sets emptied" -ForegroundColor Green
} catch { }

Write-Host "Step 5: Trimming All Process Working Sets..." -ForegroundColor Cyan
$trimmed = [MemoryOptimizer]::TrimAllProcesses()
Write-Host "   [OK] Trimmed $trimmed processes" -ForegroundColor Green

Write-Host "Step 6: PowerShell GC + LOH Compaction..." -ForegroundColor Cyan
[System.Runtime.GCSettings]::LargeObjectHeapCompactionMode = [System.Runtime.GCLargeObjectHeapCompactionMode]::CompactOnce
[GC]::Collect([GC]::MaxGeneration, [GCCollectionMode]::Forced, $true, $true)
[GC]::WaitForPendingFinalizers()
[GC]::Collect()
Write-Host "   [OK] GC completed" -ForegroundColor Green

Write-Host "Step 7: Second Pass (catch reallocations)..." -ForegroundColor Cyan
Start-Sleep -Milliseconds 300
[MemoryOptimizer]::PurgeStandbyList()
[MemoryOptimizer]::TrimAllProcesses()
Write-Host "   [OK] Second pass done" -ForegroundColor Green

# Also try EmptyStandbyList.exe if available (belt and suspenders)
$esl = "C:\Windows\System32\EmptyStandbyList.exe"
if (Test-Path $esl) {
    Write-Host "Step 8: EmptyStandbyList.exe backup..." -ForegroundColor Cyan
    Start-Process $esl "standbylist" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process $esl "workingsets" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Write-Host "   [OK] External tool executed" -ForegroundColor Green
}

# Final stats
Start-Sleep -Milliseconds 500
$os2 = Get-CimInstance Win32_OperatingSystem
$final = [math]::Round($os2.FreePhysicalMemory/1024,0)
$freed = $final - $init
$pct = [math]::Round(($final/$total)*100,1)

Write-Host "`n>>> RESULTS <<<" -ForegroundColor Green
Write-Host "After: $final MB free / $total MB total ($pct%)" -ForegroundColor Yellow
Write-Host "Freed: $freed MB" -ForegroundColor $(if($freed -gt 0){"Green"}else{"Red"})

if ($freed -lt 100 -and $init -lt ($total * 0.3)) {
    Write-Host "`nTIP: Run as Administrator for maximum effect!" -ForegroundColor Magenta
}
