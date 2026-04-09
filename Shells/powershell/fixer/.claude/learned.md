# Learned Lessons - Windows Fixer Script

## Critical Issue: Boot File Corruption (2025-12-11 13:43)

### What Went Wrong
The fixer script v5.4 corrupted boot-critical driver file `c:\windows\system32\drivers\acpiex.sys` causing:
```
Automatic Repair couldn't repair your PC
Boot critical file c:\windows\system32\drivers\acpiex.sys is corrupt
File repair failed, Error code = 0x57
```

### Why It Happened
1. **Aggressive SFC/DISM operations** without sufficient safety checks
2. **No backup of boot-critical files** before modification
3. **Component store corruption** existed BEFORE running fixer, making DISM RestoreHealth dangerous
4. **Insufficient pre-flight checks** - script didn't detect the component store was already corrupted
5. **Running too frequently** - multiple runs in short period can cause cascading failures

### Root Cause Analysis
- When DISM's component store is corrupt, running `DISM /RestoreHealth` can:
  - Pull corrupted files from the store
  - Overwrite good files with bad ones
  - Corrupt additional system files
- `acpiex.sys` is **ACPI Extension** driver - absolutely CRITICAL for boot
- Error 0x57 = ERROR_INVALID_PARAMETER suggests file metadata corruption

### Correct Solution
1. **ALWAYS create boot-critical file backups FIRST**
   ```powershell
   $bootCriticalDrivers = @(
       "acpiex.sys", "ntoskrnl.exe", "hal.dll", "ntdll.dll",
       "kernel32.dll", "win32k.sys", "csrss.exe", "smss.exe"
   )
   # Backup before ANY repair operation
   ```

2. **Pre-flight integrity check**
   ```powershell
   # Check if component store is healthy BEFORE using it
   $dismState = dism /online /cleanup-image /checkhealth
   if ($dismState -match "repairable|corrupt") {
       # DO NOT run /RestoreHealth - it will make things worse
       # Instead, use safe repair methods
   }
   ```

3. **Safe repair order**
   - First: Fix component store corruption using `/StartComponentCleanup`
   - Second: Verify component store health
   - Third: Only if healthy, run `/RestoreHealth`
   - Fourth: Run SFC (relies on healthy component store)

4. **Never repair boot-critical drivers directly**
   - Use BCD boot recovery instead
   - Use Windows installation media for file replacement
   - Use System File Checker with KNOWN GOOD source

5. **Rollback capability**
   - Keep backups of all modified files
   - Implement automatic rollback on failure
   - Test system stability after each major operation

### Prevention Measures for Future
- ✅ Check component store health BEFORE repair
- ✅ Backup all boot-critical files to safe location
- ✅ Implement file integrity verification (hash checking)
- ✅ Add rollback mechanism for failed operations
- ✅ Detect pending operations that could conflict
- ✅ Minimum time between runs (enforce cooldown)
- ✅ Restore point verification before proceeding

### Files to NEVER modify without backup
```
C:\Windows\System32\drivers\acpiex.sys
C:\Windows\System32\ntoskrnl.exe
C:\Windows\System32\hal.dll
C:\Windows\System32\ntdll.dll
C:\Windows\System32\kernel32.dll
C:\Windows\System32\win32k.sys
C:\Windows\System32\csrss.exe
C:\Windows\System32\smss.exe
C:\Windows\System32\winload.exe
C:\Windows\System32\winresume.exe
```

---

## Issue: HNS Docker Error 0x80070032 (2025-12-11)

### Problem
```
HNS ERROR: 'IpNatHlpStopSharing' : '0x80070032'
HNS ERROR: HNS failed to delete winnat instance
```

### Solution
Complete HNS network reset:
```powershell
Stop-Service hns -Force
Remove-Item "C:\ProgramData\Microsoft\Windows\HNS\HNS.data" -Force
Restart-Service hns
docker network prune -f
```

---

## Issue: DISM Component Store Corruption

### Detection
```powershell
DISM /Online /Cleanup-Image /CheckHealth
```

### Fix (SAFE method)
1. DO NOT run `/RestoreHealth` if store is corrupt!
2. Instead: `/StartComponentCleanup /ResetBase`
3. Then: `/AnalyzeComponentStore`
4. If still corrupt: Use Windows installation media as repair source

---

## CRITICAL: GPU/Driver Crash During Fixer Run (2025-12-11 19:25)

### What Happened
System crashed with `SYSTEM_SERVICE_EXCEPTION (0x38)` on `dxgkrnl.sys` (GPU display driver) while fixer script was running at 45% completion.

### Why This Is Critical
- `dxgkrnl.sys` = DirectX Graphics Kernel
- SYSTEM_SERVICE_EXCEPTION on GPU driver indicates:
  1. **Driver instability** from aggressive operations targeting display/GPU
  2. **Memory corruption** in graphics subsystem
  3. **DPC watchdog timeout** (GPU taking too long to respond)
  4. **Display driver reset loop** triggering kernel panic

