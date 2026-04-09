# Windows 11 WMI/DISM/SFC Repair Script

## Overview
**File:** `a.py` (Python 3)
**Version:** 3.0
**Purpose:** Complete Windows system repair for WMI, WMIC, DISM, and SFC issues
**Must run as:** Administrator

## What This Script Fixes

### 1. DISM Error 1639 - "Missing Servicing Command"
**Problem:** Running `dism.exe /online` without an operation command causes Error 1639
**Fix:** Script validates DISM arguments before execution, auto-prepends `/online` if missing
**Location:** `run_dism_with_progress()` function, lines 138-147

### 2. WMI/WMIC Issues
- WMI repository corruption
- Missing wmic.exe
- WMIC capability not installed
- WMI services not running
- MOF files not compiled

### 3. System Component Issues
- Corrupted Windows component store
- Pending operations blocking DISM
- SFC file integrity problems
- Service configuration issues

## Script Phases

### PHASE 0: PREPARATION (Steps 0-1)
- Stops services: BITS, wuauserv, cryptsvc, TrustedInstaller, Winmgmt, WmiApSrv
- Cleans: SoftwareDistribution, catroot2, pending.xml, ReportQueue

### PHASE 1: WMI REPAIR (Steps 2-6)
- Step 2: Check/install WMIC capability (`WMIC~~~~`)
- Step 3: Verify wmic.exe exists (copies from WinSxS if missing)
- Step 4: Reset WMI repository (salvage, reset, verify)
- Step 5: Recompile core MOF files (parallel, 5s timeout per file)
- Step 6: Ensure WBEM in system PATH

### PHASE 2: SYSTEM HEALTH (Steps 7-13)
- Step 7: Configure and start critical services
- Step 8: DISM /StartComponentCleanup
- Step 9: DISM /CheckHealth
- Step 10: DISM /ScanHealth (skips RestoreHealth if healthy)
- Step 11: DISM /RestoreHealth (with WU fallback)
- Step 12: SFC /scannow
- Step 13: Final component cleanup

### PHASE 3: VALIDATION (Step 14)
- WMI repository consistency check
- 6 WMI class queries (Win32_OperatingSystem, ComputerSystem, LogicalDisk, Process, Service, BIOS)
- 4 WMIC queries (os, cpu, memorychip, diskdrive)
- CIM instance test
- Critical service status check
- DISM CheckHealth/ScanHealth
- Pending reboot detection

## Key Features

### Never Stuck
- 45-second stall detection (kills if no progress)
- 5-minute hard timeout for DISM/SFC
- 30-second timeout for simple commands

### Error Prevention
```python
# Prevents DISM Error 1639
if not args or args.strip() == '/online':
    return -1, "MISSING_OPERATION"
```

### Parallel Processing
- MOF compilation uses ThreadPoolExecutor (8 workers max)
- Each MOF file has 5-second timeout

### Logging
- All output logged to `run_log.txt` in script directory
- ANSI colors stripped from log file

## Usage

### Run Full Repair
```powershell
# As Administrator
python F:\study\shells\powershell\scripts\Win11Fixer\new3\a.py
```

### Expected Runtime
- ~5 minutes if system is healthy
- ~10-15 minutes if repairs needed

### Exit Codes
- `0` = All repairs successful
- `1` = Some issues detected (reboot recommended)

## Common Issues & Solutions

### Issue: DISM hangs at certain percentage
**Cause:** Pending operations or corrupted component store
**Solution:** Script auto-clears pending.xml and registry keys before RestoreHealth

### Issue: WMI queries fail
**Cause:** Corrupted WMI repository
**Solution:** Script runs winmgmt /salvagerepository and /resetrepository

### Issue: wmic.exe not found
**Cause:** WMIC deprecated in Windows 11
**Solution:** Script installs WMIC capability or copies from WinSxS

### Issue: Services won't start
**Cause:** Service dependencies or configuration
**Solution:** Script configures start type and starts in correct order

## Future Session Notes

### To Modify Timeouts
```python
DISM_TIMEOUT = 300  # 5 minutes - line 67
SFC_TIMEOUT = 300   # 5 minutes - line 68
CMD_TIMEOUT = 30    # 30 seconds - line 69
STALL_TIMEOUT = 45  # 45 seconds - line 70
```

### To Add New WMI Tests
Add to `test_wmi_classes()` function:
```python
tests = [
    ('ClassName', 'Get-WmiObject ClassName'),
    ...
]
```

### To Add New WMIC Tests
Add to `test_wmic_queries()` function:
```python
tests = [
    ('alias', 'wmic alias get Property /value'),
    ...
]
```

### To Modify Service Configuration
Edit `step_7_start_services()`:
- `auto_services` = services set to auto-start
- `manual_services` = services just started (no config change)

## Dependencies
- Python 3.x (uses winreg, subprocess, threading, concurrent.futures)
- Windows 11 (tested on 10.0.26100)
- Administrator privileges

## Files
```
F:\study\shells\powershell\scripts\Win11Fixer\new3\
├── a.py          # Main repair script (39KB)
├── CLAUDE.md     # This documentation
└── run_log.txt   # Generated when script runs
```

## Tested Results (2026-01-05)
- DISM CheckHealth: PASS
- DISM ScanHealth: PASS (no corruption)
- WMI Repository: Consistent
- WMI Classes: 6/6 passed
- WMIC Queries: 4/4 passed
- CIM Instance: PASS
- Services: Winmgmt, TrustedInstaller, cryptsvc all running
