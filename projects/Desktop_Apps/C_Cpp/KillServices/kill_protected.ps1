param([string]$ServiceName = "EndpointProtectionService", [string]$ProcessName = "endpointprotection")

# Enable all privileges
function Enable-Privilege {
    param($Privilege)
    $definition = @'
    using System;
    using System.Runtime.InteropServices;
    public class AdjPriv {
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
            ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
        [DllImport("advapi32.dll", SetLastError = true)]
        internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        internal struct TokPriv1Luid {
            public int Count;
            public long Luid;
            public int Attr;
        }
        internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
        internal const int TOKEN_QUERY = 0x00000008;
        internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
        public static bool EnablePrivilege(long processHandle, string privilege) {
            bool retVal;
            TokPriv1Luid tp;
            IntPtr hproc = new IntPtr(processHandle);
            IntPtr htok = IntPtr.Zero;
            retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
            tp.Count = 1;
            tp.Luid = 0;
            tp.Attr = SE_PRIVILEGE_ENABLED;
            retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
            retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            return retVal;
        }
    }
'@
    try {
        $processHandle = (Get-Process -Id $pid).Handle
        Add-Type $definition -PassThru | Out-Null
        [AdjPriv]::EnablePrivilege($processHandle, $Privilege) | Out-Null
    } catch {}
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NUCLEAR SERVICE TERMINATOR" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

# Enable debug privileges
Enable-Privilege "SeDebugPrivilege"
Enable-Privilege "SeTakeOwnershipPrivilege"
Enable-Privilege "SeLoadDriverPrivilege"

# Get PID
$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
if ($proc) {
    $pid = $proc.Id
    Write-Host "[FOUND] Process: $ProcessName (PID: $pid)" -ForegroundColor Yellow
    
    # Try multiple methods
    Write-Host "[ATTEMPT 1] Using Stop-Process -Force..." -ForegroundColor Yellow
    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    
    if (Get-Process -Id $pid -ErrorAction SilentlyContinue) {
        Write-Host "[ATTEMPT 2] Using WMI..." -ForegroundColor Yellow
        (Get-WmiObject Win32_Process -Filter "ProcessId=$pid").Terminate() | Out-Null
        Start-Sleep -Milliseconds 500
    }
    
    if (Get-Process -Id $pid -ErrorAction SilentlyContinue) {
        Write-Host "[ATTEMPT 3] Using taskkill..." -ForegroundColor Yellow
        taskkill /F /PID $pid /T 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
    }
    
    if (Get-Process -Id $pid -ErrorAction SilentlyContinue) {
        Write-Host "[ATTEMPT 4] Using service_killer.exe..." -ForegroundColor Yellow
        & "F:\downloads\services\service_killer.exe" $ProcessName
        Start-Sleep -Milliseconds 500
    }
    
    if (Get-Process -Id $pid -ErrorAction SilentlyContinue) {
        Write-Host "[ATTEMPT 5] Stopping service..." -ForegroundColor Yellow
        net stop $ServiceName 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
    }
    
    if (Get-Process -Id $pid -ErrorAction SilentlyContinue) {
        Write-Host "[ATTEMPT 6] Disabling service and rebooting..." -ForegroundColor Yellow
        sc.exe config $ServiceName start= disabled 2>&1 | Out-Null
        Write-Host "[WARNING] Service is HIGHLY PROTECTED - requires reboot or safe mode" -ForegroundColor Red
    }
    
    # Final check
    if (!(Get-Process -Id $pid -ErrorAction SilentlyContinue)) {
        Write-Host "[SUCCESS] Process terminated!" -ForegroundColor Green
    } else {
        Write-Host "[FAILED] Process is still running - it's protected at kernel level" -ForegroundColor Red
        Write-Host "[INFO] This is likely AMD Anti-Lag protection or similar kernel-protected service" -ForegroundColor Yellow
    }
} else {
    Write-Host "[INFO] Process not found - already terminated?" -ForegroundColor Green
}

Write-Host "========================================" -ForegroundColor Cyan