### Crash Trigger Analysis
The fixer script likely triggered this via:
1. **Phase 40 (Docker)**: Aggressive service restarts → HNS changes GPU-related ICS (Internet Connection Sharing)
2. **Phase 52-59**: HNS/Network reset operations affect display driver IPC
3. **GPU reset/recovery**: Failed GPU TDR (Timeout Detection & Recovery) during cleanup
4. **Memory operations**: DISM/SFC operations can corrupt GPU driver memory if component store is corrupted

### Prevention Strategy
1. **SKIP aggressive operations if GPU driver unstable**
   - Check for pending GPU driver updates BEFORE script runs
   - Monitor for TDR (Timeout Detection & Recovery) events before cleanup
   - Skip GPU-affecting phases if display issues detected

2. **Disable GPU reset operations during cleanup**
   - Skip `dcgpu.sys` modifications
   - Skip DirectX cache cleanup if it requires GPU reset
   - Use safe display driver operations only

3. **Never restart display driver service**
   - `NVIDIA Display Driver Service`, `AMD Display Driver Service`, etc.
   - These trigger immediate GPU reset → system crash
   - Skip these ENTIRELY

4. **Check component store BEFORE Phase 40+**
   - If component store is corrupt, HNS operations will fail and cascade to GPU
   - Run `/StartComponentCleanup /ResetBase` FIRST in Phase 0
   - Verify health before proceeding to network phases

### Safe Fix
- Add GPU driver stability check before Phase 40
- Skip all phases that restart display/GPU services
- Monitor for TDR events in event log before executing
- Use safe HNS reset that doesn't cascade to GPU subsystem

---

## CRITICAL: Explorer.exe Force-Kill Causes GPU Crash (2025-12-11 23:49)

### What Happened
System crashed with `SYSTEM_SERVICE_EXCEPTION` on `dxgkrnl.sys` at Phase 30 ("Restoring Explorer.exe & Shell UI") after completing Phase 29.

### Root Cause
Line 3088 in a.ps1:
```powershell
Get-Process explorer -EA 0 | Stop-Process -Force -EA 0
```

This force-kills explorer.exe which triggers:
1. Shell COM objects invalidation
2. Desktop Window Manager (dwm.exe) destabilization
3. DirectX Graphics Kernel (dxgkrnl.sys) crash
4. SYSTEM_SERVICE_EXCEPTION BSOD

### Why Force-Killing Explorer Is Dangerous
- Explorer.exe is the Windows shell - killing it abruptly:
  - Orphans all shell extension COM objects
  - Breaks IShellView interfaces
  - Causes DWM composition failures
  - Can trigger GPU driver crash on unstable systems

### Fix Applied
Commented out lines 3088-3089 to disable the explorer.exe force-kill:
```powershell
# Kill any stuck explorer processes (DISABLED - causes GPU crash on unstable systems)
# Get-Process explorer -EA 0 | Stop-Process -Force -EA 0
# Start-Sleep -Seconds 2
```

### Prevention Rule
**NEVER force-kill explorer.exe** in system repair scripts. Instead:
- Wait for explorer to respond naturally
- Use `Stop-Process` only if absolutely necessary WITH timeout
- Prefer `taskkill /f /im explorer.exe` which is safer
- Better: just restart explorer gracefully: `Stop-Process -Name explorer -Force; Start-Process explorer`

---

## Logs Script Errors Fixed (2025-12-11 21:25)

### Error 1: DismInitialize failed (0xc0040009)
**Location**: Docker & Container Performance section (lines 2234, 2240)
**Cause**: `Get-WindowsOptionalFeature -Online` calls DISM which fails if DISM is already in use or Windows servicing stack is busy.
**Fix**: Wrapped each call in individual try-catch blocks:
```powershell
try {
    $hvFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V" -EA 0
    if ($hvFeature -and $hvFeature.State -ne 'Enabled') {
        Problem "HYPER-V: Not enabled..."
    }
} catch {}
```

### Error 2: MoveNext with "Invalid property"
**Location**: Freeze/Hang/Crash Detection section (lines 2307-2329, 2392-2408)
**Cause**: `Get-PhysicalDisk` can return objects with invalid/inaccessible properties when storage subsystem is in inconsistent state. Iterating with `ForEach-Object` or accessing `$_.BusType` throws "Invalid property" exception.
**Fix**: Wrapped entire `Get-PhysicalDisk` pipelines in try-catch with null guards:
```powershell
try {
    $disks = Get-PhysicalDisk -EA 0
    foreach ($disk in $disks) {
        try {
            if ($disk -and $disk.FriendlyName) {
                # ... operations
            }
        } catch {}
    }
} catch {}
```

### Prevention Rules
1. **Always wrap DISM/Windows Feature queries in try-catch** - DISM operations can fail silently
2. **Always wrap storage cmdlets (Get-PhysicalDisk, Get-Disk, Get-Volume) in try-catch** - storage subsystem can return invalid objects
3. **Add null checks before accessing object properties** - prevents "Invalid property" errors
4. **Don't assume cmdlet results are valid** - even with `-EA 0`, enumeration can throw

---
